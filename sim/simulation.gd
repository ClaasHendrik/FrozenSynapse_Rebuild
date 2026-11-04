extends RefCounted
## Deterministic 5-second turn simulation. Integer math only; seeded RNG.
## Usage: build with new_from_rows(), add_unit(), set_orders(), run_turn().

const Fx = preload("res://sim/fx.gd")
const Rng = preload("res://sim/rng.gd")
const SimMap = preload("res://sim/grid_map.gd")
const Balance = preload("res://sim/balance.gd")
const SimUnit = preload("res://sim/sim_unit.gd")

var map
var units: Array = []          # SimUnit, ordered by id
var projectiles: Array = []    # dictionaries
var rng
var tick: int = 0
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

## Orders: {"path":[{x,y,wait,duck,aim_x,aim_y}], "aim":{x,y}, "ignore":[ids],
##          "fire":{x,y,tick}, "duck": bool}   (x,y in milli-tiles)
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
	u.fire_order = o.get("fire", {}).duplicate()
	u.fired = false
	u.fire_timer = -1
	u.target = -1
	u.aim_timer = 0
	if o.has("duck"):
		u.ducked = o["duck"]
	if o.has("aim"):
		u.aim_lock = true
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
		if u.alive:
			_move(u)
	_update_projectiles()
	for u in units:
		if u.alive:
			_combat(u)
			_explosive_order(u)
	_apply_kills()

# ---------------------------------------------------------------- movement

func _move(u) -> void:
	u.moving = false
	if u.wait_left > 0:
		u.wait_left -= 1
		return
	if u.wp_i >= u.path.size():
		return
	var wp: Dictionary = u.path[u.wp_i]
	var speed: int = Balance.TYPES[u.type]["speed"]
	if u.ducked:
		speed = speed * Balance.DUCK_SPEED_PERMILLE / 1000
	var dx: int = wp["x"] - u.x
	var dy: int = wp["y"] - u.y
	var d: int = Fx.isqrt(dx * dx + dy * dy)
	if d <= speed:
		if map.walkable(wp["x"], wp["y"]):
			u.x = wp["x"]
			u.y = wp["y"]
		u.ducked = wp["duck"]
		if wp["aim_x"] >= 0:
			u.aim_lock = true
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

# ---------------------------------------------------------------- sight & combat

func _sees(a, b, range_: int) -> bool:
	var dx: int = b.x - a.x
	var dy: int = b.y - a.y
	if dx * dx + dy * dy > range_ * range_:
		return false
	return map.los(a.x, a.y, b.x, b.y, a.ducked or b.ducked)

func _can_shoot(a, b, wt: Dictionary) -> bool:
	return _sees(a, b, mini(wt["range"], wt["vision"]))

func _aim_time(u, t, wt: Dictionary) -> int:
	var react: int = wt["react"]
	if u.moving:
		react = react * Balance.MOVING_AIM_NUM / Balance.MOVING_AIM_DEN
	var want: int = Fx.atan2_dd(t.y - u.y, t.x - u.x)
	var diff: int = Fx.angle_diff(u.facing, want)
	if diff <= Balance.PREAIM_TOLERANCE:
		return react / 2
	return react + (diff + wt["turn"] - 1) / wt["turn"]

func _hit_chance(u, t, wt: Dictionary) -> int:
	var d: int = Fx.dist(u.x, u.y, t.x, t.y)
	var r: int = wt["range"]
	var c: int = wt["chance_near"] + (wt["chance_far"] - wt["chance_near"]) * mini(d, r) / r
	if u.moving:
		c = c * Balance.MOVING_HIT_PERMILLE / 1000
	if t.ducked:
		c = c * Balance.DUCKED_TARGET_PERMILLE / 1000
	return c

func _shield_blocks(t, shooter) -> bool:
	var sh: int = Balance.TYPES[t.type]["shield"]
	if sh <= 0:
		return false
	var to_shooter: int = Fx.atan2_dd(shooter.y - t.y, shooter.x - t.x)
	return Fx.angle_diff(t.facing, to_shooter) <= sh

func _combat(u) -> void:
	var wt: Dictionary = Balance.TYPES[u.type]
	if wt["kind"] != "direct":
		return
	if u.cooldown > 0:
		u.cooldown -= 1
	var tgt = unit(u.target) if u.target >= 0 else null
	if tgt == null or not tgt.alive or not _can_shoot(u, tgt, wt):
		u.target = -1
		tgt = null
	if tgt == null:
		var best_d2 := 0x7FFFFFFFFFFF
		for e in units:
			if not e.alive or e.team == u.team or u.ignore.has(e.id):
				continue
			if not _can_shoot(u, e, wt):
				continue
			var d2: int = (e.x - u.x) * (e.x - u.x) + (e.y - u.y) * (e.y - u.y)
			if d2 < best_d2:
				best_d2 = d2
				tgt = e
		if tgt != null:
			u.target = tgt.id
			u.aim_timer = _aim_time(u, tgt, wt)
	if tgt == null:
		return
	if u.aim_timer > 0:
		u.aim_timer -= 1
	if u.aim_timer > 0 or u.cooldown > 0:
		return
	# shoot
	u.cooldown = wt["interval"]
	if not u.aim_lock:
		u.facing = Fx.atan2_dd(tgt.y - u.y, tgt.x - u.x)
	var hit: bool = false
	if not _shield_blocks(tgt, u):
		hit = rng.below(1000) < _hit_chance(u, tgt, wt)
	events.append({"tick": tick, "type": "shot", "shooter": u.id, "target": tgt.id, "hit": hit})
	if hit:
		_kills.append([tgt.id, u.id])

func _apply_kills() -> void:
	for k in _kills:
		var v = unit(k[0])
		if v.alive:
			v.alive = false
			events.append({"tick": tick, "type": "kill", "victim": v.id, "killer": k[1]})

# ---------------------------------------------------------------- explosives

func _explosive_order(u) -> void:
	var wt: Dictionary = Balance.TYPES[u.type]
	if wt["kind"] == "direct" or u.fired or u.fire_order.is_empty() or tick < u.fire_order["tick"]:
		return
	var tx: int = u.fire_order["x"]
	var ty: int = u.fire_order["y"]
	if u.fire_timer < 0:
		var react: int = wt["react"]
		if u.moving:
			react = react * Balance.MOVING_AIM_NUM / Balance.MOVING_AIM_DEN
		var diff: int = Fx.angle_diff(u.facing, Fx.atan2_dd(ty - u.y, tx - u.x))
		u.fire_timer = react / 2 if diff <= Balance.PREAIM_TOLERANCE else react + (diff + wt["turn"] - 1) / wt["turn"]
	u.fire_timer -= 1
	if u.fire_timer > 0:
		return
	if Fx.dist(u.x, u.y, tx, ty) > wt["range"]:
		u.fired = true  # out of range: order wasted
		return
	u.fired = true
	if not u.aim_lock:
		u.facing = Fx.atan2_dd(ty - u.y, tx - u.x)
	var kind: String = wt["kind"]
	projectiles.append({"kind": kind, "x": u.x, "y": u.y, "tx": tx, "ty": ty, "owner": u.id, "landed": false, "fuse": -1})
	events.append({"tick": tick, "type": "launch", "kind": kind, "owner": u.id, "tx": tx, "ty": ty})

func _update_projectiles() -> void:
	var keep: Array = []
	for p in projectiles:
		var ex: Dictionary = Balance.EXPLOSIVES[p["kind"]]
		if p["landed"]:
			p["fuse"] -= 1
			if p["fuse"] <= 0:
				_explode(p["x"], p["y"], p["kind"], p["owner"])
			else:
				keep.append(p)
			continue
		var speed: int = ex["projectile_speed"]
		var dx: int = p["tx"] - p["x"]
		var dy: int = p["ty"] - p["y"]
		var d: int = Fx.isqrt(dx * dx + dy * dy)
		var nx: int = p["tx"]
		var ny: int = p["ty"]
		var arrived: bool = d <= speed
		if not arrived:
			nx = p["x"] + dx * speed / d
			ny = p["y"] + dy * speed / d
		var blocked: bool = false
		var tile_kind: int = map.at_pos(nx, ny)
		if p["kind"] == "rocket":
			blocked = tile_kind != SimMap.FLOOR
		else:
			blocked = tile_kind == SimMap.WALL  # grenades are lobbed over low walls
		if blocked:
			if p["kind"] == "rocket":
				_explode(p["x"], p["y"], "rocket", p["owner"])
				continue
			p["landed"] = true      # grenade bounces off the wall and stops short
			p["fuse"] = ex["fuse"]
			keep.append(p)
			continue
		p["x"] = nx
		p["y"] = ny
		if arrived:
			if p["kind"] == "rocket":
				_explode(nx, ny, "rocket", p["owner"])
				continue
			p["landed"] = true
			p["fuse"] = ex["fuse"]
		keep.append(p)
	projectiles = keep

func _explode(x: int, y: int, kind: String, owner: int) -> void:
	var ex: Dictionary = Balance.EXPLOSIVES[kind]
	var r: int = ex["radius"]
	events.append({"tick": tick, "type": "explosion", "kind": kind, "x": x, "y": y, "radius": r})
	# Walls are blown first so a blast can carry through a breached thin wall.
	if ex["wall_radius"] > 0:
		for tc in map.destroy_in_radius(x, y, ex["wall_radius"]):
			events.append({"tick": tick, "type": "wall_destroyed", "tx": tc[0], "ty": tc[1]})
	for u in units:
		if not u.alive:
			continue
		var dx: int = u.x - x
		var dy: int = u.y - y
		if dx * dx + dy * dy <= r * r and map.los(x, y, u.x, u.y, false):
			_kills.append([u.id, owner])

# ---------------------------------------------------------------- queries / state

## Ids of enemy units currently visible to a team (for Dark-mode fog of war).
func visible_to_team(team: int) -> Array:
	var out: Array = []
	for e in units:
		if not e.alive or e.team == team:
			continue
		for u in units:
			if u.alive and u.team == team and _sees(u, e, Balance.TYPES[u.type]["vision"]):
				out.append(e.id)
				break
	return out

func _snapshot() -> void:
	var us: Array = []
	for u in units:
		us.append([u.id, u.x, u.y, u.facing, u.alive, u.ducked])
	var ps: Array = []
	for p in projectiles:
		ps.append([p["kind"], p["x"], p["y"], p["landed"]])
	frames.append({"u": us, "p": ps})

func to_dict() -> Dictionary:
	var us: Array = []
	for u in units:
		us.append(u.to_dict())
	return {
		"w": map.w, "h": map.h, "tiles": Array(map.t), "units": us,
		"projectiles": projectiles.duplicate(true), "rng": rng.s, "tick": tick, "next_id": _next_id,
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
	s._next_id = d["next_id"]
	s.projectiles = d["projectiles"].duplicate(true)
	for ud in d["units"]:
		s.units.append(SimUnit.from_dict(ud))
	return s

## Independent copy (used for the Test/preview simulation and AI look-ahead).
func clone():
	return load("res://sim/simulation.gd").from_dict(to_dict())

func state_hash() -> int:
	return str(to_dict()).hash()
