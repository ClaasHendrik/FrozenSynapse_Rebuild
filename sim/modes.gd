extends RefCounted
## Game modes (rules: docs/RULES_REFERENCE.md). State lives in sim.mode (a plain Dictionary) so it
## clones and hashes with the sim. Rects are tile coordinates [x0, y0, x1, y1] inclusive.
##
## extermination | secure | disputed | hostage | charge | upload
## Teams 0 and 1 are players; team 2 is neutral (hostages/civilians).
## Scores are reported relative to team 0 (player 1), as in the original.

const Fx = preload("res://sim/fx.gd")
const MissionRules = preload("res://sim/mission.gd")

const PICKUP_RADIUS := 800
const SECURE_HOLD_TICKS := 60      # 3 s inside the zone
const CHARGE_HOLD_TICKS := 60      # last 3 s of the final turn

static func turn_limit(name: String, dark: bool) -> int:
	match name:
		"extermination": return 8
		"secure": return 12 if dark else 6
		"disputed": return 16
		"hostage": return 8
		"charge": return 6
		"upload": return 8
	return 8

static func in_rect(x: int, y: int, r: Array) -> bool:
	var tx: int = x / Fx.TILE
	var ty: int = y / Fx.TILE
	return tx >= r[0] and tx <= r[2] and ty >= r[1] and ty <= r[3]

static func _count(sim, team: int) -> int:
	var n := 0
	for u in sim.units:
		if u.team == team:
			n += 1
	return n

## layout keys used: zone, exits, boxes (tiles), hostages (tiles), center_zone, w
## opts: attacker (0/1), max_turns, dark (bool), bid (charge: tiles from the attacker's edge)
static func setup(sim, name: String, layout: Dictionary, opts: Dictionary = {}) -> void:
	var attacker: int = opts.get("attacker", layout.get("attacker", 0))
	var m := {
		"type": name, "attacker": attacker,
		"max_turns": opts.get("max_turns", turn_limit(name, opts.get("dark", false))),
		"init": [_count(sim, 0), _count(sim, 1)],
	}
	match name:
		"secure":
			m["zone"] = layout["zone"].duplicate()
			m["zone_ticks"] = {}
			m["attacker_won"] = false
		"disputed":
			m["exits"] = layout["exits"].duplicate(true)
			m["score"] = [0, 0]
			m["active"] = false
			var boxes: Array = []
			for b in layout["boxes"]:
				boxes.append({"x": b[0] * Fx.TILE + 500, "y": b[1] * Fx.TILE + 500, "carrier": -1, "delivered": false, "lost": false})
			m["boxes"] = boxes
		"hostage":
			m["square"] = layout["center_zone"].duplicate()
			m["exits"] = layout["exits"].duplicate(true)
			m["hostage_ids"] = []
			m["escaped"] = 0
			for hpos in layout["hostages"]:
				var id: int = sim.add_unit(2, "hostage", hpos[0], hpos[1])
				m["hostage_ids"].append(id)
		"charge":
			m["bid"] = opts.get("bid", 12)
			m["w"] = layout["w"]
			m["line_ticks"] = 0
		"upload":
			pass
	sim.mode = m

static func is_protected(sim, u) -> bool:
	var m: Dictionary = sim.mode
	return not m.is_empty() and m["type"] == "hostage" and u.type == "hostage" and in_rect(u.x, u.y, m["square"])

## True if a hostage may be given orders (rescuer only, from turn 2, only while still inside the square).
static func hostage_orderable(sim, u) -> bool:
	var m: Dictionary = sim.mode
	return m["type"] == "hostage" and u.type == "hostage" and u.alive and sim.turn_no >= 2 and in_rect(u.x, u.y, m["square"])

## Called at the end of every simulation tick.
static func on_tick(sim) -> void:
	var m: Dictionary = sim.mode
	match m["type"]:
		"mission":
			MissionRules.on_tick(sim, m)
		"secure":
			_tick_secure(sim, m)
		"disputed":
			if m["active"]:
				_tick_disputed(sim, m)
		"hostage":
			_tick_hostage(sim, m)
		"charge":
			_tick_charge(sim, m)

static func _tick_secure(sim, m: Dictionary) -> void:
	if sim.turn_no < 3:
		return
	for u in sim.units:
		if u.team == m["attacker"] and u.alive:
			if in_rect(u.x, u.y, m["zone"]):
				m["zone_ticks"][u.id] = m["zone_ticks"].get(u.id, 0) + 1
				if m["zone_ticks"][u.id] >= SECURE_HOLD_TICKS:
					m["attacker_won"] = true
			else:
				m["zone_ticks"].erase(u.id)
		elif u.team == m["attacker"]:
			m["zone_ticks"].erase(u.id)

static func _past_line(m: Dictionary, u) -> bool:
	var tx: int = u.x / Fx.TILE
	var depth: int = tx if m["attacker"] == 0 else (m["w"] - 1 - tx)
	return depth >= m["bid"]

static func _tick_charge(sim, m: Dictionary) -> void:
	if sim.turn_no != m["max_turns"] or sim.tick <= 40:
		return
	var ok := false
	for u in sim.units:
		if u.alive and u.team == m["attacker"] and _past_line(m, u):
			ok = true
	m["line_ticks"] = m["line_ticks"] + 1 if ok else 0

static func _tick_disputed(sim, m: Dictionary) -> void:
	for b in m["boxes"]:
		if b["delivered"] or b["lost"]:
			continue
		if b["carrier"] >= 0:
			var c = sim.unit(b["carrier"])
			if not c.alive:
				b["lost"] = true
				b["carrier"] = -1
				sim.events.append({"tick": sim.tick, "type": "box_lost", "x": b["x"], "y": b["y"]})
			else:
				b["x"] = c.x
				b["y"] = c.y
	var carrying := {}
	for b in m["boxes"]:
		if b["carrier"] >= 0:
			carrying[b["carrier"]] = true
	for b in m["boxes"]:
		if b["delivered"] or b["lost"] or b["carrier"] >= 0:
			continue
		for u in sim.units:
			if m.get("player_only", false) and u.team != 0:
				continue
			if u.alive and u.team < 2 and not carrying.has(u.id) and Fx.dist(u.x, u.y, b["x"], b["y"]) <= PICKUP_RADIUS:
				b["carrier"] = u.id
				carrying[u.id] = true
				sim.events.append({"tick": sim.tick, "type": "box_picked", "unit": u.id})
				break
	# extraction: any unit entering a green edge zone leaves the map (carrying or not)
	for u in sim.units:
		if not u.alive or u.team >= 2:
			continue
		var out := false
		for t in range(2):
			if in_rect(u.x, u.y, m["exits"][t]):
				out = true
		if not out:
			continue
		if m.get("carriers_only", false) and not carrying.has(u.id):
			continue
		for b in m["boxes"]:
			if b["carrier"] == u.id:
				b["delivered"] = true
				b["carrier"] = -1
				m["score"][u.team] += 1
				sim.events.append({"tick": sim.tick, "type": "box_delivered", "team": u.team})
		u.alive = false
		u.extracted = true
		sim.events.append({"tick": sim.tick, "type": "extracted", "unit": u.id})

static func _tick_hostage(sim, m: Dictionary) -> void:
	for hid in m["hostage_ids"]:
		var h = sim.unit(hid)
		if not h.alive:
			continue
		for t in range(2):
			if in_rect(h.x, h.y, m["exits"][t]):
				h.alive = false
				h.extracted = true
				m["escaped"] += 1
				sim.events.append({"tick": sim.tick, "type": "hostage_escaped", "id": hid})
				break

# ------------------------------------------------------------------ results

static func _signed(score_for_winner: int, winner: int) -> int:
	if winner < 0:
		return 0
	return score_for_winner if winner == 0 else -score_for_winner

static func _done(winner: int, reason: String, score: int) -> Dictionary:
	return {"over": true, "winner": winner, "reason": reason, "score": score}

static func _by_score(score0: int, reason: String) -> Dictionary:
	if score0 > 0:
		return _done(0, reason, score0)
	if score0 < 0:
		return _done(1, reason, score0)
	return _done(-1, reason + " (draw)", 0)

## Evaluate the match at the end of turn number `turn` (1-based). winner: 0/1, or -1 for a draw.
static func result(sim, turn: int) -> Dictionary:
	var m: Dictionary = sim.mode
	if m["type"] == "mission":
		return MissionRules.result(sim, turn)
	var a0: int = sim.alive_count(0)
	var a1: int = sim.alive_count(1)
	var att: int = m["attacker"]
	var dfn: int = 1 - att
	var timed_out: bool = turn >= m["max_turns"]
	var alive: Array = [a0, a1]
	match m["type"]:
		"extermination":
			var k0: int = m["init"][1] - a1
			var k1: int = m["init"][0] - a0
			var s0: int = 10 * k0 - 10 * k1 + (m["init"][1] - m["init"][0])
			if a0 == 0 and a1 == 0:
				return _by_score(s0, "mutual destruction")
			if a1 == 0:
				return _done(0, "wipe-out", s0 + 20)
			if a0 == 0:
				return _done(1, "wipe-out", s0 - 20)
			if timed_out:
				return _by_score(s0, "time up")
		"secure":
			var area: int = (m["zone"][2] - m["zone"][0] + 1) * (m["zone"][3] - m["zone"][1] + 1)
			var win_score: int = mini(200, 50 + 150 * mini(area, 16) / 16)
			if m["attacker_won"]:
				return _done(att, "zone secured", _signed(win_score, att))
			if alive[att] == 0:
				return _done(dfn, "attackers eliminated", _signed(win_score, dfn))
			if alive[dfn] == 0:
				return _done(att, "defenders eliminated", _signed(win_score, att))
			if timed_out:
				return _done(dfn, "defender held out", _signed(win_score, dfn))
		"charge":
			var frac: int = 1000 * m["bid"] / m["w"]
			var win_score2: int = 200 * frac / 1000
			if alive[dfn] == 0 and turn < m["max_turns"]:
				return _done(att, "defenders eliminated", _signed(win_score2, att))
			if alive[att] == 0:
				return _done(dfn, "attackers eliminated", _signed(win_score2, dfn))
			if timed_out:
				if m["line_ticks"] >= CHARGE_HOLD_TICKS:
					return _done(att, "bid fulfilled", _signed(win_score2, att))
				return _done(dfn, "defender held out", _signed(win_score2, dfn))
		"hostage":
			var dead := 0
			for hid in m["hostage_ids"]:
				var h = sim.unit(hid)
				if not h.alive and not h.extracted:
					dead += 1
			var escaped: int = m["escaped"]
			if escaped > 0:
				return _done(att, "hostage escaped", _signed(25 * escaped, att))
			if dead == m["hostage_ids"].size():
				return _done(dfn, "hostages killed", _signed(40, dfn))
			if alive[dfn] == 0:
				return _done(att, "captors eliminated", _signed(25, att))
			if alive[att] == 0:
				return _done(dfn, "rescuers eliminated", _signed(40, dfn))
			if timed_out:
				return _done(dfn, "time up", _signed(40, dfn))
		"disputed":
			if not m["active"]:
				if a0 == 0 and a1 == 0:
					return _done(-1, "mutual destruction", 0)
				if a1 == 0:
					return _done(0, "wipe-out before the boxes appeared", 140)
				if a0 == 0:
					return _done(1, "wipe-out before the boxes appeared", -140)
				if turn >= 4:
					m["active"] = true
			else:
				var s: Array = m["score"].duplicate()
				var end_by := ""
				if a0 == 0 or a1 == 0 or timed_out:
					end_by = "time up" if (a0 > 0 and a1 > 0) else "one side gone"
					if a0 > 0 or a1 > 0:
						# remaining boxes go to the side still on the field
						var holder: int = 0 if a0 > 0 else 1
						if a0 > 0 and a1 > 0:
							holder = -1
						for b in m["boxes"]:
							if not b["delivered"] and not b["lost"] and holder >= 0:
								s[holder] += 1
					return _by_score(30 * (s[0] - s[1]), end_by)
		"upload":
			var h0 := false
			var h1 := false
			for u in sim.units:
				if u.type == "hacker" and u.alive:
					if u.team == 0:
						h0 = true
					else:
						h1 = true
			if not h0 and not h1:
				return _done(-1, "both hackers lost", 0)
			if not h1:
				return _done(0, "enemy hacker eliminated", 100)
			if not h0:
				return _done(1, "enemy hacker eliminated", -100)
			if timed_out:
				return _done(-1, "time up", 0)
	return {"over": false, "winner": -2, "reason": "", "score": 0}
