extends Control
## The tactical board: draws the map, units and orders, edits orders with the mouse,
## and plays back 5-second replays (real turns and Test previews).

const Fx = preload("res://sim/fx.gd")
const Nav = preload("res://sim/nav.gd")
const Balance = preload("res://sim/balance.gd")
const SimMap = preload("res://sim/grid_map.gd")
const Modes = preload("res://sim/modes.gd")

signal orders_changed
signal selection_changed
signal replay_finished(was_test: bool)

const COL_BG := Color("070b16")
const COL_FLOOR := Color("0d1630")
const COL_GRID := Color("14234a")
const COL_WALL := Color("2d8cff")
const COL_WALL_EDGE := Color("8fd0ff")
const COL_LOW := Color("2a5fa8")
const TEAM_COL := [Color("39ff88"), Color("ff4d5e"), Color("ffd24a")]
const LETTER := {"mg": "M", "shotgun": "S", "sniper": "N", "rocket": "R", "grenade": "G", "riot": "B", "hostage": "H"}

var game = null
var view_team := 0
var orders := {}        # unit id -> order dict (viewing team)
var test_orders := {}   # hypothetical orders for other units (Test preview only)
var selected := -1
var tool := "path"      # path | aim | fire | ignore
var phase := "plan"     # plan | replay | idle

var ts := 32.0
var origin := Vector2.ZERO
var tiles := PackedByteArray()
var vis := PackedByteArray()
var _rmap = null
var _base_tiles := PackedByteArray()

var rframes: Array = []
var revents: Array = []
var rt := 0.0
var rspeed := 1.0
var rpaused := false
var rtest := false
var rview := 0
var rshow_all := false
var _rvis_frame := -1
var _rvis_ids: Dictionary = {}
var _hold := 0.0

func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	clip_contents = true
	resized.connect(queue_redraw)

# ------------------------------------------------------------------ public API

func set_game(g) -> void:
	game = g
	tiles = game.sim.map.t.duplicate()
	phase = "idle"
	queue_redraw()

func begin_plan(team: int) -> void:
	view_team = team
	orders = {}
	test_orders = {}
	selected = -1
	tool = "path"
	phase = "plan"
	tiles = game.sim.map.t.duplicate()
	_compute_vis()
	for u in game.sim.units:
		if u.alive and u.team == team:
			selected = u.id
			break
	selection_changed.emit()
	queue_redraw()

func start_replay(frames: Array, events: Array, map_before, team: int, is_test: bool, show_all: bool) -> void:
	rframes = frames
	revents = events
	_base_tiles = map_before.t.duplicate()
	_rmap = map_before.duplicate_map()
	rt = 0.0
	rpaused = false
	rtest = is_test
	rview = team
	rshow_all = show_all
	_rvis_frame = -1
	_hold = 0.0
	phase = "replay"
	queue_redraw()

func end_replay() -> void:
	if phase != "replay":
		return
	var was_test := rtest
	phase = "idle"
	tiles = game.sim.map.t.duplicate()
	replay_finished.emit(was_test)

func replay_length() -> float:
	return float(maxi(rframes.size() - 1, 1)) / 20.0

# ------------------------------------------------------------------ order editing

func _unit(id: int):
	return game.sim.unit(id)

func _orders_for(id: int) -> Dictionary:
	var u = _unit(id)
	var store: Dictionary = orders if u.team == view_team else test_orders
	if not store.has(id):
		store[id] = {"path": []}
	return store[id]

func _can_order(id: int) -> bool:
	var u = _unit(id)
	return u != null and u.alive and u.team < 2 and _is_visible_unit(u)

func _is_visible_unit(u) -> bool:
	if u.team == view_team or not game.dark:
		return true
	return game.sim.visible_to_team(view_team).has(u.id)

func add_waypoint(id: int, wx: int, wy: int) -> void:
	var u = _unit(id)
	var o := _orders_for(id)
	var sx: int = u.x
	var sy: int = u.y
	var duck: bool = o.get("duck", u.ducked)
	if not o["path"].is_empty():
		var last: Dictionary = o["path"][-1]
		sx = last["x"]
		sy = last["y"]
		duck = last["duck"]
	var p: Array = Nav.find_path(game.sim.map, sx, sy, wx, wy)
	if p.is_empty() or o["path"].size() + p.size() > 24:
		return
	for pt in p:
		o["path"].append({"x": pt["x"], "y": pt["y"], "wait": 0, "duck": duck, "aim_x": -1, "aim_y": -1})
	orders_changed.emit()
	queue_redraw()

func remove_last_waypoint() -> void:
	if selected < 0:
		return
	var o := _orders_for(selected)
	if not o["path"].is_empty():
		o["path"].pop_back()
	elif o.has("aim"):
		o.erase("aim")
	elif o.has("fire"):
		o.erase("fire")
	orders_changed.emit()
	queue_redraw()

func clear_orders() -> void:
	if selected < 0:
		return
	var u = _unit(selected)
	(orders if u.team == view_team else test_orders).erase(selected)
	orders_changed.emit()
	queue_redraw()

func set_aim(id: int, wx: int, wy: int) -> void:
	var o := _orders_for(id)
	if o["path"].is_empty():
		o["aim"] = {"x": wx, "y": wy}
	else:
		o["path"][-1]["aim_x"] = wx
		o["path"][-1]["aim_y"] = wy
	orders_changed.emit()
	queue_redraw()

func set_fire(id: int, wx: int, wy: int) -> void:
	var u = _unit(id)
	var wt: Dictionary = Balance.TYPES[u.type]
	if wt["kind"] != "rocket" and wt["kind"] != "grenade":
		return
	_orders_for(id)["fire"] = {"x": wx, "y": wy, "tick": 0}
	orders_changed.emit()
	queue_redraw()

func toggle_ignore(id: int, enemy_id: int) -> void:
	var o := _orders_for(id)
	var lst: Array = o.get("ignore", [])
	if lst.has(enemy_id):
		lst.erase(enemy_id)
	else:
		lst.append(enemy_id)
	o["ignore"] = lst
	orders_changed.emit()
	queue_redraw()

func toggle_duck() -> void:
	if selected < 0:
		return
	var u = _unit(selected)
	var o := _orders_for(selected)
	if o["path"].is_empty():
		o["duck"] = not o.get("duck", u.ducked)
	else:
		o["path"][-1]["duck"] = not o["path"][-1]["duck"]
	orders_changed.emit()
	queue_redraw()

func cycle_wait() -> void:
	if selected < 0:
		return
	var o := _orders_for(selected)
	if o["path"].is_empty():
		return
	o["path"][-1]["wait"] = (o["path"][-1]["wait"] + 1) % 6
	orders_changed.emit()
	queue_redraw()

func set_tool(t: String) -> void:
	tool = t
	queue_redraw()

func select_next() -> void:
	var mine: Array = []
	for u in game.sim.units:
		if u.alive and u.team == view_team:
			mine.append(u.id)
	if mine.is_empty():
		return
	var i: int = mine.find(selected)
	selected = mine[(i + 1) % mine.size()]
	selection_changed.emit()
	queue_redraw()

func unit_info() -> String:
	if selected < 0 or game == null:
		return ""
	var u = _unit(selected)
	if u == null:
		return ""
	var o: Dictionary = (orders if u.team == view_team else test_orders).get(selected, {})
	var wt: Dictionary = Balance.TYPES[u.type]
	var s := "%s #%d%s\n" % [wt["name"], u.id, " (hypothetical)" if u.team != view_team else ""]
	s += "Stance: %s\n" % ("ducked" if u.ducked else "standing")
	s += "Waypoints: %d\n" % o.get("path", []).size()
	if wt["kind"] == "rocket" or wt["kind"] == "grenade":
		s += "Fire order: %s\n" % ("set" if o.has("fire") else "none")
	s += "Ignoring: %d" % o.get("ignore", []).size()
	return s

# ------------------------------------------------------------------ geometry

func _layout() -> void:
	if game == null:
		return
	var m = game.sim.map
	ts = floorf(minf(size.x / m.w, size.y / m.h))
	ts = maxf(ts, 8.0)
	origin = Vector2((size.x - ts * m.w) * 0.5, (size.y - ts * m.h) * 0.5)

func _p(x: float, y: float) -> Vector2:
	return origin + Vector2(x, y) * ts / 1000.0

func _world(pos: Vector2) -> Vector2i:
	var v := (pos - origin) / ts * 1000.0
	return Vector2i(int(v.x), int(v.y))

func _compute_vis() -> void:
	var m = game.sim.map
	vis = PackedByteArray()
	vis.resize(m.w * m.h)
	if not game.dark:
		vis.fill(1)
		return
	for u in game.sim.units:
		if not u.alive or u.team != view_team:
			continue
		var r: int = Balance.TYPES[u.type]["vision"]
		var tx0: int = maxi(0, (u.x - r) / 1000)
		var tx1: int = mini(m.w - 1, (u.x + r) / 1000)
		var ty0: int = maxi(0, (u.y - r) / 1000)
		var ty1: int = mini(m.h - 1, (u.y + r) / 1000)
		for ty in range(ty0, ty1 + 1):
			for tx in range(tx0, tx1 + 1):
				if vis[ty * m.w + tx] == 1:
					continue
				var cx: int = tx * 1000 + 500
				var cy: int = ty * 1000 + 500
				if (cx - u.x) * (cx - u.x) + (cy - u.y) * (cy - u.y) <= r * r:
					if m.los(u.x, u.y, cx, cy, false) or (m.tile(tx, ty) == SimMap.WALL and m.los(u.x, u.y, cx - signi(cx - u.x) * 400, cy - signi(cy - u.y) * 400, false)):
						vis[ty * m.w + tx] = 1

# ------------------------------------------------------------------ input

func _unit_at(pos: Vector2, only_orderable: bool):
	var best = null
	var bd := ts * 0.7
	for u in game.sim.units:
		if not u.alive:
			continue
		if only_orderable and not _can_order(u.id):
			continue
		if not only_orderable and not _is_visible_unit(u):
			continue
		var d := _p(u.x, u.y).distance_to(pos)
		if d < bd:
			bd = d
			best = u
	return best

func _gui_input(event: InputEvent) -> void:
	if game == null or phase != "plan":
		return
	if event is InputEventMouseButton and event.pressed:
		grab_focus()
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if tool != "path":
				tool = "path"
				queue_redraw()
			else:
				remove_last_waypoint()
			return
		if event.button_index != MOUSE_BUTTON_LEFT:
			return
		var w := _world(event.position)
		var hit = _unit_at(event.position, false)
		match tool:
			"path":
				if hit != null and hit.alive and _can_order(hit.id) and (hit.team == view_team or Input.is_key_pressed(KEY_CTRL)):
					selected = hit.id
					selection_changed.emit()
				elif selected >= 0 and _can_order(selected):
					add_waypoint(selected, w.x, w.y)
				queue_redraw()
			"aim":
				if selected >= 0:
					set_aim(selected, w.x, w.y)
				tool = "path"
			"fire":
				if selected >= 0:
					set_fire(selected, w.x, w.y)
				tool = "path"
			"ignore":
				if selected >= 0 and hit != null and hit.team != _unit(selected).team:
					toggle_ignore(selected, hit.id)
				tool = "path"
		selection_changed.emit()
		queue_redraw()

# ------------------------------------------------------------------ replay timing

func _process(delta: float) -> void:
	if phase != "replay":
		return
	if not rpaused:
		rt += delta * rspeed
	if rt >= replay_length():
		rt = replay_length()
		if not rpaused:
			_hold += delta
			if _hold > (0.4 if rtest else 0.9):
				end_replay()
				return
	queue_redraw()

# ------------------------------------------------------------------ drawing

func _draw() -> void:
	if game == null:
		return
	_layout()
	draw_rect(Rect2(Vector2.ZERO, size), COL_BG)
	var m = game.sim.map
	var cur: PackedByteArray = tiles
	var f := 0
	var fa := 0.0
	if phase == "replay" and not rframes.is_empty():
		var ft := rt * 20.0
		f = clampi(int(ft), 0, rframes.size() - 1)
		fa = ft - float(f)
		cur = _tiles_at(f)
	for ty in range(m.h):
		for tx in range(m.w):
			var r := Rect2(origin + Vector2(tx, ty) * ts, Vector2(ts, ts))
			var k: int = cur[ty * m.w + tx]
			if k == SimMap.WALL:
				draw_rect(r, COL_WALL)
				draw_rect(r, COL_WALL_EDGE, false, 1.0)
			else:
				draw_rect(r, COL_FLOOR)
				draw_rect(r, COL_GRID, false, 1.0)
				if k == SimMap.LOW:
					draw_rect(r.grow(-ts * 0.18), COL_LOW)
					draw_rect(r.grow(-ts * 0.18), COL_WALL_EDGE, false, 1.0)
	_draw_objectives(f)
	if phase == "replay":
		_draw_replay(f, fa)
	else:
		_draw_plan(m)

func _draw_objectives(f: int) -> void:
	var md: Dictionary = game.sim.mode
	var yellow := Color(1.0, 0.82, 0.29, 0.9)
	match md.get("type", ""):
		"secure":
			var z: Array = md["zone"]
			draw_rect(Rect2(origin + Vector2(z[0], z[1]) * ts, Vector2(z[2] - z[0] + 1, z[3] - z[1] + 1) * ts), Color(1, 0.82, 0.29, 0.14))
			draw_rect(Rect2(origin + Vector2(z[0], z[1]) * ts, Vector2(z[2] - z[0] + 1, z[3] - z[1] + 1) * ts), yellow, false, 2.0)
		"disputed":
			for t in range(2):
				var e: Array = md["exits"][t]
				var c: Color = TEAM_COL[t]
				c.a = 0.12
				draw_rect(Rect2(origin + Vector2(e[0], e[1]) * ts, Vector2(e[2] - e[0] + 1, e[3] - e[1] + 1) * ts), c)
			var boxes: Array = []
			if phase == "replay" and f < rframes.size() and not rframes[f]["b"].is_empty():
				boxes = rframes[f]["b"]
			else:
				for b in md["boxes"]:
					boxes.append([b["x"], b["y"], b["delivered"]])
			for b in boxes:
				if b[2]:
					continue
				var p := _p(b[0], b[1])
				draw_rect(Rect2(p - Vector2(ts, ts) * 0.2, Vector2(ts, ts) * 0.4), yellow)
		"charge":
			var bx: int = md["bid"] if md["attacker"] == 0 else md["w"] - 1 - md["bid"]
			var x := origin.x + (bx + (0.5)) * ts
			draw_line(Vector2(x, origin.y), Vector2(x, origin.y + game.sim.map.h * ts), yellow, 2.0)

func _tiles_at(f: int) -> PackedByteArray:
	var t: PackedByteArray = _base_tiles.duplicate()
	var w: int = game.sim.map.w
	for e in revents:
		if e["type"] == "wall_destroyed" and e["tick"] <= f:
			t[e["ty"] * w + e["tx"]] = SimMap.FLOOR
	return t

func _draw_unit(pos: Vector2, team: int, type: String, facing: int, ducked: bool, sel: bool, alpha: float = 1.0, ghost: bool = false) -> void:
	var col: Color = TEAM_COL[team]
	col.a = alpha
	var r := ts * (0.26 if ducked else 0.33)
	if ghost:
		draw_arc(pos, r, 0, TAU, 20, col, 1.5)
	else:
		draw_circle(pos, r, col)
		var ang := float(facing) / 10.0 * PI / 180.0
		var dir := Vector2(cos(ang), sin(ang))
		draw_line(pos, pos + dir * ts * 0.55, Color(1, 1, 1, alpha), 2.0)
		var font := ThemeDB.fallback_font
		draw_string(font, pos + Vector2(-ts * 0.12, ts * 0.12), LETTER.get(type, "?"), HORIZONTAL_ALIGNMENT_LEFT, -1, int(ts * 0.38), Color(0.02, 0.05, 0.1, alpha))
	if ducked and not ghost:
		draw_arc(pos, r + 3, 0, TAU, 20, Color(1, 1, 1, 0.5), 1.0)
	if sel:
		draw_arc(pos, ts * 0.5, 0, TAU, 28, Color(1, 1, 1, 1), 2.0)

func _draw_orders(id: int, o: Dictionary, col: Color) -> void:
	var u = _unit(id)
	var prev := _p(u.x, u.y)
	for wp in o.get("path", []):
		var q := _p(wp["x"], wp["y"])
		draw_line(prev, q, col, 2.0)
		draw_circle(q, 3.5, col)
		if wp["wait"] > 0:
			draw_string(ThemeDB.fallback_font, q + Vector2(5, -5), "%ds" % wp["wait"], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)
		if wp["duck"] != u.ducked or wp["duck"]:
			draw_arc(q, 7, 0, TAU, 12, col, 1.0)
		if wp["aim_x"] >= 0:
			_dashed(q, _p(wp["aim_x"], wp["aim_y"]), col)
		prev = q
	if o.has("aim"):
		_dashed(_p(u.x, u.y), _p(o["aim"]["x"], o["aim"]["y"]), col)
	if o.has("fire"):
		var c := _p(o["fire"]["x"], o["fire"]["y"])
		var rad: float = Balance.EXPLOSIVES[Balance.TYPES[u.type]["kind"]]["radius"] / 1000.0 * ts
		draw_arc(c, rad, 0, TAU, 32, Color(1, 0.6, 0.2, 0.8), 1.5)
		draw_line(c - Vector2(8, 0), c + Vector2(8, 0), Color(1, 0.6, 0.2), 2.0)
		draw_line(c - Vector2(0, 8), c + Vector2(0, 8), Color(1, 0.6, 0.2), 2.0)
		_dashed(_p(u.x, u.y), c, Color(1, 0.6, 0.2, 0.6))
	for eid in o.get("ignore", []):
		var e = _unit(eid)
		if e != null:
			var q2 := _p(e.x, e.y)
			draw_line(q2 - Vector2(6, 6), q2 + Vector2(6, 6), Color(1, 1, 0.3), 2.0)
			draw_line(q2 - Vector2(6, -6), q2 + Vector2(6, -6), Color(1, 1, 0.3), 2.0)

func _dashed(a: Vector2, b: Vector2, col: Color) -> void:
	var d := a.distance_to(b)
	if d < 1.0:
		return
	var dir := (b - a) / d
	var s := 0.0
	var c := col
	c.a = 0.6
	while s < d:
		draw_line(a + dir * s, a + dir * minf(s + 5.0, d), c, 1.0)
		s += 10.0

func _draw_plan(m) -> void:
	# fog
	if game.dark:
		for ty in range(m.h):
			for tx in range(m.w):
				if vis[ty * m.w + tx] == 0:
					draw_rect(Rect2(origin + Vector2(tx, ty) * ts, Vector2(ts, ts)), Color(0, 0, 0, 0.55))
	var visible_ids: Array = game.visible_enemy_ids(view_team)
	for u in game.sim.units:
		if u.team == view_team:
			continue
		if not u.alive:
			continue
		if visible_ids.has(u.id):
			_draw_unit(_p(u.x, u.y), u.team, u.type, u.facing, u.ducked, u.id == selected)
		elif game.dark and game.last_seen[view_team].has(u.id):
			var ls: Array = game.last_seen[view_team][u.id]
			_draw_unit(_p(ls[0], ls[1]), u.team, u.type, 0, false, false, 0.5, true)
	for id in test_orders.keys():
		_draw_orders(id, test_orders[id], Color(1, 0.3, 0.4, 0.55))
	for u in game.sim.units:
		if u.alive and u.team == view_team:
			if orders.has(u.id):
				_draw_orders(u.id, orders[u.id], Color(0.3, 1.0, 0.6, 0.9))
			_draw_unit(_p(u.x, u.y), u.team, u.type, u.facing, u.ducked, u.id == selected)
	if tool != "path":
		draw_string(ThemeDB.fallback_font, Vector2(10, 22), "Tool: %s — click target (right-click cancels)" % tool, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 0.5))

func _frame_unit(frame: Dictionary, id: int) -> Array:
	for a in frame["u"]:
		if a[0] == id:
			return a
	return []

func _replay_visible(f: int) -> Dictionary:
	if f == _rvis_frame:
		return _rvis_ids
	_rvis_frame = f
	_rvis_ids = {}
	var fr: Dictionary = rframes[f]
	_rmap.t = _tiles_at(f)
	for a in fr["u"]:
		var ua = _unit(a[0])
		if ua.team != rview or not a[4]:
			continue
		var vr: int = Balance.TYPES[ua.type]["vision"]
		for b in fr["u"]:
			var ub = _unit(b[0])
			if ub.team == rview or not b[4] or _rvis_ids.has(b[0]):
				continue
			var dx: int = b[1] - a[1]
			var dy: int = b[2] - a[2]
			if dx * dx + dy * dy <= vr * vr and _rmap.los(a[1], a[2], b[1], b[2], bool(a[5]) or bool(b[5])):
				_rvis_ids[b[0]] = true
	return _rvis_ids

func _draw_replay(f: int, fa: float) -> void:
	var fr: Dictionary = rframes[f]
	var nxt: Dictionary = rframes[mini(f + 1, rframes.size() - 1)]
	var seen: Dictionary = {}
	if game.dark and not rshow_all:
		seen = _replay_visible(f)
	for a in fr["u"]:
		var u = _unit(a[0])
		var b: Array = _frame_unit(nxt, a[0])
		if u.team != rview and u.team < 2 and game.dark and not rshow_all and not seen.has(a[0]):
			continue
		if u.team == 2 and game.dark and not rshow_all and not seen.has(a[0]):
			continue
		if not a[4]:
			var q := _p(a[1], a[2])
			draw_line(q - Vector2(5, 5), q + Vector2(5, 5), Color(TEAM_COL[u.team], 0.5), 2.0)
			draw_line(q - Vector2(5, -5), q + Vector2(5, -5), Color(TEAM_COL[u.team], 0.5), 2.0)
			continue
		var pos := _p(lerpf(a[1], b[1], fa), lerpf(a[2], b[2], fa))
		_draw_unit(pos, u.team, u.type, a[3], bool(a[5]), false)
	for pr in fr["p"]:
		var pp := _p(pr[1], pr[2])
		draw_circle(pp, 4 if pr[0] == "rocket" else 5, Color(1, 0.7, 0.2))
	for e in revents:
		var age: int = f - e["tick"]
		if age < 0:
			continue
		match e["type"]:
			"shot":
				if age <= 2:
					var s: Array = _frame_unit(rframes[e["tick"]], e["shooter"])
					var t: Array = _frame_unit(rframes[e["tick"]], e["target"])
					if not s.is_empty() and not t.is_empty() and (not game.dark or rshow_all or seen.has(e["shooter"]) or _unit(e["shooter"]).team == rview):
						draw_line(_p(s[1], s[2]), _p(t[1], t[2]), Color(1, 0.3, 0.3, 0.9) if e["hit"] else Color(0.8, 0.8, 0.8, 0.4), 1.5)
			"explosion":
				if age <= 12:
					var k := float(age) / 12.0
					draw_circle(_p(e["x"], e["y"]), e["radius"] / 1000.0 * ts * k, Color(1, 0.6, 0.2, 0.45 * (1.0 - k)))
					draw_arc(_p(e["x"], e["y"]), e["radius"] / 1000.0 * ts * k, 0, TAU, 32, Color(1, 0.8, 0.3, 1.0 - k), 2.0)
	var label := "TEST PREVIEW" if rtest else "REPLAY"
	draw_string(ThemeDB.fallback_font, Vector2(10, 22), "%s  %.1fs / %.1fs%s" % [label, rt, replay_length(), "  [paused]" if rpaused else ""], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 0.5))
