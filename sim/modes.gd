extends RefCounted
## Game modes. State lives in sim.mode (a plain Dictionary) so it clones and hashes with the sim.
## Rects are tile coordinates [x0, y0, x1, y1] inclusive.
##
## extermination | secure | disputed | hostage | charge
## Teams 0 and 1 are players; team 2 is neutral (hostages).

const Fx = preload("res://sim/fx.gd")

const PICKUP_RADIUS := 800
const FREE_RADIUS := 1500
const FREE_TICKS := 40

const DEFAULT_MAX_TURNS := {"extermination": 20, "secure": 12, "disputed": 14, "hostage": 12, "charge": 12}

static func in_rect(x: int, y: int, r: Array) -> bool:
	var tx: int = x / Fx.TILE
	var ty: int = y / Fx.TILE
	return tx >= r[0] and tx <= r[2] and ty >= r[1] and ty <= r[3]

## layout keys used: zone, exits, boxes (tiles), hostages (tiles), w
## opts: attacker (0/1), max_turns, bid (charge: depth in tiles from the attacker's edge)
static func setup(sim, name: String, layout: Dictionary, opts: Dictionary = {}) -> void:
	var attacker: int = opts.get("attacker", layout.get("attacker", 0))
	var m := {
		"type": name, "attacker": attacker,
		"max_turns": opts.get("max_turns", DEFAULT_MAX_TURNS[name]),
	}
	match name:
		"secure":
			m["zone"] = layout["zone"].duplicate()
		"disputed":
			m["exits"] = layout["exits"].duplicate(true)
			m["score"] = [0, 0]
			var boxes: Array = []
			for b in layout["boxes"]:
				boxes.append({"x": b[0] * Fx.TILE + 500, "y": b[1] * Fx.TILE + 500, "carrier": -1, "delivered": false})
			m["boxes"] = boxes
		"hostage":
			m["progress"] = {}
			m["freed"] = []
			m["forfeit"] = -1
			for hpos in layout["hostages"]:
				var id: int = sim.add_unit(2, "hostage", hpos[0], hpos[1])
				m["progress"][id] = 0
		"charge":
			m["bid"] = opts.get("bid", 12)
			m["w"] = layout["w"]
	sim.mode = m

## Called at the end of every simulation tick.
static func on_tick(sim) -> void:
	var m: Dictionary = sim.mode
	if m["type"] == "disputed":
		_tick_disputed(sim, m)
	elif m["type"] == "hostage":
		_tick_hostage(sim, m)

static func _tick_disputed(sim, m: Dictionary) -> void:
	var carrying := {}
	for b in m["boxes"]:
		if b["carrier"] >= 0:
			carrying[b["carrier"]] = true
	for b in m["boxes"]:
		if b["delivered"]:
			continue
		if b["carrier"] >= 0:
			var c = sim.unit(b["carrier"])
			if c == null or not c.alive:
				carrying.erase(b["carrier"])
				b["carrier"] = -1
				sim.events.append({"tick": sim.tick, "type": "box_dropped", "x": b["x"], "y": b["y"]})
			else:
				b["x"] = c.x
				b["y"] = c.y
				if in_rect(c.x, c.y, m["exits"][c.team]):
					b["delivered"] = true
					b["carrier"] = -1
					m["score"][c.team] += 1
					carrying.erase(c.id)
					sim.events.append({"tick": sim.tick, "type": "box_delivered", "team": c.team})
				continue
		if b["carrier"] < 0 and not b["delivered"]:
			for u in sim.units:
				if u.alive and u.team < 2 and not carrying.has(u.id) and Fx.dist(u.x, u.y, b["x"], b["y"]) <= PICKUP_RADIUS:
					b["carrier"] = u.id
					carrying[u.id] = true
					sim.events.append({"tick": sim.tick, "type": "box_picked", "unit": u.id})
					break

static func _tick_hostage(sim, m: Dictionary) -> void:
	for e in sim.events:
		if e["tick"] == sim.tick and e["type"] == "kill":
			var v = sim.unit(e["victim"])
			var k = sim.unit(e["killer"])
			if v != null and v.type == "hostage" and k != null and k.team < 2 and m["forfeit"] < 0:
				m["forfeit"] = k.team
	var att: int = m["attacker"]
	for hid in m["progress"].keys():
		var hu = sim.unit(hid)
		if not hu.alive or m["freed"].has(hid):
			continue
		var att_near := false
		var def_near := false
		for u in sim.units:
			if not u.alive or u.team >= 2 or Fx.dist(u.x, u.y, hu.x, hu.y) > FREE_RADIUS:
				continue
			if u.team == att:
				att_near = true
			else:
				def_near = true
		if att_near and not def_near:
			m["progress"][hid] += 1
			if m["progress"][hid] >= FREE_TICKS:
				m["freed"].append(hid)
				hu.alive = false  # evacuated
				sim.events.append({"tick": sim.tick, "type": "hostage_freed", "id": hid})

## Evaluate the match at the end of a turn. winner: 0/1, or -1 for a draw.
static func result(sim, turn: int) -> Dictionary:
	var a0: int = sim.alive_count(0)
	var a1: int = sim.alive_count(1)
	if a0 == 0 and a1 == 0:
		return {"over": true, "winner": -1, "reason": "mutual destruction"}
	if a0 == 0:
		return {"over": true, "winner": 1, "reason": "team 0 eliminated"}
	if a1 == 0:
		return {"over": true, "winner": 0, "reason": "team 1 eliminated"}
	var m: Dictionary = sim.mode
	var att: int = m["attacker"]
	var dfn: int = 1 - att
	var timed_out: bool = turn >= m["max_turns"]
	match m["type"]:
		"secure":
			var att_in := 0
			var def_in := 0
			for u in sim.units:
				if u.alive and u.team < 2 and in_rect(u.x, u.y, m["zone"]):
					if u.team == att:
						att_in += 1
					else:
						def_in += 1
			if att_in > 0 and def_in == 0:
				return {"over": true, "winner": att, "reason": "zone secured"}
		"charge":
			var w: int = m["w"]
			for u in sim.units:
				if u.alive and u.team == att:
					var depth: int = u.x / Fx.TILE if att == 0 else (w - 1 - u.x / Fx.TILE)
					if depth >= m["bid"]:
						return {"over": true, "winner": att, "reason": "bid fulfilled"}
		"hostage":
			if m["forfeit"] >= 0:
				return {"over": true, "winner": 1 - m["forfeit"], "reason": "hostage killed"}
			if m["freed"].size() == m["progress"].size():
				return {"over": true, "winner": att, "reason": "all hostages freed"}
		"disputed":
			var total: int = m["boxes"].size()
			for t in range(2):
				if m["score"][t] * 2 > total:
					return {"over": true, "winner": t, "reason": "majority of boxes extracted"}
			if timed_out:
				if m["score"][0] == m["score"][1]:
					return {"over": true, "winner": -1, "reason": "time up, tied"}
				return {"over": true, "winner": 0 if m["score"][0] > m["score"][1] else 1, "reason": "time up"}
	if timed_out:
		if m["type"] == "extermination":
			return {"over": true, "winner": -1, "reason": "time up"}
		return {"over": true, "winner": dfn, "reason": "defender held out"}
	return {"over": false, "winner": -2, "reason": ""}
