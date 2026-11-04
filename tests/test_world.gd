extends SceneTree
## Map generator, game modes and match flow.
## Run: godot --headless --path . -s tests/test_world.gd

const Sim = preload("res://sim/simulation.gd")
const MapGen = preload("res://sim/map_gen.gd")
const Modes = preload("res://sim/modes.gd")
const Match = preload("res://sim/match.gd")
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

func open_rows(w: int = 32, h: int = 12) -> Array:
	var rows: Array = []
	for y in range(h):
		var row := ""
		for x in range(w):
			row += "#" if (x == 0 or y == 0 or x == w - 1 or y == h - 1) else "."
		rows.append(row)
	return rows

func _init() -> void:
	test_generator()
	test_extermination()
	test_secure()
	test_disputed()
	test_hostage()
	test_charge()
	test_match_flow()
	print("\n%d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)

func floor_count(rows: Array) -> int:
	var n := 0
	for r in rows:
		n += String(r).count(".")
	return n

func test_generator() -> void:
	print("map generator")
	var all_ok := true
	var distinct := {}
	var wall_share_ok := true
	for seed_value in range(1, 61):
		var l: Dictionary = MapGen.generate(32, 20, seed_value)
		var m = SimMap.from_rows(l["rows"])
		distinct[str(l["rows"]).hash()] = true
		var fl := floor_count(l["rows"])
		if fl < 32 * 20 * 40 / 100 or fl > 32 * 20 * 90 / 100:
			wall_share_ok = false
		for team in range(2):
			for s in l["spawn"][team]:
				if m.tile(s[0], s[1]) != SimMap.FLOOR:
					all_ok = false
		for b in l["boxes"]:
			if m.tile(b[0], b[1]) != SimMap.FLOOR:
				all_ok = false
		for hs in l["hostages"]:
			if m.tile(hs[0], hs[1]) != SimMap.FLOOR:
				all_ok = false
		var z: Array = l["zone"]
		for y in range(z[1], z[3] + 1):
			for x in range(z[0], z[2] + 1):
				if m.tile(x, y) != SimMap.FLOOR:
					all_ok = false
		if l["spawn"][0].size() < 8 or l["spawn"][1].size() < 8:
			all_ok = false
	check(all_ok, "spawns, boxes, hostages and zone sit on floor tiles (60 seeds)")
	check(distinct.size() >= 55, "seeds give varied maps (%d distinct of 60)" % distinct.size())
	check(wall_share_ok, "floor share is between 40% and 90%")
	check(MapGen.generate(32, 20, 5) == MapGen.generate(32, 20, 5), "same seed gives the same map")
	var la: Dictionary = MapGen.generate(32, 20, 9, 1)
	check(la["zone"][0] < 16, "attacker=1 puts defender objectives on the left")

func solo_sim(rows: Array = []):
	return Sim.create(rows if not rows.is_empty() else open_rows(), 1)

func test_extermination() -> void:
	print("extermination")
	var s = solo_sim()
	var a = s.add_unit(0, "mg", 3, 5)
	var b = s.add_unit(1, "mg", 20, 5)
	Modes.setup(s, "extermination", {})
	check(not Modes.result(s, 1)["over"], "ongoing while both live")
	s.unit(b).alive = false
	var r = Modes.result(s, 1)
	check(r["over"] and r["winner"] == 0, "team 0 wins when team 1 is gone")
	s.unit(a).alive = false
	check(Modes.result(s, 1)["winner"] == -1, "both gone is a draw")
	var s2 = solo_sim()
	s2.add_unit(0, "mg", 3, 5)
	s2.add_unit(1, "mg", 20, 5)
	Modes.setup(s2, "extermination", {}, {"max_turns": 3})
	check(Modes.result(s2, 3)["winner"] == -1, "time limit is a draw")

func test_secure() -> void:
	print("secure")
	var layout := {"zone": [20, 4, 22, 6]}
	var s = solo_sim()
	var att = s.add_unit(0, "mg", 3, 5)
	s.add_unit(1, "mg", 28, 2)
	Modes.setup(s, "secure", layout, {"attacker": 0})
	s.set_orders(att, {"path": [{"x": c(21), "y": c(5)}], "ignore": []})
	s.run_turn()
	# 18 tiles at 2 tiles/s needs 9 s: two turns
	check(not Modes.result(s, 1)["over"], "not secured after first turn")
	s.set_orders(att, {"path": [{"x": c(21), "y": c(5)}]})
	s.run_turn()
	var r = Modes.result(s, 2)
	check(r["over"] and r["winner"] == 0, "attacker in zone with no defender wins")
	var s2 = solo_sim()
	s2.add_unit(0, "mg", 21, 5)
	s2.add_unit(1, "mg", 22, 5)
	Modes.setup(s2, "secure", layout, {"attacker": 0})
	check(not Modes.result(s2, 1)["over"], "contested zone is not secured")
	var s3 = solo_sim()
	s3.add_unit(0, "mg", 3, 5)
	s3.add_unit(1, "mg", 28, 2)
	Modes.setup(s3, "secure", layout, {"attacker": 0, "max_turns": 4})
	check(Modes.result(s3, 4)["winner"] == 1, "defender wins on timeout")

func test_disputed() -> void:
	print("disputed")
	var layout := {"boxes": [[8, 5], [14, 5], [14, 8]], "exits": {0: [1, 1, 2, 10], 1: [29, 1, 30, 10]}}
	var s = solo_sim()
	var a = s.add_unit(0, "mg", 6, 5)
	s.add_unit(1, "mg", 28, 2)
	Modes.setup(s, "disputed", layout)
	s.set_orders(a, {"path": [{"x": c(8), "y": c(5)}, {"x": c(2), "y": c(5)}]})
	s.run_turn()
	check(s.mode["score"][0] == 1, "unit picks up a box and extracts it (score 1)")
	check(s.mode["boxes"][0]["delivered"], "box marked delivered")
	# carrier killed drops box
	var s2 = solo_sim()
	var b = s2.add_unit(0, "mg", 7, 5)
	var killer = s2.add_unit(1, "sniper", 28, 5, 1800)
	Modes.setup(s2, "disputed", layout)
	s2.set_orders(b, {"path": [{"x": c(8), "y": c(5)}, {"x": c(14), "y": c(5)}]})
	s2.set_orders(killer, {"aim": {"x": c(0), "y": c(5)}})
	s2.run_turn()
	check(s2.unit(b).alive == false or s2.mode["boxes"][0]["carrier"] == b, "carrier either carries or died")
	if not s2.unit(b).alive:
		check(s2.mode["boxes"][0]["carrier"] == -1 and not s2.mode["boxes"][0]["delivered"], "dead carrier drops the box")
	# majority wins
	var s3 = solo_sim()
	s3.add_unit(0, "mg", 3, 5)
	s3.add_unit(1, "mg", 28, 2)
	Modes.setup(s3, "disputed", layout)
	s3.mode["score"][0] = 2
	check(Modes.result(s3, 1)["winner"] == 0, "2 of 3 boxes is a majority win")

func test_hostage() -> void:
	print("hostage")
	var layout := {"hostages": [[20, 5]]}
	var s = solo_sim()
	var a = s.add_unit(0, "mg", 18, 5)
	s.add_unit(1, "mg", 29, 2)
	Modes.setup(s, "hostage", layout, {"attacker": 0})
	check(s.units.size() == 3 and s.units[2].team == 2, "hostage unit created on team 2")
	s.set_orders(a, {"path": [{"x": c(19), "y": c(5)}], "ignore": []})
	s.run_turn()
	check(s.mode["freed"].size() == 1, "attacker standing next to hostage frees it")
	check(Modes.result(s, 1)["winner"] == 0, "freeing all hostages wins for the attacker")
	# hostage is not a valid target for guns
	var s2 = solo_sim()
	var a2 = s2.add_unit(0, "mg", 10, 5, 0)
	s2.add_unit(1, "mg", 29, 2)
	Modes.setup(s2, "hostage", layout, {"attacker": 0})
	s2.set_orders(a2, {"aim": {"x": c(20), "y": c(5)}})
	s2.run_turn()
	check(s2.units[2].alive, "units do not auto-shoot hostages")
	# killing a hostage forfeits
	var s3 = solo_sim()
	var g = s3.add_unit(0, "grenade", 14, 5, 0)
	s3.add_unit(1, "mg", 29, 2)
	Modes.setup(s3, "hostage", layout, {"attacker": 0})
	s3.set_orders(g, {"fire": {"x": c(20), "y": c(5), "tick": 0}})
	s3.run_turn()
	s3.run_turn()
	check(s3.mode["forfeit"] == 0, "attacker grenade on hostage forfeits for attacker")
	check(Modes.result(s3, 2)["winner"] == 1, "defender wins after forfeit")

func test_charge() -> void:
	print("charge")
	var s = solo_sim()
	var a = s.add_unit(0, "mg", 3, 5)
	s.add_unit(1, "mg", 29, 2)
	Modes.setup(s, "charge", {"w": 32}, {"attacker": 0, "bid": 10})
	check(not Modes.result(s, 1)["over"], "not yet at the bid line")
	s.set_orders(a, {"path": [{"x": c(12), "y": c(5)}]})
	s.run_turn()
	check(Modes.result(s, 1)["winner"] == 0, "reaching the bid depth wins for the attacker")
	var s2 = solo_sim()
	s2.add_unit(0, "mg", 3, 5)
	s2.add_unit(1, "mg", 29, 2)
	Modes.setup(s2, "charge", {"w": 32}, {"attacker": 0, "bid": 25, "max_turns": 3})
	check(Modes.result(s2, 3)["winner"] == 1, "defender wins if the bid is not met in time")
	var s3 = solo_sim()
	var a3 = s3.add_unit(1, "mg", 29, 5)
	s3.add_unit(0, "mg", 3, 2)
	Modes.setup(s3, "charge", {"w": 32}, {"attacker": 1, "bid": 10})
	s3.set_orders(a3, {"path": [{"x": c(20), "y": c(5)}]})
	s3.run_turn()
	check(Modes.result(s3, 1)["winner"] == 1, "team 1 as attacker measures depth from the right edge")

func test_match_flow() -> void:
	print("match flow")
	var good := true
	for mode in ["extermination", "secure", "disputed", "hostage", "charge"]:
		for dark in [false, true]:
			var m1 = Match.create(mode, 11, dark, {"bid": 14})
			var m2 = Match.create(mode, 11, dark, {"bid": 14})
			for t in range(3):
				if m1.over:
					break
				m1.play_turn()
				m2.play_turn()
			if m1.sim.state_hash() != m2.sim.state_hash():
				good = false
	check(good, "all 5 modes x Light/Dark play 3 turns and replay identically")
	var m = Match.create("extermination", 3, true)
	check(m.sim.alive_count(0) == 5 and m.sim.alive_count(1) == 5, "5 units per side by default")
	check(m.visible_enemy_ids(0).size() <= m.sim.alive_count(1), "dark mode shows no more than all enemies")
	var ml = Match.create("extermination", 3, false)
	check(ml.visible_enemy_ids(0).size() == 5, "light mode shows all enemies")
	var bad: Array = m.submit_orders(0, {m.sim.units[5].id: {}})
	check(bad.size() == 1, "cannot give orders to the other team's unit")
	var uid: int = m.sim.units[0].id
	var rej: Array = m.submit_orders(0, {uid: {"path": [{"x": 500, "y": 500}]}})
	check(rej.size() == 1, "waypoint inside a wall is rejected")
	# a long free-for-all finishes or times out without errors
	var fm = Match.create("extermination", 21, false, {"max_turns": 6})
	var guard := 0
	while not fm.over and guard < 10:
		fm.play_turn()
		guard += 1
	check(fm.over, "match ends by elimination or the turn limit")
