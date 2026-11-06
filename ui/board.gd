extends Control
## The tactical board: draws the map, units and orders, edits orders with the mouse,
## and plays back 5-second replays (real turns and Test previews).

const Fx = preload("res://sim/fx.gd")
const Nav = preload("res://sim/nav.gd")
const Balance = preload("res://sim/balance.gd")
const SimMap = preload("res://sim/grid_map.gd")
const Modes = preload("res://sim/modes.gd")
const View = preload("res://ui/board_view.gd")
const FxLayer = preload("res://ui/board_fx.gd")

signal orders_changed
signal selection_changed
signal replay_finished(was_test: bool)
signal context_requested(screen_pos: Vector2, world: Vector2i, unit_id: int)

const COL_BG := Color("070b16")
const COL_FLOOR := Color("0d1630")
const COL_GRID := Color("14234a")
const COL_WALL := Color("2d8cff")
const COL_WALL_EDGE := Color("8fd0ff")
const COL_LOW := Color("2a5fa8")
const TEAM_COL := [Color("39ff88"), Color("ff4d5e"), Color("ffd24a")]
const LETTER := {"mg": "M", "shotgun": "S", "sniper": "N", "rocket": "R", "grenade": "G", "riot": "B", "hostage": "H", "hacker": "K", "commando": "C", "devastator": "D", "civilian": "V"}

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
var fog_tex: ImageTexture = null
var light_tex: ImageTexture = null    # soft light pools (line of sight of the viewing team)
var _light_frame := -99
var flash_t := 0.0                     # "NEXT TURN" flash timer
var _rmap = null
var _base_tiles := PackedByteArray()

var rframes: Array = []
var death_ticks := {}   # unit id -> tick of death during the replayed turn
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

var fx_layer = null

func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	clip_contents = true
	resized.connect(queue_redraw)
	fx_layer = FxLayer.new()
	fx_layer.board = self
	add_child(fx_layer)

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
	var pts: Array = []
	for u in game.sim.units:
		if u.alive and u.team == team:
			pts.append([u.x, u.y, u.ducked])
	light_tex = build_light(game.sim.map, pts, 2)
	if game.turn > 0:
		flash_t = 1.5
	for u in game.sim.units:
		if u.alive and u.team == team and game.can_order(team, u):
			selected = u.id
			break
	selection_changed.emit()
	queue_redraw()

func start_replay(frames: Array, events: Array, map_before, team: int, is_test: bool, show_all: bool) -> void:
	rframes = frames
	revents = events
	death_ticks = {}
	for e in events:
		if e["type"] == "kill":
			death_ticks[e["victim"]] = e["tick"]
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

## Soft light pools: which parts of the floor the given units can see (line of sight, no field of view limit).
func build_light(m, pts: Array, res: int) -> ImageTexture:
	var img := Image.create(m.w * res, m.h * res, false, Image.FORMAT_RGBA8)
	for sy in range(m.h * res):
		for sx in range(m.w * res):
			var wx: int = int((float(sx) + 0.5) / float(res) * 1000.0)
			var wy: int = int((float(sy) + 0.5) / float(res) * 1000.0)
			var best := 0.0
			if m.at_pos(wx, wy) != SimMap.WALL:
				for p in pts:
					var dx: int = wx - p[0]
					var dy: int = wy - p[1]
					var d2: int = dx * dx + dy * dy
					if d2 > 18000 * 18000:
						continue
					if m.los(p[0], p[1], wx, wy, bool(p[2])):
						var f: float = 1.0 - sqrt(float(d2)) / 18000.0
						best = maxf(best, f * f * 0.7 + 0.3 * f)
			img.set_pixel(sx, sy, Color(0.22, 0.5, 1.0, best))
	return ImageTexture.create_from_image(img)

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
	if u == null or not u.alive or not _is_visible_unit(u):
		return false
	return game.can_order(view_team, u) or (u.team < 2 and u.team != view_team)

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

func toggle_cos() -> void:
	if selected < 0:
		return
	var o := _orders_for(selected)
	o["cos"] = not o.get("cos", false)
	orders_changed.emit()
	queue_redraw()

func cancel_aim() -> void:
	if selected < 0:
		return
	var o := _orders_for(selected)
	if o["path"].is_empty():
		o.erase("aim")
	else:
		o["path"][-1]["aim_x"] = -1
		o["path"][-1]["aim_y"] = -1
	orders_changed.emit()
	queue_redraw()

func set_stance(duck: bool) -> void:
	if selected < 0:
		return
	var o := _orders_for(selected)
	if o["path"].is_empty():
		o["duck"] = duck
	else:
		o["path"][-1]["duck"] = duck
	orders_changed.emit()
	queue_redraw()

func set_check(id: int, wx: int, wy: int) -> void:
	var o := _orders_for(id)
	if o["path"].is_empty():
		var u = _unit(id)
		o["path"].append({"x": u.x, "y": u.y, "wait": 0, "duck": o.get("duck", u.ducked), "aim_x": -1, "aim_y": -1})
	o["path"][-1]["check_x"] = wx
	o["path"][-1]["check_y"] = wy
	orders_changed.emit()
	queue_redraw()

func engage_on_sight() -> void:
	if selected < 0:
		return
	_orders_for(selected)["cos"] = false
	orders_changed.emit()
	queue_redraw()

func toggle_focus(id: int, enemy_id: int) -> void:
	var o := _orders_for(id)
	var lst: Array = o.get("focus", [])
	if lst.has(enemy_id):
		lst.erase(enemy_id)
	else:
		lst.append(enemy_id)
	o["focus"] = lst
	orders_changed.emit()
	queue_redraw()

func clear_focus_ignore() -> void:
	if selected < 0:
		return
	var o := _orders_for(selected)
	o["focus"] = []
	o["ignore"] = []
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

func select_prev() -> void:
	var mine: Array = []
	for u in game.sim.units:
		if u.alive and u.team == view_team and game.can_order(view_team, u):
			mine.append(u.id)
	if mine.is_empty():
		return
	var i: int = mine.find(selected)
	selected = mine[(i - 1 + mine.size()) % mine.size()]
	selection_changed.emit()
	queue_redraw()

func selected_weapon_name() -> String:
	if selected < 0 or game == null or _unit(selected) == null:
		return "NO UNIT"
	return String(Balance.TYPES[_unit(selected).type]["name"]).to_upper()

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
	s += "Ignoring: %d%s" % [o.get("ignore", []).size(), "  [continue on sight]" if o.get("cos", false) else ""]
	return s

# ------------------------------------------------------------------ geometry

func _layout() -> void:
	if game == null:
		return
	var m = game.sim.map
	ts = floorf(minf(size.x / (m.w + 1.4), size.y / (m.h + 1.4)))
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
		fog_tex = null
		return
	for u in game.sim.units:
		if not u.alive or u.team != view_team:
			continue
		var r: int = Balance.SIGHT_RANGE
		var fov: int = Balance.TYPES[u.type]["fov"]
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
				if (cx - u.x) * (cx - u.x) + (cy - u.y) * (cy - u.y) <= r * r and Fx.angle_diff(u.facing, Fx.atan2_dd(cy - u.y, cx - u.x)) <= fov:
					if m.los(u.x, u.y, cx, cy, false) or (m.tile(tx, ty) == SimMap.WALL and m.los(u.x, u.y, cx - signi(cx - u.x) * 400, cy - signi(cy - u.y) * 400, false)):
						vis[ty * m.w + tx] = 1
	var img := Image.create(m.w, m.h, false, Image.FORMAT_RGBA8)
	for ty in range(m.h):
		for tx in range(m.w):
			img.set_pixel(tx, ty, Color(0.0, 0.01, 0.06, 0.0 if vis[ty * m.w + tx] == 1 else 0.66))
	fog_tex = ImageTexture.create_from_image(img)

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
	if game == null or (phase != "plan" and phase != "replay"):
		return
	if event is InputEventMouseButton and event.pressed:
		grab_focus()
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if tool != "path" and phase == "plan":
				tool = "path"
				queue_redraw()
			else:
				var hit_u = _unit_at(event.position, false) if phase == "plan" else null
				context_requested.emit(get_global_mouse_position(), _world(event.position), hit_u.id if hit_u != null else -1)
			return
		if phase != "plan":
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
			"focus":
				if selected >= 0 and hit != null and hit.team != _unit(selected).team:
					toggle_focus(selected, hit.id)
				tool = "path"
			"check":
				if selected >= 0:
					set_check(selected, w.x, w.y)
				tool = "path"
		selection_changed.emit()
		queue_redraw()

# ------------------------------------------------------------------ replay timing

func _process(delta: float) -> void:
	if flash_t > 0.0:
		flash_t = maxf(0.0, flash_t - delta)
		queue_redraw()
	if phase != "replay":
		return
	var lf: int = int(rt * 20.0 / 10.0)
	if lf != _light_frame and not rframes.is_empty():
		_light_frame = lf
		var fi: int = clampi(int(rt * 20.0), 0, rframes.size() - 1)
		var lp: Array = []
		for a in rframes[fi]["u"]:
			var lu = _unit(a[0])
			if a[4] and (lu.team == rview or rshow_all or not game.dark):
				if lu.team == rview or rshow_all:
					lp.append([a[1], a[2], bool(a[5])])
		_rmap.t = _tiles_at(fi)
		light_tex = build_light(_rmap, lp, 1)
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
	View.draw_solid(self, self)
	if fx_layer != null:
		fx_layer.queue_redraw()

func _mission_uses_exits(md: Dictionary) -> bool:
	for o in md["objectives"]:
		if o["type"] == "rescue" or o["type"] == "collect" or o.get("zone", "") == "exit_any" or o.get("zone", "").begins_with("exit"):
			return true
	return false

func _tiles_at(f: int) -> PackedByteArray:
	var t: PackedByteArray = _base_tiles.duplicate()
	var w: int = game.sim.map.w
	for e in revents:
		if e["type"] == "wall_destroyed" and e["tick"] <= f:
			t[e["ty"] * w + e["tx"]] = SimMap.FLOOR
	return t

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
		var vr: int = Balance.SIGHT_RANGE
		var fovr: int = Balance.TYPES[ua.type]["fov"]
		for b in fr["u"]:
			var ub = _unit(b[0])
			if ub.team == rview or not b[4] or _rvis_ids.has(b[0]):
				continue
			var dx: int = b[1] - a[1]
			var dy: int = b[2] - a[2]
			if dx * dx + dy * dy <= vr * vr and Fx.angle_diff(a[3], Fx.atan2_dd(dy, dx)) <= fovr and _rmap.los(a[1], a[2], b[1], b[2], bool(a[5]) or bool(b[5])):
				_rvis_ids[b[0]] = true
	return _rvis_ids
