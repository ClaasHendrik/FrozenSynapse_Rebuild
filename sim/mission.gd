extends RefCounted
## Campaign mission rules. State lives in sim.mode (type "mission"), so it clones/hashes with the sim.
## Winner convention here: 0 = the player completes the mission, 1 = the mission is failed.
##
## Objectives (all must be met):
##   eliminate   {leave}            enemy count <= leave and no reinforcements pending
##   kill_target                    every unit tagged "target" is dead
##   reach       {zone, tag, hold}  a (tagged) player unit stays in a zone for `hold` seconds
##   collect     {count}            carry `count` boxes into an exit zone
##   rescue      {count}            lead `count` units tagged "rescue" into an exit zone
##   hold        {turns, zone}      survive `turns` turns without losing the zone to the enemy
##   survive     {turns}            survive `turns` turns
## Failure: whole squad dead, a "vip" dead, rescue impossible, or the turn limit passes.

const Fx = preload("res://sim/fx.gd")
const Nav = preload("res://sim/nav.gd")

const PANEL_TICKS := 40
const PANEL_RADIUS := 1300

static func _modes():
	return load("res://sim/modes.gd")

static func squad_alive(sim) -> int:
	var n := 0
	for u in sim.units:
		if u.alive and u.team == 0 and u.tag != "ally" and u.tag != "leaver":
			n += 1
	return n

## Build the mode state. `rects` maps names to tile rects: zone, center, exit_left, exit_right.
static func build_state(mission: Dictionary, rects: Dictionary, items: Array, panels: Array, wave_tiles: Array, max_turns: int, init: Array) -> Dictionary:
	var m := {
		"type": "mission", "attacker": 0, "max_turns": max_turns, "init": init,
		"enemy_style": mission.get("enemy_style", "aggressive"),
		"objectives": [], "events": [], "fired": [], "wave_tiles": wave_tiles, "wave_cursor": 0,
		"panels": panels, "rescued": 0, "rects": rects,
		"exits": {0: rects["exit_left"], 1: rects["exit_right"]},
		"zone": rects["zone"],
	}
	for o in mission.get("objectives", [{"type": "eliminate"}]):
		var od: Dictionary = o.duplicate(true)
		od["done"] = false
		od["ticks"] = 0
		var rs: Array = []
		var zname: String = od.get("zone", "zone")
		if zname == "exit_any":
			rs = [rects["exit_left"], rects["exit_right"]]
		elif rects.has(zname):
			rs = [rects[zname]]
		od["rects"] = rs
		m["objectives"].append(od)
		if od["type"] == "collect":
			m["boxes"] = []
			for b in items:
				m["boxes"].append({"x": b[0] * Fx.TILE + 500, "y": b[1] * Fx.TILE + 500, "carrier": -1, "delivered": false, "lost": false})
			m["score"] = [0, 0]
			m["active"] = true
			m["carriers_only"] = true
			m["player_only"] = true
	for ev in mission.get("events", []):
		m["events"].append(ev.duplicate(true))
	return m

static func _in_any(rects: Array, x: int, y: int) -> bool:
	var md = _modes()
	for r in rects:
		if md.in_rect(x, y, r):
			return true
	return false

static func on_tick(sim, m: Dictionary) -> void:
	_fire_events(sim, m)
	for p in m["panels"]:
		if p["done"]:
			continue
		var near := false
		for u in sim.units:
			if u.alive and u.team == 0 and Fx.dist(u.x, u.y, p["tx"] * Fx.TILE + 500, p["ty"] * Fx.TILE + 500) <= PANEL_RADIUS:
				near = true
		p["ticks"] = p["ticks"] + 1 if near else 0
		if p["ticks"] >= PANEL_TICKS:
			p["done"] = true
			var tag: String = p["effect"].get("kill_tag", "")
			for u in sim.units:
				if u.alive and u.tag == tag and tag != "":
					u.alive = false
					sim.events.append({"tick": sim.tick, "type": "kill", "victim": u.id, "killer": -1})
			sim.events.append({"tick": sim.tick, "type": "panel", "x": p["tx"], "y": p["ty"]})
	if m.has("boxes"):
		_modes()._tick_disputed(sim, m)
	for o in m["objectives"]:
		if o["type"] == "reach" and not o["done"]:
			var any := false
			for u in sim.units:
				if not u.alive or u.team != 0:
					continue
				if o.get("tag", "") != "" and u.tag != o["tag"]:
					continue
				if o.get("tag", "") == "" and (u.tag == "ally" or u.tag == "rescue"):
					continue
				if _in_any(o["rects"], u.x, u.y):
					any = true
			o["ticks"] = o["ticks"] + 1 if any else 0
			if o["ticks"] >= int(o.get("hold", 3)) * 20:
				o["done"] = true
	# rescued units leave through an exit
	for u in sim.units:
		if u.alive and u.tag == "rescue":
			if _in_any([m["rects"]["exit_left"], m["rects"]["exit_right"]], u.x, u.y):
				u.alive = false
				u.extracted = true
				m["rescued"] += 1
				sim.events.append({"tick": sim.tick, "type": "rescued", "unit": u.id})

static func _fire_events(sim, m: Dictionary) -> void:
	var evs: Array = m["events"]
	for i in range(evs.size()):
		if m["fired"].has(i):
			continue
		var ev: Dictionary = evs[i]
		if sim.turn_no < int(ev.get("turn", 1)):
			continue
		if sim.turn_no == int(ev.get("turn", 1)) and sim.tick < int(ev.get("tick", 1)):
			continue
		m["fired"].append(i)
		if ev.has("remove_tag"):
			for u in sim.units:
				if u.alive and u.tag == ev["remove_tag"]:
					u.alive = false
					u.extracted = true
					sim.events.append({"tick": sim.tick, "type": "extracted", "unit": u.id})
		if ev.has("spawn"):
			spawn_wave(sim, m, ev)

static func spawn_wave(sim, m: Dictionary, ev: Dictionary) -> void:
	var team: int = ev.get("team", 1)
	var tiles: Array = m["wave_tiles"]
	if tiles.is_empty():
		return
	var target: Array = []
	if ev.get("rush", true):
		var z: Array = m["zone"]
		target = [(z[0] + z[2] + 1) * 500, (z[1] + z[3] + 1) * 500]
	for spec in ev["spawn"]:
		var t: Array = tiles[m["wave_cursor"] % tiles.size()]
		m["wave_cursor"] += 1
		var id: int = sim.add_unit(team, spec["type"], t[0], t[1], 1800 if team == 1 else 0, spec.get("tag", "wave" if team == 1 else "ally"))
		sim.events.append({"tick": sim.tick, "type": "reinforcement", "unit": id})
		if not target.is_empty():
			var path: Array = Nav.find_path(sim.map, sim.unit(id).x, sim.unit(id).y, target[0], target[1])
			var wps: Array = []
			for pt in path:
				wps.append({"x": pt["x"], "y": pt["y"], "duck": false})
			sim.set_orders(id, {"path": wps})

static func _pending_spawns(m: Dictionary) -> int:
	var n := 0
	for i in range(m["events"].size()):
		if m["events"][i].has("spawn") and not m["fired"].has(i):
			n += 1
	return n

static func _enemies_alive(sim) -> int:
	var n := 0
	for u in sim.units:
		if u.alive and u.team == 1:
			n += 1
	return n

static func objective_done(sim, m: Dictionary, o: Dictionary, turn: int) -> bool:
	match o["type"]:
		"eliminate":
			return _enemies_alive(sim) <= int(o.get("leave", 0)) and _pending_spawns(m) == 0
		"kill_target":
			for u in sim.units:
				if u.alive and u.tag == "target":
					return false
			return true
		"reach":
			return o["done"]
		"collect":
			return m["score"][0] >= int(o["count"])
		"rescue":
			return m["rescued"] >= int(o["count"])
		"hold", "survive":
			return turn >= int(o["turns"])
	return false

## Human-readable objective lines for the briefing / HUD.
static func describe(o: Dictionary) -> String:
	match o["type"]:
		"eliminate":
			return "Eliminate all enemy units" if int(o.get("leave", 0)) == 0 else "Eliminate all but %d enemy units" % int(o["leave"])
		"kill_target":
			return "Kill the marked target"
		"reach":
			var who: String = "a unit" if o.get("tag", "") == "" else "your %s" % o["tag"]
			return "Get %s into the marked zone for %d s" % [who, int(o.get("hold", 3))]
		"collect":
			return "Carry %d boxes to an edge exit" % int(o["count"])
		"rescue":
			return "Lead %d hostage(s) to an edge exit" % int(o["count"])
		"hold":
			return "Hold the marked zone for %d turns" % int(o["turns"])
		"survive":
			return "Survive %d turns" % int(o["turns"])
	return o["type"]

static func result(sim, turn: int) -> Dictionary:
	var m: Dictionary = sim.mode
	if squad_alive(sim) == 0:
		return {"over": true, "winner": 1, "reason": "your squad was lost", "score": 0}
	for u in sim.units:
		if u.tag == "vip" and not u.alive and not u.extracted:
			return {"over": true, "winner": 1, "reason": "the VIP was killed", "score": 0}
	for o in m["objectives"]:
		if o["type"] == "rescue":
			var left := int(m["rescued"])
			for u in sim.units:
				if u.alive and u.tag == "rescue":
					left += 1
			if left < int(o["count"]):
				return {"over": true, "winner": 1, "reason": "the hostages were lost", "score": 0}
		if o["type"] == "hold" and turn < int(o["turns"]):
			var enemy_in := false
			var mine_in := false
			for u in sim.units:
				if not u.alive:
					continue
				var inside: bool = _in_any(o["rects"], u.x, u.y)
				if inside and u.team == 1:
					enemy_in = true
				if inside and u.team == 0 and u.tag != "ally":
					mine_in = true
			if enemy_in and not mine_in:
				return {"over": true, "winner": 1, "reason": "the zone was lost", "score": 0}
	var all_done := true
	for o in m["objectives"]:
		if not objective_done(sim, m, o, turn):
			all_done = false
	if all_done:
		return {"over": true, "winner": 0, "reason": "objectives complete", "score": 0}
	if turn >= m["max_turns"]:
		return {"over": true, "winner": 1, "reason": "out of time", "score": 0}
	return {"over": false, "winner": -2, "reason": "", "score": 0}
