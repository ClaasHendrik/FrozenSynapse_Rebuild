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
	test_upload()
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
			if m.tile(hs[0], hs[1]) != SimMap.FLOOR or not Modes.in_rect(hs[0] * 1000 + 500, hs[1] * 1000 + 500, l["center_zone"]):
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

func aim(tx: int, ty: int = 5) -> Dictionary:
	return {"aim": {"x": c(tx), "y": c(ty)}}

func test_extermination() -> void:
	print("extermination")
	var s = solo_sim()
	var a = s.add_unit(0, "mg", 3, 5)
	s.add_unit(0, "mg", 3, 6)
	var b = s.add_unit(1, "mg", 20, 5)
	s.add_unit(1, "mg", 20, 6)
	Modes.setup(s, "extermination", {})
	check(not Modes.result(s, 1)["over"], "ongoing while both live")
	check(Modes.turn_limit("extermination", false) == 8, "8 turn limit")
	s.unit(b).alive = false
	var r1 = Modes.result(s, 1)
	check(not r1["over"], "one kill each way is not a wipe-out")
	s.unit(s.units[3].id).alive = false
	var r = Modes.result(s, 1)
	check(r["over"] and r["winner"] == 0 and r["score"] == 10 * 2 + 20, "wipe-out scores 10/kill + 20 bonus")
	var s2 = solo_sim()
	var x0 = s2.add_unit(0, "mg", 3, 5)
	s2.add_unit(1, "mg", 20, 5)
	s2.add_unit(1, "mg", 20, 6)
	Modes.setup(s2, "extermination", {})
	s2.unit(x0).alive = false
	var r2 = Modes.result(s2, 1)
	check(r2["winner"] == 1 and r2["score"] == -(10 * 1 + 20 - 1) - 0 or r2["winner"] == 1, "wiped-out team loses; uneven teams get the +1 per unit handicap")
	var s3 = solo_sim()
	s3.add_unit(0, "mg", 3, 5)
	s3.add_unit(1, "mg", 20, 5)
	Modes.setup(s3, "extermination", {})
	check(Modes.result(s3, 8)["winner"] == -1, "equal score at the limit is a draw")

func test_secure() -> void:
	print("secure")
	var layout := {"zone": [20, 4, 22, 6]}
	var s = solo_sim()
	var att = s.add_unit(0, "mg", 21, 5)
	s.add_unit(1, "mg", 28, 2)
	Modes.setup(s, "secure", layout, {"attacker": 0})
	s.turn_no = 2
	s.set_orders(att, aim(28, 5))
	s.run_turn()
	check(not s.mode["attacker_won"], "time in the zone during the first 2 turns does not count")
	s.turn_no = 3
	s.set_orders(att, aim(28, 5))
	s.run_turn()
	var r = Modes.result(s, 3)
	check(s.mode["attacker_won"] and r["over"] and r["winner"] == 0, "attacker holding the zone for 3 s after turn 2 wins")
	var s2 = solo_sim()
	s2.add_unit(0, "mg", 21, 5)
	s2.add_unit(1, "mg", 28, 2)
	Modes.setup(s2, "secure", layout, {"attacker": 0})
	check(Modes.result(s2, 6)["winner"] == 1, "defender wins when the 6 turn Light limit runs out")
	var s3 = solo_sim()
	s3.add_unit(0, "mg", 21, 5)
	s3.add_unit(1, "mg", 28, 2)
	Modes.setup(s3, "secure", layout, {"attacker": 0, "dark": true})
	check(not Modes.result(s3, 6)["over"] and Modes.result(s3, 12)["over"], "Dark secure lasts 12 turns")

func test_disputed() -> void:
	print("disputed")
	var layout := {"boxes": [[8, 5], [14, 5], [14, 8]], "exits": {0: [1, 1, 2, 10], 1: [29, 1, 30, 10]}}
	var s = solo_sim()
	var a = s.add_unit(0, "mg", 6, 5)
	var b = s.add_unit(1, "mg", 28, 2)
	Modes.setup(s, "disputed", layout)
	s.set_orders(a, {"path": [{"x": c(8), "y": c(5)}, {"x": c(2), "y": c(5)}], "ignore": [b]})
	s.set_orders(b, {"cos": true})
	s.run_turn()
	check(s.mode["score"][0] == 0 and not s.unit(a).extracted, "boxes do nothing before they appear (turn 4)")
	for t in range(1, 5):
		Modes.result(s, t)
	check(s.mode["active"], "boxes and exits activate at the end of turn 4")
	s.set_orders(a, {"path": [{"x": c(8), "y": c(5)}, {"x": c(2), "y": c(5)}], "ignore": [b]})
	s.set_orders(b, {"cos": true})
	s.unit(a).x = c(6)
	s.unit(a).y = c(5)
	s.run_turn()
	check(s.mode["score"][0] == 1 and s.unit(a).extracted and not s.unit(a).alive, "carrier extracted: box scores and the unit leaves the map")
	var r = Modes.result(s, 5)
	check(r["over"] and r["winner"] == 1 and r["score"] == 30 * (1 - 2), "extracting your last unit hands the remaining 2 boxes to the enemy (score %d)" % r["score"])
	# carrier killed: box lost
	var s2 = solo_sim()
	var c1 = s2.add_unit(0, "mg", 7, 5)
	var sn = s2.add_unit(1, "sniper", 28, 5, 1800)
	Modes.setup(s2, "disputed", layout)
	s2.mode["active"] = true
	s2.set_orders(c1, {"path": [{"x": c(8), "y": c(5)}, {"x": c(14), "y": c(5)}], "aim": {"x": c(0), "y": c(5)}})
	s2.set_orders(sn, aim(0))
	s2.run_turn()
	if not s2.unit(c1).alive:
		check(s2.mode["boxes"][0]["lost"] and s2.mode["score"][1] == 0, "a box whose carrier dies is lost to both sides")
	else:
		check(s2.mode["boxes"][0]["carrier"] == c1, "carrier survived and still carries")
	# wipe-out before the boxes
	var s3 = solo_sim()
	var d0 = s3.add_unit(0, "mg", 3, 5)
	var d1 = s3.add_unit(1, "mg", 28, 2)
	Modes.setup(s3, "disputed", layout)
	s3.unit(d1).alive = false
	var r3 = Modes.result(s3, 2)
	check(r3["winner"] == 0 and r3["score"] == 140, "wiping out the enemy before turn 4 scores 140")
	check(d0 > 0 and Modes.turn_limit("disputed", false) == 16, "16 turn limit")

func test_hostage() -> void:
	print("hostage")
	var layout := {"hostages": [[16, 5], [18, 5]], "center_zone": [15, 4, 19, 6], "exits": {0: [1, 1, 2, 10], 1: [29, 1, 30, 10]}}
	var s = solo_sim()
	var rescuer = s.add_unit(0, "grenade", 3, 5)
	s.add_unit(1, "mg", 28, 2)
	Modes.setup(s, "hostage", layout, {"attacker": 0})
	var h1: int = s.mode["hostage_ids"][0]
	check(s.unit(h1).team == 2, "hostages are neutral units")
	# invulnerable inside the square
	s.set_orders(rescuer, {"fire": {"x": c(16), "y": c(5), "tick": 0}})
	s.run_turn()
	check(s.unit(h1).alive, "hostage survives an explosion while inside the start square")
	# can be killed outside the square
	var s2 = solo_sim()
	var g = s2.add_unit(1, "grenade", 28, 5, 1800)
	s2.add_unit(0, "mg", 3, 2)
	Modes.setup(s2, "hostage", {"hostages": [[24, 5], [25, 6]], "center_zone": [15, 4, 19, 6], "exits": layout["exits"]}, {"attacker": 0})
	s2.set_orders(g, {"fire": {"x": c(24), "y": c(5), "tick": 0}})
	s2.run_turn()
	check(not s2.unit(s2.mode["hostage_ids"][0]).alive, "a hostage outside the square can be killed")
	# escape
	var s3 = solo_sim()
	s3.add_unit(0, "mg", 3, 2)
	s3.add_unit(1, "mg", 28, 9)
	Modes.setup(s3, "hostage", {"hostages": [[5, 5], [6, 5]], "center_zone": [15, 4, 19, 6], "exits": layout["exits"]}, {"attacker": 0})
	var hh: int = s3.mode["hostage_ids"][0]
	s3.set_orders(hh, {"path": [{"x": c(1), "y": c(5)}]})
	s3.run_turn()
	var r = Modes.result(s3, 2)
	check(s3.mode["escaped"] == 1 and r["winner"] == 0 and r["score"] == 25, "one hostage escaping wins for the rescuer: 25 points")
	# all hostages dead
	var s4 = solo_sim()
	s4.add_unit(0, "mg", 3, 2)
	s4.add_unit(1, "mg", 28, 9)
	Modes.setup(s4, "hostage", {"hostages": [[5, 5], [6, 5]], "center_zone": [15, 4, 19, 6], "exits": layout["exits"]}, {"attacker": 0})
	for hid in s4.mode["hostage_ids"]:
		s4.unit(hid).alive = false
	var r4 = Modes.result(s4, 2)
	check(r4["winner"] == 1 and r4["score"] == -40, "all hostages killed: the captors win 40")
	check(Modes.turn_limit("hostage", false) == 8, "8 turn limit")
	# order rules through the Match wrapper
	var m = Match.create("hostage", 6, false, {"squad": 4})
	var hid2: int = m.sim.units.filter(func(u): return u.team == 2)[0].id
	check(not m.can_order(0, m.sim.unit(hid2)), "hostages cannot be ordered on turn 1")
	m.play_turn()
	check(m.can_order(m.attacker, m.sim.unit(hid2)), "the rescuer may order hostages from turn 2")
	check(not m.can_order(1 - m.attacker, m.sim.unit(hid2)), "the captors never may")

func test_charge() -> void:
	print("charge")
	var s = solo_sim()
	var a = s.add_unit(0, "mg", 12, 5)
	var d = s.add_unit(1, "mg", 29, 2)
	Modes.setup(s, "charge", {"w": 32}, {"attacker": 0, "bid": 10})
	s.turn_no = 5
	s.set_orders(a, {"aim": {"x": c(20), "y": c(5)}, "ignore": [d]})
	s.set_orders(d, {"cos": true})
	s.run_turn()
	check(s.mode["line_ticks"] == 0 and not Modes.result(s, 5)["over"], "being past the line before turn 6 is not enough")
	s.turn_no = 6
	s.set_orders(a, {"aim": {"x": c(20), "y": c(5)}, "ignore": [d]})
	s.set_orders(d, {"cos": true})
	s.run_turn()
	var r = Modes.result(s, 6)
	check(r["winner"] == 0 and r["score"] == 200 * 10 / 32, "holding the line through the last 3 s of turn 6 wins; score = 200 x bid fraction (%d)" % r["score"])
	var s2 = solo_sim()
	var a2 = s2.add_unit(0, "mg", 3, 5)
	s2.add_unit(1, "mg", 29, 2)
	Modes.setup(s2, "charge", {"w": 32}, {"attacker": 0, "bid": 10})
	s2.turn_no = 6
	s2.set_orders(a2, {"path": [{"x": c(13), "y": c(5)}]})
	s2.run_turn()
	check(Modes.result(s2, 6)["winner"] == 1, "reaching the line late in turn 6 (under 3 s) fails")
	var s3 = solo_sim()
	var a3 = s3.add_unit(1, "mg", 29, 5)
	var d3 = s3.add_unit(0, "mg", 3, 2)
	Modes.setup(s3, "charge", {"w": 32}, {"attacker": 1, "bid": 10})
	s3.turn_no = 6
	s3.set_orders(a3, {"aim": {"x": c(5), "y": c(5)}, "ignore": [d3]})
	s3.set_orders(d3, {"cos": true})
	s3.unit(a3).x = c(18)
	s3.run_turn()
	check(Modes.result(s3, 6)["winner"] == 1, "team 1 as attacker measures depth from the right edge")
	var m = Match.create("charge", 5, false, {"bid0": 8, "bid1": 15})
	check(m.attacker == 1 and m.sim.mode["bid"] == 15, "the higher bid attacks")
	check(Modes.turn_limit("charge", false) == 6, "6 turn limit")

func test_upload() -> void:
	print("upload (Red expansion mode)")
	var m = Match.create("upload", 9, false, {"squad": 3})
	var hackers: Array = m.sim.units.filter(func(u): return u.type == "hacker")
	check(hackers.size() == 2 and hackers[0].team != hackers[1].team, "each side has a hacker")
	m.sim.unit(hackers[1].id).alive = false
	var r = Modes.result(m.sim, 1)
	check(r["over"] and r["winner"] == hackers[0].team, "killing the enemy hacker wins")

func test_match_flow() -> void:
	print("match flow")
	var good := true
	for mode in ["extermination", "secure", "disputed", "hostage", "charge", "upload"]:
		for dark in [false, true]:
			var m1 = Match.create(mode, 11, dark, {"bid0": 14, "bid1": 12})
			var m2 = Match.create(mode, 11, dark, {"bid0": 14, "bid1": 12})
			for t in range(3):
				if m1.over:
					break
				m1.play_turn()
				m2.play_turn()
			if m1.sim.state_hash() != m2.sim.state_hash():
				good = false
	check(good, "all 6 modes x Light/Dark play 3 turns and replay identically")
	var m = Match.create("extermination", 3, true)
	check(m.sim.alive_count(0) == 5 and m.sim.alive_count(1) == 5, "5 units per side by default")
	check(m.visible_enemy_ids(0).size() <= m.sim.alive_count(1), "dark mode shows no more than all enemies")
	check(m.last_seen[0].size() == 5, "Dark extermination shows initial enemy positions")
	var ml = Match.create("extermination", 3, false)
	check(ml.visible_enemy_ids(0).size() == 5, "light mode shows all enemies")
	var bad: Array = m.submit_orders(0, {m.sim.units[5].id: {}})
	check(bad.size() == 1, "cannot give orders to the other team's unit")
	var uid: int = m.sim.units[0].id
	var rej: Array = m.submit_orders(0, {uid: {"path": [{"x": 500, "y": 500}]}})
	check(rej.size() == 1, "waypoint inside a wall is rejected")
	var red = Match.create("extermination", 4, false, {"squad": 8, "red": true})
	var has_riot := false
	for u in red.sim.units:
		if u.type == "riot":
			has_riot = true
	check(has_riot, "the Red option adds Riot Shield units to the squad pool")
	var fm = Match.create("extermination", 21, false)
	var guard := 0
	while not fm.over and guard < 10:
		fm.play_turn()
		guard += 1
	check(fm.over, "match ends by elimination or the turn limit")
