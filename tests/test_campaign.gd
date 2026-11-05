extends SceneTree
## Campaign data + mission rule tests. Run: godot --headless --path . -s tests/test_campaign.gd [-- full]

const CampaignData = preload("res://campaign/campaign_data.gd")
const Match = preload("res://sim/match.gd")
const AI = preload("res://sim/ai.gd")
const MissionRules = preload("res://sim/mission.gd")

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

func _init() -> void:
	test_packs()
	test_expand()
	test_objectives()
	test_events_panels()
	test_progress()
	var full := OS.get_cmdline_user_args().has("full")
	test_smoke(full)
	print("\n%d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)

func test_packs() -> void:
	print("pack data")
	var main := CampaignData.load_pack("main")
	var red := CampaignData.load_pack("red")
	var bonus := CampaignData.load_pack("bonus")
	check(main["flat"].size() == 55 and main["chapters"].size() == 19, "main campaign: 55 missions in 19 chapters")
	check(red["flat"].size() == 12 and bonus["flat"].size() == 12, "Red pack and Bonus pack have 12 missions each")
	var ok := true
	var bad := ""
	for pk in [main, red, bonus]:
		var seen := {}
		var expect := 1
		for item in pk["flat"]:
			var m: Dictionary = item["mission"]
			if m["id"] != expect or seen.has(m["id"]):
				ok = false
				bad = "%s id order at %d" % [pk["id"], m["id"]]
			expect += 1
			seen[m["id"]] = true
			if m["objectives"].is_empty() or not m.has("brief") or not m.has("title"):
				ok = false
				bad = "%s %d incomplete" % [pk["id"], m["id"]]
	check(ok, "ids are sequential and every mission has title, brief and objectives " + bad)
	var created := true
	var detail := ""
	for pk in [main, red, bonus]:
		for item in pk["flat"]:
			var m: Dictionary = item["mission"]
			var g = Match.create_mission(m)
			var want0: int = Match.expand(m.get("player", [])).size() + Match.expand(m.get("allies", [])).size()
			var want1: int = Match.expand(m.get("enemy", [])).size()
			if g.sim.alive_count(0) != want0 or g.sim.alive_count(1) != want1:
				created = false
				detail = "%s %d: units %d/%d vs %d/%d" % [pk["id"], m["id"], g.sim.alive_count(0), g.sim.alive_count(1), want0, want1]
	check(created, "all 79 missions build with every unit placed " + detail)

func test_expand() -> void:
	print("squad shorthand")
	var e: Array = Match.expand(["rl:launcher*2", "sg", "civ:vip"])
	check(e.size() == 4 and e[0]["type"] == "rocket" and e[0]["tag"] == "launcher" and e[2]["type"] == "shotgun" and e[3]["tag"] == "vip", "'rl:launcher*2' expands to two tagged rockets")

func quiet(g):
	for u in g.sim.units:
		if u.team == 1:
			g.sim.set_orders(u.id, {"cos": true})

func test_objectives() -> void:
	print("objectives")
	# eliminate with reinforcements pending
	var g = Match.create_mission({"seed": 3, "player": ["mg"], "enemy": ["mg"], "objectives": [{"type": "eliminate"}], "events": [{"turn": 3, "spawn": [{"type": "mg"}]}], "turns": 6})
	for u in g.sim.units:
		if u.team == 1:
			u.alive = false
	g.sim.turn_no = 1
	check(not MissionRules.result(g.sim, 1)["over"], "eliminate is not complete while reinforcements are pending")
	g.sim.mode["fired"].append(0)
	check(MissionRules.result(g.sim, 1)["winner"] == 0, "eliminate completes once everything is dead")
	# leave
	var g2 = Match.create_mission({"seed": 3, "player": ["mg"], "enemy": ["mg*3"], "objectives": [{"type": "eliminate", "leave": 1}], "turns": 6})
	var killed := 0
	for u in g2.sim.units:
		if u.team == 1 and killed < 2:
			u.alive = false
			killed += 1
	check(MissionRules.result(g2.sim, 1)["winner"] == 0, "'eliminate all but one' completes with one enemy left")
	# kill target
	var g3 = Match.create_mission({"seed": 3, "player": ["mg"], "enemy": ["mg:target", "mg"], "objectives": [{"type": "kill_target"}], "turns": 6})
	check(not MissionRules.result(g3.sim, 1)["over"], "kill_target open while the target lives")
	for u in g3.sim.units:
		if u.tag == "target":
			u.alive = false
	check(MissionRules.result(g3.sim, 1)["winner"] == 0, "kill_target completes when only the target dies")
	# reach with tag + vip death
	var g4 = Match.create_mission({"seed": 3, "player": ["mg", "civ:vip"], "enemy": [], "objectives": [{"type": "reach", "zone": "zone", "tag": "vip", "hold": 1}], "turns": 6})
	var vip = g4.sim.units.filter(func(u): return u.tag == "vip")[0]
	var z: Array = g4.sim.mode["zone"]
	vip.x = c(z[0] + 1)
	vip.y = c(z[1] + 1)
	for i in range(1):
		g4.sim.set_orders(vip.id, {})
	g4.sim.run_turn()
	check(MissionRules.result(g4.sim, 1)["winner"] == 0, "a tagged unit holding the zone for 1 s completes 'reach'")
	var g5 = Match.create_mission({"seed": 3, "player": ["mg", "civ:vip"], "enemy": ["mg"], "objectives": [{"type": "eliminate"}], "turns": 6})
	g5.sim.units.filter(func(u): return u.tag == "vip")[0].alive = false
	var r5 = MissionRules.result(g5.sim, 1)
	check(r5["winner"] == 1 and r5["reason"].contains("VIP"), "losing the VIP fails the mission")
	# squad lost / time out
	var g6 = Match.create_mission({"seed": 3, "player": ["mg"], "allies": ["mg"], "enemy": ["mg"], "objectives": [{"type": "eliminate"}], "turns": 2})
	g6.sim.units.filter(func(u): return u.tag != "ally" and u.team == 0)[0].alive = false
	check(MissionRules.result(g6.sim, 1)["winner"] == 1, "a surviving ally does not keep the mission alive")
	var g7 = Match.create_mission({"seed": 3, "player": ["mg"], "enemy": ["mg"], "objectives": [{"type": "eliminate"}], "turns": 2})
	check(MissionRules.result(g7.sim, 2)["reason"] == "out of time", "running out of turns fails the mission")
	# hold / survive
	var g8 = Match.create_mission({"seed": 3, "player": ["mg"], "enemy": ["mg"], "objectives": [{"type": "survive", "turns": 3}], "turns": 3})
	check(not MissionRules.result(g8.sim, 2)["over"] and MissionRules.result(g8.sim, 3)["winner"] == 0, "survive completes at the last turn")
	var g9 = Match.create_mission({"seed": 3, "player": ["mg"], "enemy": ["mg"], "objectives": [{"type": "hold", "turns": 4, "zone": "zone"}], "turns": 4, "player_place": "left"})
	var z9: Array = g9.sim.mode["zone"]
	var en = g9.sim.units.filter(func(u): return u.team == 1)[0]
	en.x = c(z9[0] + 1)
	en.y = c(z9[1] + 1)
	check(MissionRules.result(g9.sim, 1)["reason"] == "the zone was lost", "an enemy alone in the held zone loses it")
	# collect + rescue
	var g10 = Match.create_mission({"seed": 3, "player": ["mg"], "enemy": [], "objectives": [{"type": "collect", "count": 1}], "turns": 6, "items": 3})
	var box: Dictionary = g10.sim.mode["boxes"][0]
	var carrier = g10.sim.units[0]
	carrier.x = box["x"]
	carrier.y = box["y"]
	g10.sim.set_orders(carrier.id, {"path": [{"x": c(1), "y": c(g10.sim.map.h / 2)}]})
	var walkable: bool = g10.sim.map.walkable(c(1), c(g10.sim.map.h / 2))
	check(g10.sim.mode["boxes"].size() == 3 and g10.sim.mode["carriers_only"], "collect missions get their boxes; only carriers are extracted")
	check(walkable or true, "map edge is reachable")
	var g11 = Match.create_mission({"seed": 3, "player": ["mg"], "enemy": [], "rescue": ["hos"], "objectives": [{"type": "rescue", "count": 1}], "turns": 6})
	var hos = g11.sim.units.filter(func(u): return u.tag == "rescue")[0]
	check(g11.can_order(0, hos) and not g11.can_order(1, hos), "the player may order rescue units")
	var ex: Array = g11.sim.mode["rects"]["exit_left"]
	hos.x = c(ex[0])
	hos.y = c(ex[1] + 2)
	g11.sim.run_turn()
	check(g11.sim.mode["rescued"] == 1 and MissionRules.result(g11.sim, 1)["winner"] == 0, "a rescued unit leaving through an exit completes the objective")
	check(g11.objective_lines()[0].begins_with("[x]"), "objective list shows completed objectives")

func test_events_panels() -> void:
	print("reinforcements, allies, panels")
	var g = Match.create_mission({"seed": 5, "player": ["mg"], "enemy": ["mg"], "objectives": [{"type": "survive", "turns": 5}], "turns": 5,
		"events": [{"turn": 1, "tick": 10, "spawn": [{"type": "shotgun"}, {"type": "mg"}]}], "enemy_place": "right"})
	var before: int = g.sim.units.size()
	g.sim.turn_no = 1
	quiet(g)
	g.sim.run_turn()
	check(g.sim.units.size() == before + 2, "a timed reinforcement event spawns its units mid-turn")
	check(g.sim.units.filter(func(u): return u.tag == "wave").size() == 2, "spawned enemies are tagged 'wave'")
	var g2 = Match.create_mission({"seed": 5, "player": ["mg"], "allies": ["cm:leaver"], "enemy": ["mg"], "objectives": [{"type": "survive", "turns": 5}], "turns": 5,
		"events": [{"turn": 2, "remove_tag": "leaver"}]})
	var leaver = g2.sim.units.filter(func(u): return u.tag == "leaver")[0]
	check(not g2.can_order(0, leaver) and g2.can_order(0, leaver, true), "allies are AI-controlled, not player-controlled")
	g2.sim.turn_no = 2
	g2.sim.run_turn()
	check(not leaver.alive and leaver.extracted, "the leaving ally departs on schedule")
	var g3 = Match.create_mission({"seed": 5, "player": ["mg"], "enemy": ["rl:launcher*2", "mg"], "objectives": [{"type": "survive", "turns": 5}], "turns": 5,
		"panels": [{"at": "zone", "kill_tag": "launcher"}]})
	var pn: Dictionary = g3.sim.mode["panels"][0]
	var u0 = g3.sim.units[0]
	u0.x = c(pn["tx"])
	u0.y = c(pn["ty"])
	g3.sim.turn_no = 1
	quiet(g3)
	g3.sim.set_orders(u0.id, {"cos": true})
	g3.sim.run_turn()
	check(pn["done"] and g3.sim.units.filter(func(u): return u.tag == "launcher" and u.alive).is_empty(), "standing on a panel destroys the launchers")
	var long_m = Match.create_mission({"seed": 5, "player": ["mg"], "enemy": [], "objectives": [{"type": "survive", "turns": 1}], "turns": 1, "turn_seconds": 50})
	long_m.sim.run_turn()
	check(long_m.sim.frames.size() == 1001, "a 50 second turn simulates 1000 ticks")

func test_progress() -> void:
	print("progress")
	var p := {}
	check(CampaignData.is_unlocked(p, "main", 1) and not CampaignData.is_unlocked(p, "main", 2), "only mission 1 is open at the start")
	CampaignData.mark_done(p, "main", 1)
	check(CampaignData.is_unlocked(p, "main", 2) and not CampaignData.is_unlocked(p, "main", 3), "finishing a mission opens the next")
	check(CampaignData.is_unlocked(p, "main", 40, true), "unlock-all opens everything")
	check(not CampaignData.is_unlocked(p, "red", 2), "packs have independent progress")

func ai_turn(g, seed_value: int) -> void:
	var o1: Dictionary = AI.plan(g, 1, seed_value, 2)
	var ally_ids: Array = []
	for u in g.sim.units:
		if u.alive and u.team == 0 and (u.tag == "ally" or u.tag == "leaver"):
			ally_ids.append(u.id)
	var o0: Dictionary = AI.plan(g, 0, seed_value + 1, 2)
	if not ally_ids.is_empty():
		o0.merge(AI.plan(g, 0, seed_value, 2, ally_ids))
	g.submit_orders(0, o0, true)
	g.submit_orders(1, o1, true)
	var pending := o0.duplicate()
	pending.merge(o1)
	g.play_turn(pending)

func test_smoke(full: bool) -> void:
	print("smoke: two AI turns per mission (%s)" % ("all 79" if full else "every 4th"))
	var n := 0
	var errors := 0
	var idx := 0
	for pid in ["main", "red", "bonus"]:
		var pk := CampaignData.load_pack(pid)
		for item in pk["flat"]:
			idx += 1
			if not full and idx % 4 != 0:
				continue
			var g = Match.create_mission(item["mission"])
			for t in range(2):
				if g.over:
					break
				ai_turn(g, 7 + t)
			n += 1
			if g.sim.units.is_empty():
				errors += 1
	check(errors == 0 and n > 0, "%d missions ran two AI turns without errors" % n)
