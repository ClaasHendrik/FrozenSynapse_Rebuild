extends SceneTree
## AI smoke/strength tests. Run: godot --headless --path . -s tests/test_ai.gd

const Match = preload("res://sim/match.gd")
const AI = preload("res://sim/ai.gd")
const Nav = preload("res://sim/nav.gd")
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

func _init() -> void:
	test_nav()
	test_ai_plans_valid()
	test_ai_vs_idle()
	test_ai_vs_ai_modes()
	print("\n%d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)

func test_nav() -> void:
	print("pathfinding")
	var m = SimMap.from_rows([
		"##########",
		"#....#...#",
		"#.##.#.#.#",
		"#.#..#.#.#",
		"#.#.##.#.#",
		"#........#",
		"##########"])
	var p: Array = Nav.find_path(m, 1500, 1500, 8500, 1500)
	check(not p.is_empty(), "finds a path around walls")
	var ok := true
	var px := 1500
	var py := 1500
	for wp in p:
		if not Nav.walk_clear(m, px, py, wp["x"], wp["y"]):
			ok = false
		px = wp["x"]
		py = wp["y"]
	check(ok, "every path segment is walkable")
	check(px == 8500 and py == 1500, "path ends at the target")
	check(Nav.find_path(m, 1500, 1500, 5500, 1500).is_empty(), "wall target is unreachable")
	check(Nav.find_path(m, 1500, 1500, 1500, 1500).size() == 1, "same-spot path is trivial")

func test_ai_plans_valid() -> void:
	print("ai plans")
	var good := true
	var timing := 0
	for mode in ["extermination", "secure", "disputed", "hostage", "charge"]:
		for dark in [false, true]:
			var g = Match.create(mode, 17, dark, {"bid": 14})
			var t0 := Time.get_ticks_msec()
			var orders: Dictionary = AI.plan(g, 1, 17)
			timing = maxi(timing, Time.get_ticks_msec() - t0)
			var rej: Array = g.submit_orders(1, orders)
			if not rej.is_empty() or orders.size() != g.sim.alive_count(1):
				good = false
	check(good, "AI orders accepted for all modes, Light and Dark")
	print("    slowest plan: ", timing, " ms")
	check(timing < 4000, "a plan takes under 4 s")

func idle_game(seed_value: int, ai_team: int):
	return Match.create("extermination", seed_value, false, {"max_turns": 12})

func test_ai_vs_idle() -> void:
	print("ai vs idle opponent")
	var wins := 0
	var losses := 0
	for s in range(1, 7):
		var g = idle_game(s, 0)
		var guard := 0
		while not g.over and guard < 12:
			var o: Dictionary = AI.plan(g, 0, s)
			g.submit_orders(0, o)
			g.play_turn(o)
			guard += 1
		if g.winner == 0:
			wins += 1
		elif g.winner == 1:
			losses += 1
	print("    wins ", wins, " losses ", losses, " of 6")
	check(wins > losses, "AI wins more often than it loses against a passive (but shooting) opponent")

func test_ai_vs_ai_modes() -> void:
	print("ai vs ai full games")
	var finished := 0
	var total := 0
	for mode in ["extermination", "secure", "disputed", "hostage", "charge"]:
		var g = Match.create(mode, 5, false, {"bid": 14})
		var guard := 0
		while not g.over and guard < 25:
			var o0: Dictionary = AI.plan(g, 0, 5 + guard, 6)
			var o1: Dictionary = AI.plan(g, 1, 9 + guard, 6)
			g.submit_orders(0, o0)
			g.submit_orders(1, o1)
			var pending := o0.duplicate()
			pending.merge(o1)
			g.play_turn(pending)
			guard += 1
		total += 1
		if g.over:
			finished += 1
		print("    ", mode, ": turns ", g.turn, " winner ", g.winner, " (", g.reason, ")")
	check(finished == total, "every mode reaches a result")
