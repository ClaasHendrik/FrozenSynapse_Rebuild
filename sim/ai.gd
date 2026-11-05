extends RefCounted
## Computer opponent. Generates random candidate plans from a few behaviours (advance, advance
## partway, hold, peek), test-plays each against two guesses of what the enemy will do on a
## fog-respecting copy of the game, and submits the best-scoring plan.

const Fx = preload("res://sim/fx.gd")
const Rng = preload("res://sim/rng.gd")
const Nav = preload("res://sim/nav.gd")
const Balance = preload("res://sim/balance.gd")
const Modes = preload("res://sim/modes.gd")

const CANDIDATES := 14

static func plan(game, team: int, seed_value: int = 1, candidates: int = CANDIDATES) -> Dictionary:
	var rng = Rng.new(seed_value * 31 + team * 7 + game.turn * 101 + 5)
	var base = game.fog_clone(team)
	var mine: Array = []
	for u in base.units:
		if u.alive and game.can_order(team, game.sim.unit(u.id)):
			mine.append(u)
	var known: Array = []   # enemy units (alive in fogged clone)
	for u in base.units:
		if u.alive and u.team == 1 - team:
			known.append(u)
	var path_cache := {}
	var best_orders: Dictionary = {}
	var best_score := -1.0e18
	for k in range(candidates):
		var orders := {}
		for u in mine:
			orders[u.id] = _unit_order(game, base, u, known, rng, path_cache, team)
		var score := 0.0
		for scenario in range(2):
			score += _evaluate(game, base, team, orders, scenario, rng)
		if score > best_score:
			best_score = score
			best_orders = orders
	return best_orders

# ------------------------------------------------------------------ objectives

static func _is_attacker(game, team: int) -> bool:
	var m: Dictionary = game.sim.mode
	if m["type"] == "extermination" or m["type"] == "disputed":
		return true
	return m["attacker"] == team

static func _dest_for(game, base, u, known: Array) -> Array:
	var m: Dictionary = game.sim.mode
	var team: int = u.team
	var near_enemy = _nearest(u, known)
	match m["type"]:
		"secure":
			var z: Array = m["zone"]
			return [(z[0] + z[2] + 1) * 500, (z[1] + z[3] + 1) * 500]
		"charge":
			if _is_attacker(game, team):
				var col: int = m["bid"] if team == 0 else m["w"] - 1 - m["bid"]
				return [col * 1000 + 500, u.y]
			return [(m["w"] - 1 if team == 1 else 0) * 500 + 1000, u.y] if near_enemy == null else [near_enemy.x, near_enemy.y]
		"hostage":
			if u.type == "hostage":
				var ex0: Array = m["exits"][0]
				var ex1: Array = m["exits"][1]
				var left: bool = u.x < base.map.w * 500
				var ex: Array = ex0 if left else ex1
				return [(ex[0] + ex[2] + 1) * 500, u.y]
			if not _is_attacker(game, team):
				var sq: Array = m["square"]
				return [(sq[0] + sq[2] + 1) * 500, (sq[1] + sq[3] + 1) * 500]
			var sq2: Array = m["square"]
			return [(sq2[0] + sq2[2] + 1) * 500, (sq2[1] + sq2[3] + 1) * 500]
		"disputed":
			if _carrying(m, u.id) or m["active"] and m["boxes"].size() == 0:
				var ex: Array = m["exits"][team]
				return [(ex[0] + ex[2] + 1) * 500, u.y]
			var best = null
			var bd := 0x7FFFFFFFFFFF
			if not m["active"]:
				return [base.map.w * 500, base.map.h * 500]
			for b in m["boxes"]:
				if b["delivered"] or b["lost"] or b["carrier"] >= 0:
					continue
				var d: int = Fx.dist(u.x, u.y, b["x"], b["y"])
				if d < bd:
					bd = d
					best = b
			if best != null:
				return [best["x"], best["y"]]
	if near_enemy != null:
		return [near_enemy.x, near_enemy.y]
	var gx: int = (base.map.w - 4) * 1000 if team == 0 else 3000
	return [gx, base.map.h * 500]

static func _carrying(m: Dictionary, id: int) -> bool:
	if m["type"] != "disputed":
		return false
	for b in m["boxes"]:
		if b["carrier"] == id:
			return true
	return false

static func _nearest(u, list: Array):
	var best = null
	var bd := 0x7FFFFFFFFFFF
	for e in list:
		var d: int = (e.x - u.x) * (e.x - u.x) + (e.y - u.y) * (e.y - u.y)
		if d < bd:
			bd = d
			best = e
	return best

# ------------------------------------------------------------------ plan generation

static func _path(map, cache: Dictionary, u, dest: Array) -> Array:
	var key := "%d:%d:%d:%d" % [u.id, dest[0] / 1000, dest[1] / 1000, u.x / 1000 * 100 + u.y / 1000]
	if not cache.has(key):
		var d_x: int = dest[0]
		var d_y: int = dest[1]
		# snap an unwalkable destination to the nearest floor tile
		if not map.walkable(d_x, d_y):
			var found := false
			for r in range(1, 5):
				for dy in range(-r, r + 1):
					for dx in range(-r, r + 1):
						if not found and map.walkable(d_x + dx * 1000, d_y + dy * 1000):
							d_x += dx * 1000
							d_y += dy * 1000
							found = true
		cache[key] = Nav.find_path(map, u.x, u.y, d_x, d_y)
	return cache[key]

static func _unit_order(game, base, u, known: Array, rng, cache: Dictionary, team: int) -> Dictionary:
	if u.type == "hostage":
		var hd: Array = _dest_for(game, base, u, known)
		var hp: Array = _path(base.map, cache, u, hd)
		var hpath: Array = []
		for pt in hp:
			hpath.append({"x": pt["x"], "y": pt["y"], "duck": false})
		return {"path": hpath} if rng.below(100) < 60 else {}
	var attacker: bool = _is_attacker(game, team)
	var dest: Array = _dest_for(game, base, u, known)
	var enemy = _nearest(u, known)
	var aim_at: Array = [enemy.x, enemy.y] if enemy != null else dest
	var roll: int = rng.below(100)
	var kind: String
	if attacker:
		kind = "advance" if roll < 40 else ("partial" if roll < 70 else ("hold" if roll < 85 else "peek"))
	else:
		kind = "hold" if roll < 45 else ("peek" if roll < 75 else ("partial" if roll < 90 else "advance"))
	if _carrying(game.sim.mode, u.id):
		kind = "advance"
	var order := {}
	var wt: Dictionary = Balance.TYPES[u.type]
	if wt["kind"] == "none":
		kind = "advance" if attacker else "hold"
	match kind:
		"advance", "partial":
			var p: Array = _path(base.map, cache, u, dest)
			if p.is_empty():
				order["aim"] = {"x": aim_at[0], "y": aim_at[1]}
			else:
				var keep: int = p.size() if kind == "advance" else maxi(1, p.size() / 2)
				var path: Array = []
				for i in range(keep):
					path.append({"x": p[i]["x"], "y": p[i]["y"], "duck": false})
				path[path.size() - 1]["aim_x"] = aim_at[0]
				path[path.size() - 1]["aim_y"] = aim_at[1]
				order["path"] = path
		"peek":
			var target: Array = []
			for tries in range(8):
				var ox: int = u.x + (rng.below(9) - 4) * 1000
				var oy: int = u.y + (rng.below(9) - 4) * 1000
				if base.map.walkable(ox, oy):
					var p2: Array = Nav.find_path(base.map, u.x, u.y, ox, oy)
					if not p2.is_empty():
						target = p2
						break
			if target.is_empty():
				order["aim"] = {"x": aim_at[0], "y": aim_at[1]}
			else:
				target[target.size() - 1]["aim_x"] = aim_at[0]
				target[target.size() - 1]["aim_y"] = aim_at[1]
				target[target.size() - 1]["wait"] = 1
				order["path"] = target
		_:
			order["aim"] = {"x": aim_at[0], "y": aim_at[1]}
			if rng.below(100) < 30:
				order["duck"] = true
	if wt["kind"] == "rocket" or wt["kind"] == "grenade":
		if enemy != null and Fx.dist(u.x, u.y, enemy.x, enemy.y) <= wt["range"] and Fx.dist(u.x, u.y, enemy.x, enemy.y) > 3500:
			if not _near_hostage(base, enemy.x, enemy.y):
				order["fire"] = {"x": enemy.x, "y": enemy.y, "tick": rng.below(30)}
	return order

static func _near_hostage(base, x: int, y: int) -> bool:
	for h in base.units:
		if h.team == 2 and h.alive and Fx.dist(h.x, h.y, x, y) < 4000:
			return true
	return false

# ------------------------------------------------------------------ evaluation

static func _evaluate(game, base, team: int, orders: Dictionary, scenario: int, rng) -> float:
	var sim = base.clone()
	var enemy_alive_before := 0
	var my_alive_before := 0
	var my_centre := Vector2i.ZERO
	var n := 0
	for u in sim.units:
		if u.alive and u.team == team:
			my_alive_before += 1
			my_centre += Vector2i(u.x, u.y)
			n += 1
		elif u.alive and u.team == 1 - team:
			enemy_alive_before += 1
	if n > 0:
		my_centre /= n
	for u in sim.units:
		sim.set_orders(u.id, {})
	for id in orders.keys():
		sim.set_orders(id, orders[id])
	var cache := {}
	for u in sim.units:
		if u.alive and u.team == 1 - team:
			var aim := {"aim": {"x": my_centre.x, "y": my_centre.y}}
			if scenario == 1:
				var p: Array = _path(sim.map, cache, u, [my_centre.x, my_centre.y])
				if not p.is_empty():
					var cut: Array = []
					for i in range(mini(p.size(), 3)):
						cut.append({"x": p[i]["x"], "y": p[i]["y"]})
					aim = {"path": cut}
			sim.set_orders(u.id, aim)
	var score_before := 0
	var boxes_before := 0
	if sim.mode["type"] == "disputed":
		boxes_before = sim.mode["score"][team]
	sim.run_turn()
	var enemy_dead := 0
	var my_dead := 0
	var prog := 0.0
	for u in sim.units:
		if u.team == team:
			if not u.alive:
				my_dead += 1
			else:
				var dd: Array = _dest_for(game, sim, u, [])
				prog -= Fx.dist(u.x, u.y, dd[0], dd[1]) / 1000.0 * 0.12
		elif u.team == 1 - team and not u.alive:
			enemy_dead += 1
	enemy_dead = maxi(0, enemy_dead - (0 if enemy_alive_before > 0 else 0))
	var score: float = 3.0 * enemy_dead - 4.0 * my_dead + prog
	var m: Dictionary = sim.mode
	if m["type"] == "disputed":
		score += 10.0 * (m["score"][team] - boxes_before)
	elif m["type"] == "hostage":
		score += 12.0 * m["escaped"] * (1 if m["attacker"] == team else -1)
	var res: Dictionary = Modes.result(sim, game.turn + 1)
	if res["over"]:
		if res["winner"] == team:
			score += 60.0
		elif res["winner"] == 1 - team:
			score -= 60.0
	return score + float(rng.below(100)) / 1000.0
