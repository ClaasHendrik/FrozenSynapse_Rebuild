extends RefCounted
## One game: generated map + random squads + mode + turn loop.
## Teams: 0 = left player, 1 = right player. In Secure/Hostage/Charge, `attacker` is the attacking team.

const Fx = preload("res://sim/fx.gd")
const Rng = preload("res://sim/rng.gd")
const Sim = preload("res://sim/simulation.gd")
const MapGen = preload("res://sim/map_gen.gd")
const Modes = preload("res://sim/modes.gd")
const Balance = preload("res://sim/balance.gd")
const MissionRules = preload("res://sim/mission.gd")

const SQUAD_POOL := ["mg", "mg", "shotgun", "shotgun", "sniper", "rocket", "grenade"]

var sim
var layout: Dictionary = {}
var mode_name: String = "extermination"
var dark: bool = false
var turn: int = 0
var over: bool = false
var winner: int = -2
var reason: String = ""
var score: int = 0                # relative to team 0
var attacker: int = 0
var mission: Dictionary = {}      # campaign mission definition (empty in skirmish)
var is_mission: bool = false
var last_seen: Array = [{}, {}]   # per team: enemy id -> [x, y] (Dark mode memory)

## opts: attacker (0/1), bid (charge), bid0/bid1 (charge auction), max_turns, squad (units per side, default 5),
##       types0/types1 (explicit squads), map_w, map_h, red (bool: adds Riot Shield to the squad pool)
static func create(mode: String, seed_value: int, is_dark: bool = false, opts: Dictionary = {}):
	var mt = load("res://sim/match.gd").new()
	mt.mode_name = mode
	mt.dark = is_dark
	var att: int = opts.get("attacker", 0)
	var mopts: Dictionary = opts.duplicate()
	if mode == "charge" and opts.has("bid0") and opts.has("bid1"):
		if opts["bid0"] == opts["bid1"]:
			att = seed_value % 2
		else:
			att = 0 if opts["bid0"] > opts["bid1"] else 1
		mopts["bid"] = maxi(opts["bid0"], opts["bid1"])
	mt.attacker = att
	mopts["attacker"] = att
	mopts["dark"] = is_dark
	mt.layout = MapGen.generate(opts.get("map_w", 32), opts.get("map_h", 20), seed_value, att)
	mt.sim = Sim.create(mt.layout["rows"], seed_value)
	var rng = Rng.new(seed_value ^ 0x5EED)
	var pool: Array = SQUAD_POOL.duplicate()
	if opts.get("red", false):
		pool.append("riot")
	var n: int = opts.get("squad", 5)
	var spots: Array = [mt.layout["spawn"][0], mt.layout["spawn"][1]]
	var dfn: int = 1 - att
	if mode == "secure":
		spots[dfn] = mt._near(mt.layout["zone"], 12)
	elif mode == "hostage":
		spots[dfn] = mt._near(mt.layout["center_zone"], 12)
	for team in range(2):
		var types: Array = opts.get("types%d" % team, []).duplicate()
		if types.is_empty():
			for i in range(n):
				types.append(pool[rng.below(pool.size())])
		if mode == "upload":
			types.append("hacker")
		for i in range(mini(types.size(), spots[team].size())):
			mt.sim.add_unit(team, types[i], spots[team][i][0], spots[team][i][1], 0 if team == 0 else 1800)
	Modes.setup(mt.sim, mode, mt.layout, mopts)
	mt._init_seen()
	return mt

## Floor tiles nearest to a rect's centre (not inside hostage cells), spaced apart: defender deployment.
func _near(rect: Array, count: int) -> Array:
	var cx: int = (rect[0] + rect[2]) / 2
	var cy: int = (rect[1] + rect[3]) / 2
	var cands: Array = []
	for y in range(sim.map.h):
		for x in range(sim.map.w):
			if sim.map.tile(x, y) == 0:
				var inside: bool = x >= rect[0] and x <= rect[2] and y >= rect[1] and y <= rect[3]
				cands.append([absi(x - cx) + absi(y - cy) + (0 if inside else 1), x, y])
	cands.sort()
	var out: Array = []
	for c in cands:
		if layout.get("hostages", []).has([c[1], c[2]]):
			continue
		var ok := true
		for o in out:
			if absi(o[0] - c[1]) + absi(o[1] - c[2]) < 2:
				ok = false
		if ok:
			out.append([c[1], c[2]])
			if out.size() >= count:
				break
	return out

func _init_seen() -> void:
	_update_seen()
	if not dark:
		return
	# the original shows initial enemy positions in Extermination and Disputed, and hostages in Hostage
	for t in range(2):
		for e in sim.units:
			if e.team == t:
				continue
			var shown: bool = mode_name == "extermination" or mode_name == "disputed" or (mode_name == "hostage" and e.team == 2)
			if shown:
				last_seen[t][e.id] = [e.x, e.y, 0]

func _update_seen() -> void:
	for t in range(2):
		for id in sim.visible_to_team(t):
			var e = sim.unit(id)
			last_seen[t][id] = [e.x, e.y, turn]

## Copy of the sim as the given team may know it. In Dark mode enemies it cannot see are
## moved to their last-known position, or removed if never seen (used by Test preview and the AI).
func fog_clone(team: int):
	var c = sim.clone()
	if not dark:
		return c
	var vis: Array = sim.visible_to_team(team)
	for u in c.units:
		if u.team == team or vis.has(u.id):
			continue
		if last_seen[team].has(u.id):
			u.x = last_seen[team][u.id][0]
			u.y = last_seen[team][u.id][1]
		else:
			u.alive = false
	return c

## True if `team` may give orders to this unit right now.
func can_order(team: int, u, include_allies: bool = false) -> bool:
	if u == null or not u.alive:
		return false
	if (u.tag == "ally" or u.tag == "leaver") and not include_allies:
		return false                      # allies are computer-controlled
	if u.team == team:
		return true
	if is_mission and u.team == 2 and u.tag == "rescue" and team == 0:
		return true
	return u.team == 2 and team == attacker and mode_name == "hostage" and Modes.hostage_orderable(sim, u)

## orders: {unit_id: order dict}. Returns the ids that were rejected.
func submit_orders(team: int, orders: Dictionary, include_allies: bool = false) -> Array:
	var rejected: Array = []
	for id in orders.keys():
		var u = sim.unit(id)
		if not can_order(team, u, include_allies):
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

## Runs one turn. Units without fresh orders stand still (hostages already escaping keep going).
func play_turn(pending: Dictionary = {}) -> Dictionary:
	for u in sim.units:
		if not u.alive or pending.has(u.id):
			continue
		if u.team == 2 and u.wp_i < u.path.size():
			continue
		sim.set_orders(u.id, {})
	sim.turn_no = turn + 1
	sim.run_turn()
	turn += 1
	sim.turn_no = turn + 1
	_update_seen()
	var r: Dictionary = Modes.result(sim, turn)
	over = r["over"]
	winner = r["winner"]
	reason = r["reason"]
	score = r["score"]
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

# ------------------------------------------------------------------ campaign missions

const ALIAS := {
	"mg": "mg", "sg": "shotgun", "sn": "sniper", "rl": "rocket", "gl": "grenade", "cm": "commando",
	"dv": "devastator", "rs": "riot", "hk": "hacker", "civ": "civilian", "hos": "hostage",
}

## "rl:launcher*2" -> two rocket launchers tagged "launcher". Accepts a string or an array of strings.
static func expand(spec) -> Array:
	var out: Array = []
	var items: Array = spec if spec is Array else [spec]
	for it in items:
		var s: String = it
		var count := 1
		if s.contains("*"):
			var parts := s.split("*")
			count = int(parts[1])
			s = parts[0]
		var tag := ""
		if s.contains(":"):
			var tp := s.split(":")
			s = tp[0]
			tag = tp[1]
		var type: String = ALIAS.get(s, s)
		for i in range(count):
			out.append({"type": type, "tag": tag})
	return out

func _cands(place: String, rng) -> Array:
	var w: int = sim.map.w
	var h: int = sim.map.h
	var out: Array = []
	match place:
		"left":
			out = layout["spawn"][0].duplicate()
			out.append_array(_near([1, h / 2, 1, h / 2], 30))
		"right":
			out = layout["spawn"][1].duplicate()
			out.append_array(_near([w - 2, h / 2, w - 2, h / 2], 30))
		"zone":
			out = _near(layout["zone"], 30)
		"center":
			out = _near(layout["center_zone"], 30)
		"scatter":
			var pool: Array = []
			for y in range(1, h - 1):
				for x in range(w / 3, w - 3):
					if sim.map.tile(x, y) == 0:
						pool.append([x, y])
			for i in range(pool.size() - 1, 0, -1):
				var j: int = rng.below(i + 1)
				var t = pool[i]
				pool[i] = pool[j]
				pool[j] = t
			out = pool.slice(0, 60)
	return out

func _place(group: Array, team: int, place: String, used: Dictionary, rng, default_tag: String = "") -> void:
	var cands: Array = _cands(place, rng)
	var k := 0
	for spec in group:
		while k < cands.size() and used.has(str(cands[k])):
			k += 1
		if k >= cands.size():
			push_error("mission: no free tile for %s" % spec["type"])
			return
		var t: Array = cands[k]
		used[str(t)] = true
		var facing: int = 0 if t[0] < sim.map.w / 2 else 1800
		sim.add_unit(team, spec["type"], t[0], t[1], facing, spec["tag"] if spec["tag"] != "" else default_tag)

static func create_mission(mission: Dictionary):
	var mt = load("res://sim/match.gd").new()
	mt.mission = mission
	mt.is_mission = true
	mt.mode_name = "mission"
	mt.dark = mission.get("dark", false)
	mt.attacker = 0
	var mp: Dictionary = mission.get("map", {})
	var seed_value: int = mission.get("seed", 1)
	mt.layout = MapGen.generate(mp.get("w", 32), mp.get("h", 20), seed_value, 0)
	mt.sim = Sim.create(mt.layout["rows"], seed_value)
	mt.sim.turn_ticks = int(mission.get("turn_seconds", 5)) * 20
	var rng = Rng.new(seed_value ^ 0xC0DE)
	var used := {}
	var pp: String = mission.get("player_place", "left")
	var ep: String = mission.get("enemy_place", "right")
	mt._place(expand(mission.get("player", [])), 0, pp, used, rng)
	mt._place(expand(mission.get("allies", [])), 0, mission.get("ally_place", pp), used, rng, "ally")
	mt._place(expand(mission.get("enemy", [])), 1, ep, used, rng)
	mt._place(expand(mission.get("neutrals", [])), 2, "center", used, rng)
	mt._place(expand(mission.get("rescue", [])), 2, "center", used, rng, "rescue")
	# items, panels, reinforcement tiles
	var items: Array = mt.layout["boxes"].duplicate()
	var want: int = mission.get("items", 3)
	if want > items.size():
		for t in mt._cands("scatter", rng):
			if items.size() >= want:
				break
			if not used.has(str(t)) and not items.has(t):
				items.append(t)
	items = items.slice(0, maxi(want, 1))
	var panels: Array = []
	for pd in mission.get("panels", []):
		var pc: Array = mt._cands(pd.get("at", "zone"), rng)
		var tile: Array = pc[mini(pd.get("index", 8), pc.size() - 1)]
		panels.append({"tx": tile[0], "ty": tile[1], "effect": {"kill_tag": pd.get("kill_tag", "")}, "done": false, "ticks": 0})
	var from: String = mission.get("wave_from", "left" if pp != "left" else "right")
	var wave_tiles: Array = mt.layout["spawn"][0 if from == "left" else 1].duplicate()
	var rects := {
		"zone": mt.layout["zone"], "center": mt.layout["center_zone"],
		"exit_left": mt.layout["exits"][0], "exit_right": mt.layout["exits"][1],
	}
	var init: Array = [0, 0]
	for u in mt.sim.units:
		if u.team < 2:
			init[u.team] += 1
	mt.sim.mode = MissionRules.build_state(mission, rects, items, panels, wave_tiles, int(mission.get("turns", 8)), init)
	mt._init_seen()
	return mt

func objective_lines() -> Array:
	var out: Array = []
	if is_mission:
		for o in sim.mode["objectives"]:
			out.append(("[x] " if MissionRules.objective_done(sim, sim.mode, o, turn) else "[ ] ") + MissionRules.describe(o))
	return out
