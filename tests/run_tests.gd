extends SceneTree
## Simulation core tests. Run: godot --headless --path . -s tests/run_tests.gd

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

func open_map(w: int = 40, h: int = 9) -> Array:
	var rows: Array = []
	for y in range(h):
		var row := ""
		for x in range(w):
			row += "#" if (x == 0 or y == 0 or x == w - 1 or y == h - 1) else "."
		rows.append(row)
	return rows

func with_col(rows: Array, x: int, ch: String, ys: Array = []) -> Array:
	for y in range(1, rows.size() - 1):
		if ys.is_empty() or ys.has(y):
			rows[y] = rows[y].substr(0, x) + ch + rows[y].substr(x + 1)
	return rows

func _init() -> void:
	test_math()
	test_los()
	test_movement()
	test_ttk_calibration()
	test_stillness()
	test_first_sight()
	test_symmetric_duel()
	test_weapon_envelopes()
	test_cover()
	test_stance_change()
	test_rocket()
	test_grenade()
	test_shield()
	test_orders_ignore_cos_focus()
	test_commando_devastator()
	test_determinism()
	print("\n%d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)

func kill_tick(s, victim: int) -> int:
	for e in s.events:
		if e["type"] == "kill" and e["victim"] == victim:
			return e["tick"]
	return -1

func test_math() -> void:
	print("math")
	check(Fx.isqrt(0) == 0 and Fx.isqrt(99) == 9 and Fx.isqrt(100) == 10 and Fx.isqrt(1000000) == 1000, "isqrt")
	check(Fx.atan2_dd(0, 10) == 0 and Fx.atan2_dd(10, 0) == 900 and Fx.atan2_dd(0, -10) == 1800 and Fx.atan2_dd(-10, 0) == 2700, "atan2 axes")
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
	check(m.los(c(5), c(2), c(15), c(2), false), "half wall ignored when both standing")
	check(not m.los(c(5), c(2), c(15), c(2), true), "half wall blocks when one side is ducked")
	check(m.first_low(c(5), c(2), c(15), c(2)) in range(4400, 5100), "first_low finds the half wall distance")

func test_movement() -> void:
	print("movement")
	var s = Sim.create(open_map(), 1)
	var a = s.add_unit(0, "mg", 2, 4)
	s.set_orders(a, {"path": [{"x": c(12), "y": c(4)}]})
	s.run_turn()
	check(s.unit(a).x == c(12) and s.unit(a).facing == 0, "mg walks 10 tiles in 5 s and faces its travel direction")
	var b = s.add_unit(0, "commando", 2, 6)
	s.set_orders(b, {"path": [{"x": c(30), "y": c(6)}]})
	s.run_turn()
	check(s.unit(b).x > c(15), "commando is far faster than an mg")
	var d = s.add_unit(0, "mg", 2, 2)
	s.set_orders(d, {"path": [{"x": c(12), "y": c(2)}], "aim": {"x": c(20), "y": c(2)}})
	s.run_turn()
	check(s.unit(d).x < c(12), "aiming while moving slows the unit")

func duel(a_type: String, a_tile: int, a_orders: Dictionary, b_type: String, b_tile: int, b_orders: Dictionary, rows: Array = []):
	var s = Sim.create(rows if not rows.is_empty() else open_map(), 1)
	var a = s.add_unit(0, a_type, a_tile, 4, 0)
	var b = s.add_unit(1, b_type, b_tile, 4, 1800)
	s.set_orders(a, a_orders)
	s.set_orders(b, b_orders)
	s.run_turn()
	return [s, a, b]

func aim_at(tx: int) -> Dictionary:
	return {"aim": {"x": c(tx), "y": c(4)}}

func test_ttk_calibration() -> void:
	print("time to kill")
	var r = duel("mg", 5, aim_at(13), "mg", 13, aim_at(40))
	var t: int = kill_tick(r[0], r[2])
	check(t >= 20 and t <= 24, "mg kills an unaware target 8 tiles away in about 1.1 s (tick %d)" % t)
	var r2 = duel("sniper", 5, aim_at(35), "mg", 35, aim_at(0))
	check(kill_tick(r2[0], r2[2]) > 30, "sniper needs well over a second even at range")

func test_stillness() -> void:
	print("stillness")
	# A stands still aiming down the corridor; B charges at it. Slower unit wins.
	var r = duel("mg", 5, aim_at(25), "mg", 25, {"path": [{"x": c(15), "y": c(4)}]})
	check(r[0].unit(r[1]).alive and not r[0].unit(r[2]).alive, "stationary mg beats an mg running at it")
	# aiming while moving beats running
	var r2 = duel("mg", 5, {"path": [{"x": c(7), "y": c(4)}], "aim": {"x": c(25), "y": c(4)}}, "mg", 25, {"path": [{"x": c(17), "y": c(4)}]})
	check(r2[0].unit(r2[1]).alive and not r2[0].unit(r2[2]).alive, "aim-walking mg beats a full-speed runner")

func test_first_sight() -> void:
	print("first sight")
	var r = duel("mg", 10, aim_at(20), "mg", 20, aim_at(40))
	check(r[0].unit(r[1]).alive and not r[0].unit(r[2]).alive, "the unit facing the enemy first wins; the surprised one never kills")
	var r2 = duel("mg", 10, aim_at(0), "mg", 20, aim_at(40))
	check(r2[0].unit(r2[1]).alive and r2[0].unit(r2[2]).alive, "back to back: neither sees the other, nobody dies")

func test_symmetric_duel() -> void:
	print("bilateral engagements")
	for turn_no in [1, 2, 3, 4]:
		var s = Sim.create(open_map(), 1)
		s.turn_no = turn_no
		var a = s.add_unit(0, "mg", 10, 4, 0)
		var b = s.add_unit(1, "mg", 20, 4, 1800)
		s.set_orders(a, aim_at(20))
		s.set_orders(b, aim_at(0))
		s.run_turn()
		var alive := int(s.unit(a).alive) + int(s.unit(b).alive)
		check(alive == 1, "identical mutual aim: exactly one survives (turn %d)" % turn_no)

func test_weapon_envelopes() -> void:
	print("weapon envelopes")
	var r = duel("shotgun", 10, aim_at(14), "mg", 14, aim_at(40))
	check(r[0].unit(r[1]).alive and not r[0].unit(r[2]).alive, "shotgun beats mg at 4 tiles")
	var r1 = duel("shotgun", 10, aim_at(14), "mg", 14, aim_at(10))
	check(r1[0].unit(r1[1]).alive and not r1[0].unit(r1[2]).alive, "shotgun beats mg at 4 tiles even when mutually aimed")
	var r2 = duel("shotgun", 10, aim_at(20), "mg", 20, aim_at(10))
	check(not r2[0].unit(r2[1]).alive and r2[0].unit(r2[2]).alive, "mg beats shotgun at 10 tiles (outside shotgun range)")
	var r3 = duel("mg", 12, aim_at(20), "sniper", 20, aim_at(12))
	check(r3[0].unit(r3[1]).alive and not r3[0].unit(r3[2]).alive, "mg beats sniper at 8 tiles")
	var r4 = duel("mg", 10, aim_at(34), "sniper", 34, aim_at(10))
	check(not r4[0].unit(r4[1]).alive and r4[0].unit(r4[2]).alive, "sniper beats mg at 24 tiles")

func test_cover() -> void:
	print("cover")
	var rows := with_col(open_map(), 12, "o", [4])
	# ducked unit behind a half wall cannot be seen or shot by a standing shooter
	var s = Sim.create(rows, 1)
	var shooter = s.add_unit(0, "mg", 5, 4, 0)
	var hider = s.add_unit(1, "mg", 13, 4, 1800)
	s.set_orders(shooter, aim_at(13))
	s.set_orders(hider, {"duck": true, "aim": {"x": c(40), "y": c(4)}})
	s.run_turn()
	check(s.unit(hider).alive, "ducked unit behind a half wall survives")
	check(not s.visible_to_team(0).has(hider), "...and is invisible to the shooter")
	# standing in cover beats standing in the open
	var r = duel("mg", 6, aim_at(13), "mg", 13, aim_at(6), with_col(open_map(), 12, "o", [4]))
	check(not r[0].unit(r[1]).alive and r[0].unit(r[2]).alive, "mg standing in cover beats an equal mg in the open")
	# a ducked unit also cannot see over the wall
	var s2 = Sim.create(with_col(open_map(), 12, "o", [4]), 1)
	var a2 = s2.add_unit(0, "mg", 5, 4, 0)
	var b2 = s2.add_unit(1, "mg", 13, 4, 1800)
	check(s2.visible_to_team(0).has(b2), "standing viewer sees a standing target behind a half wall")
	s2.unit(a2).ducked = true
	check(not s2.visible_to_team(0).has(b2), "ducked viewer cannot see over a half wall")

func test_stance_change() -> void:
	print("stance change")
	var s = Sim.create(open_map(), 1)
	var a = s.add_unit(0, "mg", 10, 4, 0)
	var b = s.add_unit(1, "mg", 18, 4, 1800)
	s.unit(a).ducked = true
	s.set_orders(a, {"duck": false, "aim": {"x": c(18), "y": c(4)}})
	s.set_orders(b, aim_at(10))
	s.run_turn()
	check(not s.unit(a).alive and s.unit(b).alive, "a unit that changes stance loses a duel to one that doesn't")

func test_rocket() -> void:
	print("rocket")
	# rocket flies along the aim line and explodes on the first full wall; the target point is only a direction
	var rows := with_col(open_map(), 20, "#", [3, 4, 5])
	var s = Sim.create(rows, 1)
	var r = s.add_unit(0, "rocket", 5, 4, 0)
	var near = s.add_unit(1, "mg", 19, 4, 1800)
	var far = s.add_unit(1, "mg", 28, 4, 1800)
	s.set_orders(r, {"fire": {"x": c(8), "y": c(4), "tick": 0}})
	s.set_orders(near, aim_at(40))
	s.set_orders(far, aim_at(40))
	s.run_turn()
	var boom: Array = []
	for e in s.events:
		if e["type"] == "explosion":
			boom.append(e)
	check(boom.size() == 1 and boom[0]["x"] > c(18) and boom[0]["x"] < c(20), "rocket explodes at the first wall, not at the target point")
	check(not s.unit(near).alive, "unit next to that wall dies")
	check(s.unit(far).alive, "unit behind the wall but outside the blast survives")
	check(s.map.tile(20, 4) == SimMap.FLOOR, "rocket destroys terrain")
	# half walls: a standing rocketeer fires over them, a ducked one explodes on them
	var low_rows := with_col(open_map(), 10, "o", [4])
	low_rows = with_col(low_rows, 22, "#", [4])
	var s2 = Sim.create(low_rows, 1)
	var r2 = s2.add_unit(0, "rocket", 5, 4, 0)
	s2.set_orders(r2, {"fire": {"x": c(9), "y": c(4), "tick": 0}})
	s2.run_turn()
	check(s2.events.filter(func(e): return e["type"] == "explosion")[0]["x"] > c(20), "standing rocket flies over a half wall and hits the far wall")
	var s3 = Sim.create(with_col(open_map(), 10, "o", [4]), 1)
	var r3 = s3.add_unit(0, "rocket", 5, 4, 0)
	s3.unit(r3).ducked = true
	s3.set_orders(r3, {"fire": {"x": c(9), "y": c(4), "tick": 0}})
	s3.run_turn()
	check(s3.events.filter(func(e): return e["type"] == "explosion")[0]["x"] < c(10), "ducked rocketeer's rocket explodes on the half wall")
	# edge of the field: harmless
	var s4 = Sim.create(open_map(), 1)
	var r4 = s4.add_unit(0, "rocket", 5, 4, 0)
	s4.set_orders(r4, {"fire": {"x": c(30), "y": c(4), "tick": 0}})
	s4.run_turn()
	check(s4.events.filter(func(e): return e["type"] == "explosion").is_empty(), "rocket flying off the map edge explodes nowhere")
	# cooldown: one launch per turn (5 s)
	var s5 = Sim.create(with_col(open_map(), 20, "#", [3, 4, 5]), 1)
	var r5 = s5.add_unit(0, "rocket", 5, 4, 0)
	s5.set_orders(r5, {"fires": [{"x": c(8), "y": c(4), "tick": 0}, {"x": c(8), "y": c(4), "tick": 10}]})
	s5.run_turn()
	check(s5.events.filter(func(e): return e["type"] == "launch").size() == 1, "rocket launcher cannot fire twice inside its 5 s cooldown")

func test_grenade() -> void:
	print("grenade")
	var s = Sim.create(open_map(), 1)
	var g = s.add_unit(0, "grenade", 5, 4, 0)
	var v = s.add_unit(1, "mg", 14, 4, 1800)
	s.set_orders(g, {"fire": {"x": c(14), "y": c(4), "tick": 0}})
	s.set_orders(v, aim_at(40))
	s.run_turn()
	var boom = s.events.filter(func(e): return e["type"] == "explosion")
	check(boom.size() == 1 and boom[0]["tick"] >= 70 and boom[0]["tick"] <= 80, "grenade detonates about 3 s after its 0.8 s launch (tick %d)" % (boom[0]["tick"] if boom.size() > 0 else -1))
	check(not s.unit(v).alive, "target at the landing point dies")
	# bounces off a full wall and does not break it
	var rows := with_col(open_map(), 12, "#", [3, 4, 5])
	var s2 = Sim.create(rows, 1)
	var g2 = s2.add_unit(0, "grenade", 5, 4, 0)
	var v2 = s2.add_unit(1, "mg", 14, 4, 1800)
	s2.set_orders(g2, {"fire": {"x": c(14), "y": c(4), "tick": 0}})
	s2.set_orders(v2, aim_at(40))
	s2.run_turn()
	check(s2.unit(v2).alive and s2.map.tile(12, 4) == SimMap.WALL, "grenade bounces off a wall: target behind it lives, wall stands")
	# ducked grenadier can lob over a half wall in the first half of the flight
	var s3 = Sim.create(with_col(open_map(), 7, "o", [4]), 1)
	var g3 = s3.add_unit(0, "grenade", 5, 4, 0)
	var v3 = s3.add_unit(1, "mg", 14, 4, 1800)
	s3.unit(g3).ducked = true
	s3.set_orders(g3, {"fire": {"x": c(14), "y": c(4), "tick": 0}})
	s3.set_orders(v3, aim_at(40))
	s3.run_turn()
	check(not s3.unit(v3).alive, "grenade clears a nearby half wall and kills the target")
	# friendly fire
	var s4 = Sim.create(open_map(), 1)
	var g4 = s4.add_unit(0, "grenade", 5, 4, 0)
	var f4 = s4.add_unit(0, "mg", 14, 4, 0)
	s4.set_orders(g4, {"fire": {"x": c(14), "y": c(4), "tick": 0}})
	s4.run_turn()
	check(not s4.unit(f4).alive, "explosions harm friendly units")

func test_shield() -> void:
	print("riot shield")
	var r = duel("mg", 5, aim_at(12), "riot", 12, aim_at(0))
	check(r[0].unit(r[2]).alive, "standing shield blocks frontal fire")
	var r2 = duel("mg", 5, aim_at(12), "riot", 12, aim_at(40))
	check(not r2[0].unit(r2[2]).alive, "shield does not protect from behind")
	var r3 = duel("mg", 5, aim_at(12), "riot", 12, {"path": [{"x": c(8), "y": c(4)}]})
	check(not r3[0].unit(r3[2]).alive, "a moving riot unit has no shield")
	var s = Sim.create(open_map(), 1)
	var g = s.add_unit(0, "grenade", 4, 4, 0)
	var sh = s.add_unit(1, "riot", 13, 4, 1800)
	var behind = s.add_unit(1, "mg", 16, 4, 1800)
	s.set_orders(g, {"fire": {"x": c(13), "y": c(4), "tick": 0}})
	s.set_orders(sh, aim_at(0))
	s.set_orders(behind, aim_at(40))
	s.run_turn()
	var boom = s.events.filter(func(e): return e["type"] == "explosion")
	check(not boom.is_empty() and boom[0]["x"] < c(13), "grenade bounces back off the shield")

func test_orders_ignore_cos_focus() -> void:
	print("ignore / continue on sight / focus")
	var s = Sim.create(open_map(), 1)
	var a = s.add_unit(0, "mg", 5, 4, 0)
	var b = s.add_unit(1, "mg", 12, 4, 1800)
	s.set_orders(a, {"aim": {"x": c(12), "y": c(4)}, "ignore": [b]})
	s.set_orders(b, aim_at(40))
	s.run_turn()
	check(s.unit(a).alive and s.unit(b).alive, "ignoring an enemy that looks away: both survive")
	var shots := 0
	for e in s.events:
		if e["type"] == "shot" and e["shooter"] == a:
			shots += 1
	check(shots == 0, "no shots fired at an ignored enemy")
	var s2 = Sim.create(open_map(), 1)
	var a2 = s2.add_unit(0, "mg", 5, 4, 0)
	var b2 = s2.add_unit(1, "mg", 12, 4, 1800)
	s2.set_orders(a2, {"cos": true})
	s2.set_orders(b2, aim_at(0))
	s2.run_turn()
	check(not s2.unit(a2).alive, "continue-on-sight unit does not fight back")
	var s3 = Sim.create(open_map(), 1)
	var a3 = s3.add_unit(0, "mg", 5, 3, 0)
	var near3 = s3.add_unit(1, "mg", 12, 3, 1800)
	var far3 = s3.add_unit(1, "mg", 12, 6, 1800)
	s3.set_orders(a3, {"aim": {"x": c(12), "y": c(6)}, "focus": [far3]})
	s3.set_orders(near3, aim_at(40))
	s3.set_orders(far3, aim_at(40))
	s3.run_turn()
	check(s3.unit(near3).alive, "a focused unit ignores everything else")

func test_commando_devastator() -> void:
	print("campaign units")
	var r = duel("commando", 10, aim_at(14), "shotgun", 14, aim_at(40))
	check(r[0].unit(r[1]).alive and not r[0].unit(r[2]).alive, "commando kills a shotgun first")
	var rows := with_col(open_map(), 30, "#", [3, 4, 5])
	var s = Sim.create(rows, 1)
	var d = s.add_unit(0, "devastator", 5, 4, 0)
	s.set_orders(d, {"fires": [{"x": c(8), "y": c(4), "tick": 0}, {"x": c(8), "y": c(4), "tick": 20}, {"x": c(8), "y": c(4), "tick": 40}]})
	s.run_turn()
	check(s.events.filter(func(e): return e["type"] == "launch").size() >= 3, "devastator fires several rockets in one turn")

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
