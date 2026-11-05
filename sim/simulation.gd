extends RefCounted
## Deterministic 5-second turn simulation. Integer math only; no randomness in combat.
## Usage: create(), add_unit(), set_orders(), run_turn().
## Combat model: see docs/RULES_REFERENCE.md (time-to-kill with stillness, cover, first sight, turn delay).

const Fx = preload("res://sim/fx.gd")
const Rng = preload("res://sim/rng.gd")
const SimMap = preload("res://sim/grid_map.gd")
const Balance = preload("res://sim/balance.gd")
const SimUnit = preload("res://sim/sim_unit.gd")
const Modes = preload("res://sim/modes.gd")

const KILL_SCALE := 1000000
const GRENADE_FLIGHT := 60

var map
var units: Array = []          # SimUnit, ordered by id
var projectiles: Array = []    # dictionaries
var rng                        # kept for modes/AI that need seeded choices
var mode: Dictionary = {}      # game-mode state, see modes.gd
var tick: int = 0
var turn_no: int = 1           # 1-based number of the turn being (or about to be) played
var events: Array = []         # replay events for the last run_turn
var frames: Array = []         # per-tick snapshots for the last run_turn
var _next_id: int = 1
var _kills: Array = []         # pending kills this tick: [victim_id, killer_id]

static func create(rows: Array, seed_value: int = 1):
	var s = load("res://sim/simulation.gd").new()
	s.map = SimMap.from_rows(rows)
	s.rng = Rng.new(seed_value)
	return s

## Adds a unit at the centre of tile (tx,ty). Returns the unit id.
func add_unit(team: int, type: String, tx: int, ty: int, facing: int = 0) -> int:
	var u = SimUnit.new()
	u.id = _next_id
	_next_id += 1
	u.team = team
	u.type = type
	u.x = tx * Fx.TILE + 500
	u.y = ty * Fx.TILE + 500
	u.facing = facing
	units.append(u)
	return u.id

func unit(id: int):
	for u in units:
		if u.id == id:
			return u
	return null

func alive_count(team: int) -> int:
	var n := 0
	for u in units:
		if u.alive and u.team == team:
			n += 1
	return n

## Orders: {"path":[{x,y,wait(s),duck,aim_x,aim_y}], "aim":{x,y}, "ignore":[ids], "focus":[ids], "cos":bool,
##          "fire":{x,y,tick} | "fires":[{x,y,tick}], "duck": bool}   (x,y in milli-tiles)
func set_orders(id: int, o: Dictionary) -> void:
	var u = unit(id)
	u.path = []
	for wp in o.get("path", []):
		u.path.append({
			"x": wp["x"], "y": wp["y"], "wait": wp.get("wait", 0) * 20,
			"duck": wp.get("duck", u.ducked), "aim_x": wp.get("aim_x", -1), "aim_y": wp.get("aim_y", -1),
		})
	u.wp_i = 0
	u.wait_left = 0
	u.ignore = o.get("ignore", []).duplicate()
	u.focus = o.get("focus", []).duplicate()
	u.cos = o.get("cos", false)
	u.fires = []
	if o.has("fires"):
		u.fires = o["fires"].duplicate(true)
	elif o.has("fire") and not o["fire"].is_empty():
		u.fires = [o["fire"].duplicate()]
	u.fire_i = 0
	u.anim_left = 0
	u.target = -1
	u.progress = 0
	u.unaware = false
	u.pending_duck = -1
	if o.has("duck") and o["duck"] != u.ducked:
		u.pending_duck = 1 if o["duck"] else 0
	if o.has("aim"):
		u.aim_lock = true
		u.cos = false
		u.aim_x = o["aim"]["x"]
		u.aim_y = o["aim"]["y"]
		u.facing = Fx.atan2_dd(u.aim_y - u.y, u.aim_x - u.x)
	else:
		u.aim_lock = false

func run_turn() -> void:
	events = []
	frames = []
	tick = 0
	_snapshot()
	for i in range(Balance.TICKS_PER_TURN):
		step()
		_snapshot()

func step() -> void:
	tick += 1
	_kills = []
	for u in units:
		if not u.alive:
			continue
		if tick == 1 and u.pending_duck >= 0:
			_set_stance(u, u.pending_duck == 1)
			u.pending_duck = -1
		if u.stance_lock > 0:
			u.stance_lock -= 1
		if u.fire_cd > 0:
			u.fire_cd -= 1
	for u in units:
		if u.alive:
			_move(u)
	for u in units:
		if u.alive:
			_launch(u)
	_update_projectiles()
	_combat_all()
	_apply_kills()
	if not mode.is_empty():
		Modes.on_tick(self)

func _set_stance(u, duck: bool) -> void:
	if u.ducked != duck:
		u.ducked = duck
		u.stance_lock = Balance.STANCE_LOCK_TICKS

# ---------------------------------------------------------------- movement

func _move(u) -> void:
	u.moving = false
	if u.anim_left > 0:
		return
	if u.wait_left > 0:
		u.wait_left -= 1
		return
	if u.wp_i >= u.path.size():
		return
	var wp: Dictionary = u.path[u.wp_i]
	var speed: int = Balance.TYPES[u.type]["speed"]
	if u.ducked:
		speed = speed * Balance.DUCK_SPEED_PERMILLE / 1000
	if u.aim_lock:
		speed = speed * Balance.AIM_MOVE_SPEED_PERMILLE / 1000
	var dx: int = wp["x"] - u.x
	var dy: int = wp["y"] - u.y
	var d: int = Fx.isqrt(dx * dx + dy * dy)
	if d <= speed:
		if map.walkable(wp["x"], wp["y"]):
			u.x = wp["x"]
			u.y = wp["y"]
		_set_stance(u, wp["duck"])
		if wp["aim_x"] >= 0:
			u.aim_lock = true
			u.cos = false
			u.aim_x = wp["aim_x"]
			u.aim_y = wp["aim_y"]
			u.facing = Fx.atan2_dd(u.aim_y - u.y, u.aim_x - u.x)
		u.wait_left = wp["wait"]
		u.wp_i += 1
		return
	var nx: int = u.x + dx * speed / d
	var ny: int = u.y + dy * speed / d
	if map.walkable(nx, ny):
		u.x = nx
		u.y = ny
		u.moving = true
		if not u.aim_lock:
			u.facing = Fx.atan2_dd(dy, dx)
	elif map.walkable(nx, u.y):
		u.x = nx
		u.moving = true
	elif map.walkable(u.x, ny):
		u.y = ny
		u.moving = true
	else:
		u.wp_i = u.path.size()  # blocked: give up the rest of the path

# ---------------------------------------------------------------- sight

func in_fov(a, x: int, y: int) -> bool:
	return Fx.angle_diff(a.facing, Fx.atan2_dd(y - a.y, x - a.x)) <= Balance.TYPES[a.type]["fov"]

func _los(a, e) -> bool:
	return map.los(a.x, a.y, e.x, e.y, a.ducked or e.ducked)

## Natural sighting: within sight range, field of view and line of sight.
func can_see(a, e) -> bool:
	var dx: int = e.x - a.x
	var dy: int = e.y - a.y
	if dx * dx + dy * dy > Balance.SIGHT_RANGE * Balance.SIGHT_RANGE:
		return false
	return in_fov(a, e.x, e.y) and _los(a, e)

func _in_weapon_range(a, e, wt: Dictionary) -> bool:
	var dx: int = e.x - a.x
	var dy: int = e.y - a.y
	return dx * dx + dy * dy <= wt["range"] * wt["range"] and _los(a, e)

func _allowed(a, e) -> bool:
	if a.cos or a.ignore.has(e.id):
		return false
	return a.focus.is_empty() or a.focus.has(e.id)

func _enemy(a, e) -> bool:
	return e.alive and e.team != a.team and e.team < 2 and e.id != a.id

# ---------------------------------------------------------------- direct-fire combat

func _shield_active(u) -> bool:
	return Balance.TYPES[u.type]["shield"] > 0 and not u.moving and u.anim_left == 0

func _shield_blocks(t, shooter) -> bool:
	if not _shield_active(t):
		return false
	var to_shooter: int = Fx.atan2_dd(shooter.y - t.y, shooter.x - t.x)
	return Fx.angle_diff(t.facing, to_shooter) <= Balance.TYPES[t.type]["shield"]

func _ttk_ms(a, t, wt: Dictionary) -> int:
	var d: int = Fx.dist(a.x, a.y, t.x, t.y)
	var ms: int = wt["base"] + wt["slope"] * mini(d, wt["range"]) / wt["range"] + a.turn_ms
	var still: int = Balance.STILL_PERMILLE
	if a.moving:
		still = Balance.AIMING_MOVE_PERMILLE if a.aim_lock else Balance.MOVING_PERMILLE
	ms = ms * still / 1000
	if not t.ducked:
		var cd: int = map.first_low(a.x, a.y, t.x, t.y)
		if cd >= 0:
			var from_target: int = maxi(d - cd, 1)
			var ratio: int = cd * 1000 / from_target
			if ratio >= 2000:
				ms = ms * Balance.COVER_FAR_PERMILLE / 1000
			elif ratio > 500:
				ms = ms * Balance.COVER_MID_PERMILLE / 1000
	if a.unaware:
		ms = ms * Balance.UNAWARE_PERMILLE / 1000
	return maxi(ms, 40)

func _acquire(a, e, wt: Dictionary, forced: bool) -> void:
	a.target = e.id
	a.progress = 0
	var want: int = Fx.atan2_dd(e.y - a.y, e.x - a.x)
	var diff: int = Fx.angle_diff(a.facing, want)
	a.turn_ms = wt["turn"] * diff / 1800
	a.unaware = forced and diff > Balance.AIM_CONE
	if not a.aim_lock:
		a.facing = want

func _combat_all() -> void:
	var shooters: Array = []
	for a in units:
		if a.alive and Balance.TYPES[a.type]["kind"] == "direct":
			shooters.append(a)
	# keep or drop current targets
	for a in shooters:
		if a.target >= 0:
			var t = unit(a.target)
			var wt: Dictionary = Balance.TYPES[a.type]
			if t == null or not _enemy(a, t) or not _allowed(a, t) or not _in_weapon_range(a, t, wt):
				a.target = -1
				a.progress = 0
				a.unaware = false
	# natural sighting
	for a in shooters:
		if a.target >= 0 or a.cos:
			continue
		var wt2: Dictionary = Balance.TYPES[a.type]
		var best = null
		var bd := 0x7FFFFFFFFFFF
		for e in units:
			if not _enemy(a, e) or not _allowed(a, e):
				continue
			if not (_in_weapon_range(a, e, wt2) and in_fov(a, e.x, e.y)):
				continue
			var d2: int = (e.x - a.x) * (e.x - a.x) + (e.y - a.y) * (e.y - a.y)
			if d2 < bd:
				bd = d2
				best = e
		if best != null:
			_acquire(a, best, wt2, false)
	# forced sighting: whoever is being engaged turns to answer (if in weapon range)
	for a in shooters:
		if a.target >= 0 or a.cos:
			continue
		var wt3: Dictionary = Balance.TYPES[a.type]
		for e in shooters:
			if e.target == a.id and _enemy(a, e) and _allowed(a, e) and _in_weapon_range(a, e, wt3):
				_acquire(a, e, wt3, true)
				break
	# progress towards the kill shot
	for a in shooters:
		if a.target < 0:
			continue
		var t = unit(a.target)
		var wt4: Dictionary = Balance.TYPES[a.type]
		if a.stance_lock > 0:
			continue
		if _shield_blocks(t, a):
			a.progress = 0
			continue
		a.progress += KILL_SCALE * Balance.MS_PER_TICK / _ttk_ms(a, t, wt4)
		if tick % Balance.BURST_EVENT_EVERY == 0 and a.progress < KILL_SCALE:
			events.append({"tick": tick, "type": "shot", "shooter": a.id, "target": t.id, "hit": false})
		if a.progress >= KILL_SCALE:
			events.append({"tick": tick, "type": "shot", "shooter": a.id, "target": t.id, "hit": true})
			_kills.append([t.id, a.id])
			a.target = -1
			a.progress = 0
			a.unaware = false

func _apply_kills() -> void:
	for k in _kills:
		var v = unit(k[0])
		var killer = unit(k[1])
		if v == null or not v.alive:
			continue
		# two units cannot kill each other with direct fire in the same tick: a pseudo-random bonus decides
		var mutual := false
		for j in _kills:
			if j[0] == k[1] and j[1] == k[0]:
				mutual = true
		if mutual:
			var lo: int = mini(k[0], k[1])
			var hi: int = maxi(k[0], k[1])
			var low_wins: bool = (turn_no + lo + hi) % 2 == 0
			if (k[1] == lo) != low_wins:
				continue
		if Modes.is_protected(self, v):
			continue
		v.alive = false
		events.append({"tick": tick, "type": "kill", "victim": v.id, "killer": killer.id if killer != null else -1})

# ---------------------------------------------------------------- explosives

func _launch(u) -> void:
	var wt: Dictionary = Balance.TYPES[u.type]
	if wt["kind"] != "rocket" and wt["kind"] != "grenade":
		return
	if u.anim_left > 0:
		u.anim_left -= 1
		if u.anim_left == 0:
			_spawn_projectile(u, u.anim_order, wt)
		return
	if u.fire_i < u.fires.size() and u.fire_cd <= 0 and tick >= u.fires[u.fire_i]["tick"]:
		u.anim_order = u.fires[u.fire_i]
		u.fire_i += 1
		if not u.aim_lock:
			u.facing = Fx.atan2_dd(u.anim_order["y"] - u.y, u.anim_order["x"] - u.x)
		u.anim_left = maxi(wt["anim"], 1)
		u.moving = false
		u.anim_left -= 1
		if u.anim_left == 0:
			_spawn_projectile(u, u.anim_order, wt)

func _spawn_projectile(u, order: Dictionary, wt: Dictionary) -> void:
	var kind: String = wt["kind"]
	u.fire_cd = wt["cooldown"]
	var dx: int = order["x"] - u.x
	var dy: int = order["y"] - u.y
	var d: int = maxi(Fx.isqrt(dx * dx + dy * dy), 1)
	var p := {"kind": kind, "x": u.x, "y": u.y, "owner": u.id, "ducked": u.ducked, "life": 0}
	if kind == "rocket":
		var sp: int = Balance.EXPLOSIVES["rocket"]["projectile_speed"]
		p["vx"] = dx * sp / d
		p["vy"] = dy * sp / d
	else:
		var reach: int = mini(d, wt["range"])
		p["vx"] = dx * reach / d / GRENADE_FLIGHT
		p["vy"] = dy * reach / d / GRENADE_FLIGHT
		p["fuse"] = Balance.EXPLOSIVES["grenade"]["fuse"]
	projectiles.append(p)
	events.append({"tick": tick, "type": "launch", "kind": kind, "owner": u.id, "tx": order["x"], "ty": order["y"]})

func _shield_hit(x: int, y: int) -> bool:
	for u in units:
		if u.alive and _shield_active(u) and Fx.dist(u.x, u.y, x, y) <= 700:
			var ang: int = Fx.atan2_dd(y - u.y, x - u.x)
			if Fx.angle_diff(u.facing, ang) <= Balance.TYPES[u.type]["shield"]:
				return true
	return false

func _blocked(kind_tile: int, p: Dictionary) -> bool:
	if kind_tile == SimMap.WALL:
		return true
	if kind_tile == SimMap.LOW:
		if p["kind"] == "rocket":
			return p["ducked"]
		return p["life"] > GRENADE_FLIGHT / 2   # grenades clear half walls only in the first half of the flight
	return false

func _update_projectiles() -> void:
	var keep: Array = []
	for p in projectiles:
		p["life"] += 1
		if p["kind"] == "rocket":
			var nx: int = p["x"] + p["vx"]
			var ny: int = p["y"] + p["vy"]
			var k: int = map.at_pos(nx, ny)
			if k == SimMap.WALL and map.is_border(nx / Fx.TILE if nx >= 0 else -1, ny / Fx.TILE if ny >= 0 else -1):
				continue   # flies off the edge of the field harmlessly
			if _blocked(k, p) or _shield_hit(nx, ny):
				_explode(p["x"], p["y"], "rocket", p["owner"])
				continue
			if p["life"] > 300:
				continue
			p["x"] = nx
			p["y"] = ny
			keep.append(p)
		else:
			p["fuse"] -= 1
			if p["fuse"] <= 0:
				_explode(p["x"], p["y"], "grenade", p["owner"])
				continue
			var gx: int = p["x"] + p["vx"]
			var gy: int = p["y"] + p["vy"]
			if _shield_hit(gx, gy):
				p["vx"] = -p["vx"]
				p["vy"] = -p["vy"]
			elif _blocked(map.at_pos(gx, gy), p):
				var bx: bool = _blocked(map.at_pos(gx, p["y"]), p)
				var by: bool = _blocked(map.at_pos(p["x"], gy), p)
				if bx or not by:
					p["vx"] = -p["vx"]
				if by or not bx:
					p["vy"] = -p["vy"]
			else:
				p["x"] = gx
				p["y"] = gy
			keep.append(p)
	projectiles = keep

func _explode(x: int, y: int, kind: String, owner: int) -> void:
	var ex: Dictionary = Balance.EXPLOSIVES[kind]
	var r: int = ex["radius"]
	events.append({"tick": tick, "type": "explosion", "kind": kind, "x": x, "y": y, "radius": r})
	# Terrain is blown first so a blast can carry through a breached wall.
	if ex["wall_radius"] > 0:
		for tc in map.destroy_in_radius(x, y, ex["wall_radius"]):
			events.append({"tick": tick, "type": "wall_destroyed", "tx": tc[0], "ty": tc[1]})
	for u in units:
		if not u.alive:
			continue
		var d2: int = (u.x - x) * (u.x - x) + (u.y - y) * (u.y - y)
		if d2 > r * r or not map.los(x, y, u.x, u.y, false):
			continue
		if map.first_low(x, y, u.x, u.y) >= 0:
			if u.ducked:
				continue                     # fully shielded by a half wall
			if d2 > (r / 2) * (r / 2):
				continue                     # standing behind one: only a close blast kills
		_kills.append([u.id, owner])

# ---------------------------------------------------------------- queries / state

## Ids of units not on `team` that the team can currently see (for Dark-mode fog of war).
func visible_to_team(team: int) -> Array:
	var out: Array = []
	for e in units:
		if not e.alive or e.team == team:
			continue
		for u in units:
			if not u.alive or u.team != team:
				continue
			if can_see(u, e) or e.target == u.id or u.target == e.id:
				out.append(e.id)
				break
	return out

func _snapshot() -> void:
	var us: Array = []
	for u in units:
		us.append([u.id, u.x, u.y, u.facing, u.alive, u.ducked])
	var ps: Array = []
	for p in projectiles:
		ps.append([p["kind"], p["x"], p["y"], false])
	var bs: Array = []
	if not mode.is_empty() and mode["type"] == "disputed":
		for b in mode["boxes"]:
			bs.append([b["x"], b["y"], b["delivered"] or not mode["active"]])
	frames.append({"u": us, "p": ps, "b": bs})

func to_dict() -> Dictionary:
	var us: Array = []
	for u in units:
		us.append(u.to_dict())
	return {
		"w": map.w, "h": map.h, "tiles": Array(map.t), "units": us,
		"projectiles": projectiles.duplicate(true), "mode": mode.duplicate(true), "rng": rng.s,
		"tick": tick, "turn_no": turn_no, "next_id": _next_id,
	}

static func from_dict(d: Dictionary):
	var s = load("res://sim/simulation.gd").new()
	s.map = SimMap.new()
	s.map.w = d["w"]
	s.map.h = d["h"]
	s.map.t = PackedByteArray(d["tiles"])
	s.rng = Rng.new(1)
	s.rng.s = d["rng"]
	s.tick = d["tick"]
	s.turn_no = d["turn_no"]
	s._next_id = d["next_id"]
	s.projectiles = d["projectiles"].duplicate(true)
	s.mode = d["mode"].duplicate(true)
	for ud in d["units"]:
		s.units.append(SimUnit.from_dict(ud))
	return s

## Independent copy (used for the Test/preview simulation and AI look-ahead).
func clone():
	return load("res://sim/simulation.gd").from_dict(to_dict())

func state_hash() -> int:
	return str(to_dict()).hash()
