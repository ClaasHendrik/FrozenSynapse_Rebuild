extends RefCounted
## One game: generated map + random squads + mode + turn loop.
## Teams: 0 = left player, 1 = right player.

const Fx = preload("res://sim/fx.gd")
const Rng = preload("res://sim/rng.gd")
const Sim = preload("res://sim/simulation.gd")
const MapGen = preload("res://sim/map_gen.gd")
const Modes = preload("res://sim/modes.gd")

const SQUAD_POOL := ["mg", "mg", "shotgun", "shotgun", "sniper", "rocket", "grenade"]

var sim
var layout: Dictionary = {}
var mode_name: String = "extermination"
var dark: bool = false
var turn: int = 0
var over: bool = false
var winner: int = -2
var reason: String = ""
var last_seen: Array = [{}, {}]   # per team: enemy id -> [x, y] (Dark mode memory)

## opts: attacker (0/1), bid, max_turns, squad (units per side, default 5), types0/types1 (explicit squads),
##       map_w, map_h
static func create(mode: String, seed_value: int, is_dark: bool = false, opts: Dictionary = {}):
	var mt = load("res://sim/match.gd").new()
	mt.mode_name = mode
	mt.dark = is_dark
	var attacker: int = opts.get("attacker", 0)
	mt.layout = MapGen.generate(opts.get("map_w", 32), opts.get("map_h", 20), seed_value, attacker)
	mt.sim = Sim.create(mt.layout["rows"], seed_value)
	var rng = Rng.new(seed_value ^ 0x5EED)
	var n: int = opts.get("squad", 5)
	for team in range(2):
		var types: Array = opts.get("types%d" % team, [])
		if types.is_empty():
			for i in range(n):
				types.append(SQUAD_POOL[rng.below(SQUAD_POOL.size())])
		var spots: Array = mt.layout["spawn"][team]
		for i in range(mini(types.size(), spots.size())):
			mt.sim.add_unit(team, types[i], spots[i][0], spots[i][1], 0 if team == 0 else 1800)
	Modes.setup(mt.sim, mode, mt.layout, opts)
	return mt

## orders: {unit_id: order dict}. Returns the ids that were rejected.
func submit_orders(team: int, orders: Dictionary) -> Array:
	var rejected: Array = []
	for id in orders.keys():
		var u = sim.unit(id)
		if u == null or u.team != team or not u.alive:
			rejected.append(id)
			continue
		var ok := true
		for wp in orders[id].get("path", []):
			if not sim.map.walkable(wp["x"], wp["y"]):
				ok = false
		if ok:
			sim.set_orders(id, orders[id])
		else:
			rejected.append(id)
	return rejected

## Runs one turn. Units without fresh orders stand still.
func play_turn(pending: Dictionary = {}) -> Dictionary:
	for u in sim.units:
		if u.alive and not pending.has(u.id):
			sim.set_orders(u.id, {})
	sim.run_turn()
	turn += 1
	for t in range(2):
		for id in sim.visible_to_team(t):
			var e = sim.unit(id)
			last_seen[t][id] = [e.x, e.y]
	var r: Dictionary = Modes.result(sim, turn)
	over = r["over"]
	winner = r["winner"]
	reason = r["reason"]
	return r

## Enemy unit ids the given team may see right now (everything in Light, line of sight in Dark).
func visible_enemy_ids(team: int) -> Array:
	if not dark:
		var out: Array = []
		for u in sim.units:
			if u.alive and u.team != team:
				out.append(u.id)
		return out
	return sim.visible_to_team(team)
