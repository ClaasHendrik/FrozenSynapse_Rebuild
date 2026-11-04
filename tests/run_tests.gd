extends SceneTree
## Run: godot --headless --path . -s tests/run_tests.gd

const Fx = preload("res://sim/fx.gd")
const Sim = preload("res://sim/simulation.gd")
const SimMap = preload("res://sim/grid_map.gd")

var passed := 0
var failed := 0

func check(cond: bool, name: String) -> void:
	if cond:
		passed += 1
		print("  ok   ", name)
	else:
		failed += 1
		print("  FAIL ", name)

func c(tx: int) -> int:
	return tx * 1000 + 500

func open_map(w: int = 30, h: int = 9) -> Array:
	var rows: Array = []
	for y in range(h):
		var row := ""
		for x in range(w):
			row += "#" if (x == 0 or y == 0 or x == w - 1 or y == h - 1) else "."
		rows.append(row)
	return rows

func _init() -> void:
	test_math()
	test_los()
	test_movement()
	test_stationary_beats_moving()
	test_preaim_beats_unaimed()
	test_shotgun_vs_mg_close()
	test_low_cover()
	test_rocket()
	test_grenade()
	test_shield()
	test_ignore()
	test_determinism()
	print("\n%d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)

func test_math() -> void:
	print("math")
	check(Fx.isqrt(0) == 0 and Fx.isqrt(99) == 9 and Fx.isqrt(100) == 10 and Fx.isqrt(1000000) == 1000, "isqrt")
	check(Fx.atan2_dd(0, 10) == 0, "atan2 east")
	check(Fx.atan2_dd(10, 0) == 900, "atan2 south")
	check(Fx.atan2_dd(0, -10) == 1800, "atan2 west")
	check(Fx.atan2_dd(-10, 0) == 2700, "atan2 north")
	check(absi(Fx.atan2_dd(10, 10) - 450) <= 2, "atan2 diagonal")
	check(Fx.angle_diff(10, 3590) == 20, "angle_diff wraps")

func test_los() -> void:
	print("line of sight")
	var rows := open_map()
	rows[4] = rows[4].substr(0, 10) + "#" + rows[4].substr(11)
	rows[2] = rows[2].substr(0, 10) + "o" + rows[2].substr(11)
	var m = SimMap.from_rows(rows)
	check(m.los(c(5), c(3), c(15), c(3), false), "open line")
	check(not m.los(c(5), c(4), c(15), c(4), false), "wall blocks")
	check(m.los(c(5), c(2), c(15), c(2), false), "low cover ignored when standing")
	check(not m.los(c(5), c(2), c(15), c(2), true), "low cover blocks when ducked")

func test_movement() -> void:
	print("movement")
	var s = Sim.create(open_map(), 1)
	var a = s.add_unit(0, "mg", 2, 4)
	s.set_orders(a, {"path": [{"x": c(12), "y": c(4)}]})
	s.run_turn()
	var u = s.unit(a)
	check(u.x == c(12) and u.y == c(4), "mg reaches 10 tiles in 5 s")
	check(u.facing == 0, "faces direction of travel")
	var b = s.add_unit(0, "sniper", 2, 6)
	s.set_orders(b, {"path": [{"x": c(20), "y": c(6)}]})
	s.run_turn()
	check(s.unit(b).x < c(20), "sniper is slower than a 18-tile dash")

func duel(seed_value: int, a_type: String, a_tile: int, a_orders: Dictionary, b_type: String, b_tile: int, b_orders: Dictionary, rows: Array = []) -> Array:
	var s = Sim.create(rows if not rows.is_empty() else open_map(), seed_value)
	var a = s.add_unit(0, a_type, a_tile, 4, 0)
	var b = s.add_unit(1, b_type, b_tile, 4, 1800)
	s.set_orders(a, a_orders)
	s.set_orders(b, b_orders)
	s.run_turn()
	return [s.unit(a).alive, s.unit(b).alive]

func test_stationary_beats_moving() -> void:
	print("combat: stationary beats moving")
	var a_wins := 0
	var b_wins := 0
	for seed_value in range(1, 101):
		var r = duel(seed_value, "mg", 5, {"aim": {"x": c(20), "y": c(4)}},
			"mg", 20, {"path": [{"x": c(10), "y": c(4)}]})
		if r[0] and not r[1]:
			a_wins += 1
		elif r[1] and not r[0]:
			b_wins += 1
	print("    stationary wins ", a_wins, "  mover wins ", b_wins)
	check(a_wins > b_wins * 3, "pre-aimed stationary unit wins clearly")

func test_preaim_beats_unaimed() -> void:
	print("combat: pre-aimed beats reacting")
	var a_wins := 0
	var b_wins := 0
	for seed_value in range(1, 101):
		# both stationary at 10 tiles; A pre-aimed, B facing away
		var r = duel(seed_value, "mg", 10, {"aim": {"x": c(20), "y": c(4)}},
			"mg", 20, {"aim": {"x": c(28), "y": c(4)}})
		if r[0] and not r[1]:
			a_wins += 1
		elif r[1] and not r[0]:
			b_wins += 1
	print("    pre-aimed wins ", a_wins, "  unaimed wins ", b_wins)
	check(a_wins > b_wins * 2, "pre-aimed unit usually wins")

func test_shotgun_vs_mg_close() -> void:
	print("combat: weapon envelopes")
	var sg := 0
	var mg := 0
	for seed_value in range(1, 101):
		var r = duel(seed_value, "shotgun", 10, {"aim": {"x": c(0), "y": c(4)}},
			"mg", 14, {"aim": {"x": c(28), "y": c(4)}})
		if r[0] and not r[1]:
			sg += 1
		elif r[1] and not r[0]:
			mg += 1
	print("    shotgun wins ", sg, "  mg wins ", mg)
	check(sg > mg, "shotgun beats MG at 4 tiles")
	var r2 = duel(1, "sniper", 3, {"aim": {"x": c(28), "y": c(4)}}, "shotgun", 26, {"aim": {"x": c(0), "y": c(4)}})
	check(r2[0] and not r2[1], "sniper kills shotgun at 23 tiles, never gets hit back")

func test_low_cover() -> void:
	print("cover")
	var rows := open_map()
	for y in range(1, 8):
		if y != 4:
			continue
		rows[y] = rows[y].substr(0, 12) + "o" + rows[y].substr(13)
	var survived := 0
	for seed_value in range(1, 51):
		var s = Sim.create(rows, seed_value)
		var shooter = s.add_unit(0, "mg", 5, 4, 0)
		var hider = s.add_unit(1, "mg", 13, 4, 1800)
		s.set_orders(shooter, {"aim": {"x": c(13), "y": c(4)}})
		s.set_orders(hider, {"duck": true, "aim": {"x": c(28), "y": c(4)}})
		s.run_turn()
		if s.unit(hider).alive:
			survived += 1
	check(survived == 50, "ducked unit behind low wall is untouchable by standing shooter")
	var s2 = Sim.create(rows, 1)
	var sh = s2.add_unit(0, "mg", 5, 4, 0)
	var st = s2.add_unit(1, "mg", 13, 4, 1800)
	check(s2.visible_to_team(0).has(st), "standing target behind low wall is visible")
	s2.unit(st).ducked = true
	check(not s2.visible_to_team(0).has(st), "ducked target behind low wall is hidden")
	s2.unit(sh).ducked = true
	check(sh > 0, "sanity")

func test_rocket() -> void:
	print("rocket")
	var rows := open_map()
	for y in range(1, 8):
		rows[y] = rows[y].substr(0, 12) + "#" + rows[y].substr(13)
	var s = Sim.create(rows, 1)
	var r = s.add_unit(0, "rocket", 5, 4, 0)
	var v = s.add_unit(1, "mg", 14, 4, 1800)
	s.set_orders(r, {"fire": {"x": c(13), "y": c(4), "tick": 0}})
	s.set_orders(v, {"aim": {"x": c(28), "y": c(4)}})
	s.run_turn()
	check(s.map.tile(12, 4) == SimMap.FLOOR, "rocket destroys the wall")
	check(s.unit(v).alive, "unit 2 tiles behind wall survives (outside blast)")
	var s2 = Sim.create(rows, 1)
	var r2 = s2.add_unit(0, "rocket", 5, 4, 0)
	var v2 = s2.add_unit(1, "mg", 13, 4, 1800)
	s2.set_orders(r2, {"fire": {"x": c(13), "y": c(4), "tick": 0}})
	s2.set_orders(v2, {"aim": {"x": c(28), "y": c(4)}})
	s2.run_turn()
	check(not s2.unit(v2).alive, "unit adjacent to wall dies to blast")

func test_grenade() -> void:
	print("grenade")
	var rows := open_map()
	for y in range(1, 8):
		rows[y] = rows[y].substr(0, 12) + "#" + rows[y].substr(13)
	var s = Sim.create(rows, 1)
	var g = s.add_unit(0, "grenade", 5, 4, 0)
	var v = s.add_unit(1, "mg", 14, 4, 1800)
	s.set_orders(g, {"fire": {"x": c(14), "y": c(4), "tick": 0}})
	s.set_orders(v, {"aim": {"x": c(28), "y": c(4)}})
	s.run_turn()
	check(s.unit(v).alive, "grenade stops at the wall; target behind full wall is safe")
	check(s.map.tile(12, 4) == SimMap.WALL, "grenade does not break walls")
	# grenade over a low wall hits a unit behind it
	var rows2 := open_map()
	for y in range(1, 8):
		rows2[y] = rows2[y].substr(0, 12) + "o" + rows2[y].substr(13)
	var s2 = Sim.create(rows2, 1)
	var g2 = s2.add_unit(0, "grenade", 5, 4, 0)
	var v2 = s2.add_unit(1, "mg", 14, 4, 1800)
	s2.set_orders(g2, {"fire": {"x": c(14), "y": c(4), "tick": 0}})
	s2.set_orders(v2, {"duck": true, "aim": {"x": c(28), "y": c(4)}})
	s2.run_turn()
	check(not s2.unit(v2).alive, "grenade lobbed over low wall kills ducked unit behind it")

func test_shield() -> void:
	print("riot shield")
	var front_kills := 0
	var back_kills := 0
	for seed_value in range(1, 51):
		var s = Sim.create(open_map(), seed_value)
		var m = s.add_unit(0, "mg", 5, 4, 0)
		var r = s.add_unit(1, "riot", 12, 4, 1800)
		s.set_orders(m, {"aim": {"x": c(12), "y": c(4)}})
		s.set_orders(r, {"aim": {"x": c(0), "y": c(4)}})
		s.run_turn()
		if not s.unit(r).alive:
			front_kills += 1
		var s2 = Sim.create(open_map(), seed_value)
		var m2 = s2.add_unit(0, "mg", 5, 4, 0)
		var r2 = s2.add_unit(1, "riot", 12, 4, 0)
		s2.set_orders(m2, {"aim": {"x": c(12), "y": c(4)}})
		s2.set_orders(r2, {"aim": {"x": c(28), "y": c(4)}})
		s2.run_turn()
		if not s2.unit(r2).alive:
			back_kills += 1
	check(front_kills == 0, "shield blocks all frontal fire")
	check(back_kills > 25, "shield does not protect from behind")

func test_ignore() -> void:
	print("ignore order")
	var s = Sim.create(open_map(), 1)
	var a = s.add_unit(0, "mg", 5, 4, 0)
	var b = s.add_unit(1, "mg", 12, 4, 1800)
	s.set_orders(a, {"aim": {"x": c(12), "y": c(4)}, "ignore": [b]})
	s.set_orders(b, {"duck": false, "aim": {"x": c(28), "y": c(4)}})
	s.run_turn()
	var shots_by_a := 0
	for e in s.events:
		if e["type"] == "shot" and e["shooter"] == a:
			shots_by_a += 1
	check(shots_by_a == 0, "ignored enemy is not shot at")

func test_determinism() -> void:
	print("determinism")
	var hashes: Array = []
	for i in range(3):
		var s = Sim.create(open_map(), 42)
		var a = s.add_unit(0, "mg", 5, 4, 0)
		var b = s.add_unit(1, "mg", 20, 4, 1800)
		var g = s.add_unit(0, "grenade", 4, 5, 0)
		s.set_orders(a, {"path": [{"x": c(10), "y": c(4)}]})
		s.set_orders(b, {"path": [{"x": c(15), "y": c(5)}]})
		s.set_orders(g, {"fire": {"x": c(15), "y": c(5), "tick": 10}})
		s.run_turn()
		hashes.append(s.state_hash())
	check(hashes[0] == hashes[1] and hashes[1] == hashes[2], "identical runs give identical state hash")
	var s2 = Sim.create(open_map(), 7)
	var u1 = s2.add_unit(0, "mg", 5, 4, 0)
	var u2 = s2.add_unit(1, "mg", 20, 4, 1800)
	s2.set_orders(u1, {"path": [{"x": c(12), "y": c(4)}]})
	s2.set_orders(u2, {"path": [{"x": c(12), "y": c(5)}]})
	var copy = s2.clone()
	check(copy.state_hash() == s2.state_hash(), "clone equals original")
	s2.run_turn()
	copy.run_turn()
	check(copy.state_hash() == s2.state_hash(), "clone simulates identically (Test preview is exact)")
