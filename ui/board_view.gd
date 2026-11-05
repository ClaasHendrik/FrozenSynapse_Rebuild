extends RefCounted
## Renderer for the tactical board: pseudo-3D neon look (extruded glowing walls, cube half-walls,
## figure silhouettes, tracers and bloom). Two layers: draw_solid() on the board itself and
## draw_glow() on an additive-blend child layer. Everything is drawn procedurally - no image assets.

const Fx = preload("res://sim/fx.gd")
const Balance = preload("res://sim/balance.gd")
const SimMap = preload("res://sim/grid_map.gd")

const LEAN := 0.075            # how strongly walls lean away from the screen centre (perspective)
const H_WALL := 1.0
const H_LOW := 0.42

const TEAM_COL := [Color("3dff8f"), Color("ff3d4d"), Color("ffd23a")]
const ORDER_COL := Color(0.22, 1.0, 0.4, 1.0)
const TEST_COL := Color(1.0, 0.4, 0.5, 0.6)
const WALL_TOP := Color("1c58e0")
const WALL_TOP_EDGE := Color("a6dcff")
const WALL_SIDE_LIGHT := Color("1b50d0")
const WALL_SIDE_DARK := Color("041552")
const LOW_TOP := Color("3f88ff")
const YELLOW := Color(1.0, 0.82, 0.29)

static var _tex_bg: GradientTexture2D = null
static var _tex_soft: GradientTexture2D = null

static func _textures() -> void:
	if _tex_bg != null:
		return
	var g := Gradient.new()
	g.colors = PackedColorArray([Color("0e2f9a"), Color("051550"), Color("010413")])
	g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	_tex_bg = GradientTexture2D.new()
	_tex_bg.gradient = g
	_tex_bg.fill = GradientTexture2D.FILL_RADIAL
	_tex_bg.fill_from = Vector2(0.5, 0.5)
	_tex_bg.fill_to = Vector2(1.0, 0.5)
	_tex_bg.width = 256
	_tex_bg.height = 256
	var g2 := Gradient.new()
	g2.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0)])
	g2.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	_tex_soft = GradientTexture2D.new()
	_tex_soft.gradient = g2
	_tex_soft.fill = GradientTexture2D.FILL_RADIAL
	_tex_soft.fill_from = Vector2(0.5, 0.5)
	_tex_soft.fill_to = Vector2(1.0, 0.5)
	_tex_soft.width = 128
	_tex_soft.height = 128

static func lean(b, p: Vector2, h: float) -> Vector2:
	var c: Vector2 = b.size * 0.5
	return p + (p - c) * LEAN * h

static func _state(b) -> Dictionary:
	var f := 0
	var fa := 0.0
	var cur: PackedByteArray = b.tiles
	if b.phase == "replay" and not b.rframes.is_empty():
		var ft: float = b.rt * 20.0
		f = clampi(int(ft), 0, b.rframes.size() - 1)
		fa = ft - float(f)
		cur = b._tiles_at(f)
	return {"f": f, "fa": fa, "cur": cur}

static func _glow_blob(c, center: Vector2, radius: float, col: Color) -> void:
	c.draw_texture_rect(_tex_soft, Rect2(center - Vector2(radius, radius), Vector2(radius, radius) * 2.0), false, col)

static func _dash(c, a: Vector2, b: Vector2, col: Color, width: float, dash: float = 5.0, gap: float = 6.0, off: float = 0.0) -> void:
	var d: float = a.distance_to(b)
	if d < 1.0:
		return
	var dir: Vector2 = (b - a) / d
	var s: float = -fposmod(off, dash + gap)
	while s < d:
		var s0: float = maxf(s, 0.0)
		var s1: float = minf(s + dash, d)
		if s1 > s0:
			c.draw_line(a + dir * s0, a + dir * s1, col, width)
		s += dash + gap

static func _ellipse(center: Vector2, rx: float, ry: float, n: int = 16) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(n):
		var a: float = TAU * float(i) / float(n)
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	return pts

# ------------------------------------------------------------------ solid layer

static func draw_solid(b, c) -> void:
	_textures()
	b._layout()
	var game = b.game
	var m = game.sim.map
	var st: Dictionary = _state(b)
	var cur: PackedByteArray = st["cur"]
	var f: int = st["f"]
	c.draw_rect(Rect2(Vector2.ZERO, b.size), Color("010412"))
	var map_rect := Rect2(b.origin, Vector2(m.w, m.h) * b.ts)
	c.draw_texture_rect(_tex_bg, map_rect.grow(b.ts * 6.0), false)
	var gcol := Color(0.25, 0.5, 1.0, 0.07)
	for x in range(m.w + 1):
		c.draw_line(b.origin + Vector2(x * b.ts, 0), b.origin + Vector2(x * b.ts, m.h * b.ts), gcol, 1.0)
	for y in range(m.h + 1):
		c.draw_line(b.origin + Vector2(0, y * b.ts), b.origin + Vector2(m.w * b.ts, y * b.ts), gcol, 1.0)
	_objectives(b, c, f)
	_walls(b, c, cur)
	if b.phase == "replay":
		_replay_units(b, c, st)
	else:
		_plan_layer(b, c, m)
	if b.phase == "replay":
		var label := "TEST PREVIEW" if b.rtest else "REPLAY"
		_text(c, Vector2(b.size.x * 0.5 - 150.0, 26), "%s   %.1fs / %.1fs%s" % [label, b.rt, b.replay_length(), "   [paused]" if b.rpaused else ""], Color(0.75, 0.9, 1.0), 16)
	elif b.tool != "path":
		_text(c, Vector2(b.size.x * 0.5 - 200.0, 26), "%s: click a target  (right-click or Esc cancels)" % b.tool.to_upper(), Color(1, 0.95, 0.5), 16)

static func _text(c, pos: Vector2, s: String, col: Color, size: int) -> void:
	var font := ThemeDB.fallback_font
	c.draw_string(font, pos + Vector2(1, 1), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, 0.8))
	c.draw_string(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

static func _tile_kind(cur: PackedByteArray, m, tx: int, ty: int) -> int:
	if tx < 0 or ty < 0 or tx >= m.w or ty >= m.h:
		return SimMap.WALL
	return cur[ty * m.w + tx]

static func _sorted_blocks(b, cur: PackedByteArray, m) -> Array:
	var list: Array = []
	var ctr: Vector2 = b.size * 0.5
	for ty in range(m.h):
		for tx in range(m.w):
			var k: int = cur[ty * m.w + tx]
			if k == SimMap.FLOOR:
				continue
			var cen: Vector2 = b.origin + Vector2(tx + 0.5, ty + 0.5) * b.ts
			list.append([cen.distance_squared_to(ctr), tx, ty, k])
	list.sort_custom(func(p, q): return p[0] > q[0])
	return list

# edge i connects corner i to corner (i+1)%4; neighbour offsets for edges 0..3
const EDGE_NB := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]

static func _corners(b, tx: int, ty: int, inset: float) -> PackedVector2Array:
	var x0: float = b.origin.x + (tx + inset) * b.ts
	var y0: float = b.origin.y + (ty + inset) * b.ts
	var s: float = b.ts * (1.0 - 2.0 * inset)
	return PackedVector2Array([Vector2(x0, y0), Vector2(x0 + s, y0), Vector2(x0 + s, y0 + s), Vector2(x0, y0 + s)])

static func _walls(b, c, cur: PackedByteArray) -> void:
	var m = b.game.sim.map
	var ctr: Vector2 = b.size * 0.5
	for e in _sorted_blocks(b, cur, m):
		var tx: int = e[1]
		var ty: int = e[2]
		var kind: int = e[3]
		var is_wall: bool = kind == SimMap.WALL
		var inset := 0.0 if is_wall else 0.17
		var h: float = H_WALL if is_wall else H_LOW
		var base: PackedVector2Array = _corners(b, tx, ty, inset)
		var top := PackedVector2Array()
		for v in base:
			top.append(lean(b, v, h))
		var cen: Vector2 = b.origin + Vector2(tx + 0.5, ty + 0.5) * b.ts
		for i in range(4):
			var nb: Vector2i = EDGE_NB[i]
			if is_wall and _tile_kind(cur, m, tx + nb.x, ty + nb.y) == SimMap.WALL:
				continue
			var normal := Vector2(nb.x, nb.y)
			if normal.dot(ctr - cen) <= 0.0:
				continue       # faces away from the centre: hidden behind the top face
			var j: int = (i + 1) % 4
			var lo: Color = WALL_SIDE_DARK if is_wall else Color("0a2a86")
			var hi: Color = WALL_SIDE_LIGHT if is_wall else Color("2a68f0")
			c.draw_polygon(PackedVector2Array([base[i], base[j], top[j], top[i]]), PackedColorArray([lo, lo, hi, hi]))
		var fall: float = clampf(cen.distance_to(ctr) / (b.size.length() * 0.5), 0.0, 1.0)
		var tcol: Color = (WALL_TOP if is_wall else LOW_TOP).darkened(0.45 * fall)
		c.draw_colored_polygon(top, tcol)
		var edge_col: Color = WALL_TOP_EDGE if is_wall else Color("d8f0ff")
		for i in range(4):
			var nb2: Vector2i = EDGE_NB[i]
			if is_wall and _tile_kind(cur, m, tx + nb2.x, ty + nb2.y) == SimMap.WALL:
				continue
			c.draw_line(top[i], top[(i + 1) % 4], edge_col, 1.8)

# ------------------------------------------------------------------ objectives (flat on the floor)

static func _rect_px(b, r: Array) -> Rect2:
	return Rect2(b.origin + Vector2(r[0], r[1]) * b.ts, Vector2(r[2] - r[0] + 1, r[3] - r[1] + 1) * b.ts)

static func _zone(b, c, r: Array, col: Color) -> void:
	var rc: Rect2 = _rect_px(b, r)
	var fill := col
	fill.a = 0.13
	c.draw_rect(rc, fill)
	c.draw_rect(rc, col, false, 2.0)

static func _box(b, c, x: float, y: float) -> void:
	var p: Vector2 = b._p(x, y)
	var s: float = b.ts * 0.4
	c.draw_rect(Rect2(p - Vector2(s, s) * 0.5, Vector2(s, s)), YELLOW)
	c.draw_rect(Rect2(p - Vector2(s, s) * 0.5, Vector2(s, s)), Color(1, 1, 0.8), false, 1.5)

static func _objectives(b, c, f: int) -> void:
	var md: Dictionary = b.game.sim.mode
	var green := Color(0.3, 1.0, 0.5)
	match md.get("type", ""):
		"mission":
			var shown := {}
			for o in md["objectives"]:
				for r in o["rects"]:
					if not shown.has(str(r)):
						shown[str(r)] = true
						_zone(b, c, r, YELLOW)
			if md.has("boxes") or b._mission_uses_exits(md):
				for t in range(2):
					var ex: Array = md["exits"][t]
					var gc := green
					gc.a = 0.5
					_zone(b, c, ex, gc)
			var boxes: Array = []
			if b.phase == "replay" and f < b.rframes.size() and not b.rframes[f]["b"].is_empty():
				boxes = b.rframes[f]["b"]
			elif md.has("boxes"):
				for bx in md["boxes"]:
					boxes.append([bx["x"], bx["y"], bx["delivered"] or bx["lost"]])
			for bx in boxes:
				if not bx[2]:
					_box(b, c, bx[0], bx[1])
			for pn in md["panels"]:
				var pc := Color(0.4, 0.9, 1.0, 0.35 if pn["done"] else 0.95)
				c.draw_rect(Rect2(b.origin + Vector2(pn["tx"], pn["ty"]) * b.ts + Vector2(b.ts, b.ts) * 0.2, Vector2(b.ts, b.ts) * 0.6), pc, false, 2.0)
		"secure":
			_zone(b, c, md["zone"], YELLOW)
		"disputed":
			for t in range(2):
				var gc2 := green
				gc2.a = 0.55 if md["active"] else 0.15
				_zone(b, c, md["exits"][t], gc2)
			var dboxes: Array = []
			if b.phase == "replay" and f < b.rframes.size() and not b.rframes[f]["b"].is_empty():
				dboxes = b.rframes[f]["b"]
			else:
				for bx2 in md["boxes"]:
					dboxes.append([bx2["x"], bx2["y"], bx2["delivered"] or not md["active"]])
			for bx3 in dboxes:
				if not bx3[2]:
					_box(b, c, bx3[0], bx3[1])
		"hostage":
			_zone(b, c, md["square"], YELLOW)
			for t in range(2):
				var gc3 := green
				gc3.a = 0.4
				_zone(b, c, md["exits"][t], gc3)
		"charge":
			var bxl: int = md["bid"] if md["attacker"] == 0 else md["w"] - 1 - md["bid"]
			var x: float = b.origin.x + (bxl + 0.5) * b.ts
			c.draw_line(Vector2(x, b.origin.y), Vector2(x, b.origin.y + b.game.sim.map.h * b.ts), YELLOW, 2.5)

# ------------------------------------------------------------------ figures

static func _capsule(c, a: Vector2, b: Vector2, w: float, col: Color) -> void:
	c.draw_line(a, b, col, w)
	c.draw_circle(a, w * 0.5, col)
	c.draw_circle(b, w * 0.5, col)

## Humanoid, seen from above, facing +x (after the transform). k = size scale.
static func _figure(c, pos: Vector2, ang: float, r: float, col: Color, type: String, ducked: bool, alpha: float, ghost: bool, moving: bool = false, phase: float = 0.0) -> void:
	c.draw_set_transform(pos, ang, Vector2.ONE)
	var k: float = r
	if type == "devastator":
		k *= 1.3
	var bright := col
	bright.a = alpha
	var mid := col.darkened(0.1)
	mid.a = alpha
	var dark := col.darkened(0.72)
	dark.a = alpha
	var lite := col.lightened(0.55)
	lite.a = alpha
	var sq: float = 0.8 if ducked else 1.0
	if ghost:
		var ring := _ellipse(Vector2.ZERO, 0.6 * k, 1.0 * k, 16)
		ring.append(ring[0])
		c.draw_polyline(ring, bright, 1.5)
		c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	# soft shadow
	c.draw_colored_polygon(_ellipse(Vector2(-0.05 * k, 0.12 * k), 0.85 * k, 1.1 * k, 16), Color(0, 0, 0, 0.38 * alpha))
	# legs trail behind the torso, striding while moving, short and wide when ducked
	var swing: float = sin(phase * 9.0) * 0.5 * k if moving else 0.0
	var spread_y: float = 0.36 * k * (1.35 if ducked else 1.0)
	var reach: float = 1.55 * k * (0.62 if ducked else 1.0)
	for side in [-1.0, 1.0]:
		var hip := Vector2(-0.3 * k, side * 0.28 * k)
		var knee := Vector2(-0.3 * k - reach * 0.5 + swing * side, side * spread_y * 1.15)
		var foot := Vector2(-0.3 * k - reach + swing * side * 1.4, side * spread_y)
		_capsule(c, hip, knee, 0.56 * k, dark)
		_capsule(c, knee, foot, 0.48 * k, dark)
		c.draw_line(hip, knee, mid, 0.34 * k)
		c.draw_line(knee, foot, mid, 0.28 * k)
		c.draw_circle(foot, 0.22 * k, lite)
	# torso: angular low-poly shoulders, back plate, chest highlight, bright rim
	var T := PackedVector2Array([
		Vector2(0.32 * k * sq, -0.55 * k), Vector2(0.1 * k, -0.82 * k), Vector2(-0.25 * k, -0.74 * k), Vector2(-0.5 * k * sq, -0.4 * k),
		Vector2(-0.5 * k * sq, 0.4 * k), Vector2(-0.25 * k, 0.74 * k), Vector2(0.1 * k, 0.82 * k), Vector2(0.32 * k * sq, 0.55 * k)])
	c.draw_colored_polygon(T, mid)
	c.draw_colored_polygon(PackedVector2Array([Vector2(-0.5 * k * sq, -0.4 * k), Vector2(-0.25 * k, -0.74 * k), Vector2(-0.15 * k, -0.4 * k), Vector2(-0.15 * k, 0.4 * k), Vector2(-0.25 * k, 0.74 * k), Vector2(-0.5 * k * sq, 0.4 * k)]), dark)
	c.draw_colored_polygon(PackedVector2Array([Vector2(0.26 * k * sq, -0.42 * k), Vector2(0.06 * k, -0.64 * k), Vector2(0.06 * k, 0.64 * k), Vector2(0.26 * k * sq, 0.42 * k)]), Color(lite.r, lite.g, lite.b, 0.45 * alpha))
	var outline := T.duplicate()
	outline.append(T[0])
	c.draw_polyline(outline, lite, 1.4)
	# arms to the grip, then the weapon
	var hand_a := Vector2(1.0 * k, 0.3 * k)
	var hand_b := Vector2(0.6 * k, 0.1 * k)
	var civilian: bool = type == "hostage" or type == "civilian"
	if civilian:
		hand_a = Vector2(0.9 * k, 0.75 * k)
		hand_b = Vector2(0.9 * k, -0.75 * k)
	if type == "rocket" or type == "devastator":
		hand_a = Vector2(0.5 * k, 0.6 * k)
		hand_b = Vector2(0.1 * k, 0.55 * k)
	var sh_a := Vector2(0.0, 0.78 * k)
	var sh_b := Vector2(0.0, -0.78 * k)
	var el_a := Vector2(0.42 * k, 1.0 * k) if not civilian else Vector2(0.5 * k, 0.95 * k)
	var el_b := Vector2(0.4 * k, -0.85 * k) if not civilian else Vector2(0.5 * k, -0.95 * k)
	if type == "rocket" or type == "devastator":
		el_a = Vector2(0.3 * k, 0.95 * k)
		el_b = Vector2(0.05 * k, 0.8 * k)
	for pair in [[sh_a, el_a, hand_a], [sh_b, el_b, hand_b]]:
		_capsule(c, pair[0], pair[1], 0.48 * k, dark)
		_capsule(c, pair[1], pair[2], 0.42 * k, dark)
		c.draw_line(pair[0], pair[1], mid, 0.3 * k)
		c.draw_line(pair[1], pair[2], mid, 0.25 * k)
		c.draw_circle(pair[2], 0.19 * k, lite)
	match type:
		"mg":
			c.draw_line(Vector2(0.35 * k, 0.32 * k), Vector2(1.95 * k, 0.32 * k), bright, maxf(0.22 * k, 2.0))
			c.draw_rect(Rect2(Vector2(0.55 * k, 0.32 * k), Vector2(0.38 * k, 0.4 * k)), bright)
			c.draw_rect(Rect2(Vector2(0.2 * k, 0.2 * k), Vector2(0.4 * k, 0.26 * k)), mid)
		"shotgun":
			c.draw_line(Vector2(0.35 * k, 0.32 * k), Vector2(1.55 * k, 0.32 * k), bright, maxf(0.34 * k, 3.0))
			c.draw_line(Vector2(0.9 * k, 0.32 * k), Vector2(1.3 * k, 0.32 * k), lite, maxf(0.14 * k, 1.5))
		"commando":
			c.draw_line(Vector2(0.35 * k, 0.15 * k), Vector2(1.6 * k, 0.15 * k), bright, maxf(0.22 * k, 2.2))
			c.draw_line(Vector2(0.35 * k, 0.5 * k), Vector2(1.6 * k, 0.5 * k), bright, maxf(0.22 * k, 2.2))
		"sniper":
			c.draw_line(Vector2(0.1 * k, 0.32 * k), Vector2(2.7 * k, 0.32 * k), bright, maxf(0.14 * k, 1.6))
			c.draw_rect(Rect2(Vector2(0.9 * k, 0.05 * k), Vector2(0.55 * k, 0.2 * k)), lite)
			c.draw_line(Vector2(0.4 * k, 0.32 * k), Vector2(0.4 * k, 0.8 * k), bright, maxf(0.1 * k, 1.4))
		"rocket":
			c.draw_line(Vector2(-0.7 * k, 0.6 * k), Vector2(1.35 * k, 0.6 * k), bright, maxf(0.52 * k, 4.0))
			c.draw_line(Vector2(-0.7 * k, 0.6 * k), Vector2(-0.4 * k, 0.6 * k), lite, maxf(0.52 * k, 4.0))
			c.draw_colored_polygon(PackedVector2Array([Vector2(1.35 * k, 0.28 * k), Vector2(1.9 * k, 0.6 * k), Vector2(1.35 * k, 0.92 * k)]), bright)
		"devastator":
			c.draw_line(Vector2(-0.5 * k, 0.75 * k), Vector2(1.5 * k, 0.75 * k), bright, maxf(0.36 * k, 3.5))
			c.draw_line(Vector2(-0.5 * k, -0.75 * k), Vector2(1.5 * k, -0.75 * k), bright, maxf(0.36 * k, 3.5))
		"grenade":
			c.draw_line(Vector2(0.3 * k, 0.32 * k), Vector2(1.2 * k, 0.32 * k), bright, maxf(0.5 * k, 4.0))
			c.draw_circle(Vector2(1.45 * k, 0.32 * k), 0.32 * k, lite)
		"riot":
			var arc := PackedVector2Array()
			for i in range(15):
				var a: float = deg_to_rad(-75.0 + 150.0 * float(i) / 14.0)
				arc.append(Vector2(cos(a), sin(a)) * 1.35 * k)
			c.draw_polyline(arc, bright, maxf(0.4 * k, 3.5))
			c.draw_polyline(arc, lite, maxf(0.12 * k, 1.5))
		"hacker":
			c.draw_rect(Rect2(Vector2(0.6 * k, -0.28 * k), Vector2(0.7 * k, 0.56 * k)), bright, false, 1.8)
			c.draw_rect(Rect2(Vector2(0.72 * k, -0.17 * k), Vector2(0.46 * k, 0.34 * k)), lite)
		_:
			pass
	# head: helmet with dark rim, bright crown and visor slit
	var hc := Vector2(0.14 * k - (0.08 * k if ducked else 0.0), 0)
	c.draw_circle(hc, 0.4 * k * sq, dark)
	c.draw_circle(hc, 0.34 * k * sq, mid)
	c.draw_circle(hc + Vector2(-0.06 * k, 0), 0.22 * k * sq, lite)
	c.draw_arc(hc, 0.34 * k * sq, deg_to_rad(-60.0), deg_to_rad(60.0), 8, dark, maxf(0.14 * k, 1.8))
	c.draw_arc(hc, 0.4 * k * sq, 0, TAU, 20, lite, 1.0)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## What a dead unit leaves behind: a faint crumpled body under a splatter in its team colour.
static func _splat(c, pos: Vector2, ang: float, r: float, col: Color, type: String, seed_v: int, spread: float, alpha: float) -> void:
	_figure(c, pos, ang, r * 0.9, col.darkened(0.35), type, true, 0.3 * alpha, false)
	var base := col
	base.a = 0.75 * alpha
	var pool := col.darkened(0.2)
	pool.a = 0.5 * alpha
	c.draw_colored_polygon(_ellipse(pos, r * 1.5 * spread, r * 1.2 * spread, 16), pool)
	for i in range(40):
		var h: int = (seed_v * 131 + i * 7919) % 1000
		var a: float = TAU * float((h * 7) % 360) / 360.0
		var d: float = r * (0.1 + float((h * 13) % 100) / 100.0 * 2.1) * spread
		var rr: float = r * (0.08 + float((h * 29) % 100) / 100.0 * 0.3) * (0.4 + 0.6 * spread)
		c.draw_circle(pos + Vector2(cos(a), sin(a)) * d, rr, base)
	for i in range(8):
		var h2: int = (seed_v * 97 + i * 6007) % 1000
		var a2: float = ang + PI + (float(h2 % 100) - 50.0) / 80.0
		var d2: float = r * (1.2 + float((h2 * 3) % 100) / 100.0 * 1.4) * spread
		c.draw_line(pos + Vector2(cos(a2), sin(a2)) * r * 0.4 * spread, pos + Vector2(cos(a2), sin(a2)) * d2, base, maxf(r * 0.1, 1.5))

static func _facing_rad(facing: int) -> float:
	return float(facing) / 10.0 * PI / 180.0

static func _unit_figure(b, c, pos: Vector2, u_team: int, type: String, facing: int, ducked: bool, alpha: float = 1.0, ghost: bool = false, moving: bool = false, phase: float = 0.0) -> void:
	_figure(c, pos, _facing_rad(facing), b.ts * 0.78, TEAM_COL[u_team], type, ducked, alpha, ghost, moving, phase)

static func _cross(c, p: Vector2, r: float, col: Color) -> void:
	c.draw_arc(p, r, 0, TAU, 20, col, 1.6)
	c.draw_line(p + Vector2(-r * 1.5, 0), p + Vector2(-r * 0.5, 0), col, 1.6)
	c.draw_line(p + Vector2(r * 0.5, 0), p + Vector2(r * 1.5, 0), col, 1.6)
	c.draw_line(p + Vector2(0, -r * 1.5), p + Vector2(0, -r * 0.5), col, 1.6)
	c.draw_line(p + Vector2(0, r * 0.5), p + Vector2(0, r * 1.5), col, 1.6)

## Small pictogram: crouching (ducked) or upright figure.
static func _stance_icon(c, p: Vector2, ducked: bool, col: Color) -> void:
	c.draw_circle(p + Vector2(0, -6), 2.6, col)
	if ducked:
		c.draw_line(p + Vector2(0, -3), p + Vector2(3, 3), col, 2.0)
		c.draw_line(p + Vector2(3, 3), p + Vector2(-3, 7), col, 2.0)
		c.draw_line(p + Vector2(3, 3), p + Vector2(8, 7), col, 2.0)
	else:
		c.draw_line(p + Vector2(0, -3), p + Vector2(0, 4), col, 2.0)
		c.draw_line(p + Vector2(0, 4), p + Vector2(-3, 9), col, 2.0)
		c.draw_line(p + Vector2(0, 4), p + Vector2(3, 9), col, 2.0)
		c.draw_line(p + Vector2(-4, -1), p + Vector2(4, -1), col, 2.0)

static func _orders(b, c, id: int, o: Dictionary, col: Color, off: float, test: bool = false) -> void:
	var u = b._unit(id)
	var prev: Vector2 = b._p(u.x, u.y)
	var line_col := Color(1, 1, 1, 0.55 if test else 0.92)
	var node_col := col
	node_col.a = 1.0 if not test else 0.65
	var sqs: float = b.ts * 0.26
	var aim_col := Color(0.85, 0.95, 1.0, 0.55)
	for wp in o.get("path", []):
		var q: Vector2 = b._p(wp["x"], wp["y"])
		c.draw_line(prev, q, line_col, 2.6)
		c.draw_rect(Rect2(q - Vector2(sqs, sqs) * 0.5, Vector2(sqs, sqs)), node_col)
		if wp["wait"] > 0:
			_text(c, q + Vector2(8, -8), "%ds" % wp["wait"], line_col, 12)
		if wp["duck"] != u.ducked or wp["duck"]:
			_stance_icon(c, q + Vector2(-12, 14), wp["duck"], line_col)
		if wp["aim_x"] >= 0:
			var ap: Vector2 = b._p(wp["aim_x"], wp["aim_y"])
			_dash(c, q, ap, aim_col, 1.2, 5.0, 6.0, off)
			_cross(c, ap, 5.0, Color(1, 1, 1, 0.85))
		prev = q
	if o.has("aim"):
		var ap2: Vector2 = b._p(o["aim"]["x"], o["aim"]["y"])
		_dash(c, b._p(u.x, u.y), ap2, aim_col, 1.2, 5.0, 6.0, off)
		_cross(c, ap2, 5.0, Color(1, 1, 1, 0.85))
	if o.has("fire"):
		var fp: Vector2 = b._p(o["fire"]["x"], o["fire"]["y"])
		var rad: float = Balance.EXPLOSIVES[Balance.TYPES[u.type]["kind"]]["radius"] / 1000.0 * b.ts
		var oc := Color(1.0, 0.62, 0.2, 0.95)
		c.draw_arc(fp, rad, 0, TAU, 40, Color(1.0, 0.62, 0.2, 0.5), 1.4)
		_cross(c, fp, 6.0, oc)
		_dash(c, b._p(u.x, u.y), fp, Color(1.0, 0.62, 0.2, 0.55), 1.4, 5.0, 6.0, off)
	if o.has("duck") and o["path"].is_empty():
		_stance_icon(c, b._p(u.x, u.y) + Vector2(-b.ts * 0.9, b.ts * 0.6), o["duck"], line_col)
	if o.get("cos", false):
		_text(c, b._p(u.x, u.y) + Vector2(-10, -b.ts * 0.95), "HOLD FIRE", Color(1, 0.95, 0.5), 11)
	for eid in o.get("ignore", []):
		var e = b._unit(eid)
		if e != null:
			var q2: Vector2 = b._p(e.x, e.y)
			c.draw_line(q2 - Vector2(7, 7), q2 + Vector2(7, 7), Color(1, 1, 0.3), 2.0)
			c.draw_line(q2 - Vector2(7, -7), q2 + Vector2(7, -7), Color(1, 1, 0.3), 2.0)

static func _plan_layer(b, c, m) -> void:
	var game = b.game
	if game.dark and b.fog_tex != null:
		c.draw_texture_rect(b.fog_tex, Rect2(b.origin, Vector2(m.w, m.h) * b.ts), false)
	var off: float = Time.get_ticks_msec() * 0.012
	for id in b.test_orders.keys():
		_orders(b, c, id, b.test_orders[id], TEST_COL, off, true)
	for id2 in b.orders.keys():
		if b._unit(id2) != null and b._unit(id2).alive:
			_orders(b, c, id2, b.orders[id2], ORDER_COL, off)
	var visible_ids: Array = game.visible_enemy_ids(b.view_team)
	for u in game.sim.units:
		if not u.alive:
			if u.extracted:
				continue
			_splat(c, b._p(u.x, u.y), _facing_rad(u.facing), b.ts * 0.78, TEAM_COL[u.team], u.type, u.id, 1.0, 1.0)
			continue
		if u.team == b.view_team:
			_unit_figure(b, c, b._p(u.x, u.y), u.team, u.type, u.facing, u.ducked)
		elif visible_ids.has(u.id):
			_unit_figure(b, c, b._p(u.x, u.y), u.team, u.type, u.facing, u.ducked)
		elif game.dark and game.last_seen[b.view_team].has(u.id):
			var ls: Array = game.last_seen[b.view_team][u.id]
			_unit_figure(b, c, b._p(ls[0], ls[1]), u.team, u.type, 0, false, 0.5, true)

static func _replay_units(b, c, st: Dictionary) -> void:
	var game = b.game
	var f: int = st["f"]
	var fa: float = st["fa"]
	var fr: Dictionary = b.rframes[f]
	var nxt: Dictionary = b.rframes[mini(f + 1, b.rframes.size() - 1)]
	var seen: Dictionary = {}
	if game.dark and not b.rshow_all:
		seen = b._replay_visible(f)
	for a in fr["u"]:
		var u = b._unit(a[0])
		var nb: Array = b._frame_unit(nxt, a[0])
		if u.team != b.rview and game.dark and not b.rshow_all and not seen.has(a[0]):
			continue
		if not a[4]:
			var dt: int = b.death_ticks.get(a[0], -100)
			var spread: float = clampf(float(f - dt) / 6.0, 0.0, 1.0)
			_splat(c, b._p(a[1], a[2]), _facing_rad(a[3]), b.ts * 0.78, TEAM_COL[u.team], u.type, a[0], spread, 1.0)
			continue
		var pos: Vector2 = b._p(lerpf(a[1], nb[1], fa), lerpf(a[2], nb[2], fa))
		var moving: bool = absi(nb[1] - a[1]) + absi(nb[2] - a[2]) > 20
		_unit_figure(b, c, pos, u.team, u.type, a[3], bool(a[5]), 1.0, false, moving, b.rt + float(a[0]) * 0.37)

# ------------------------------------------------------------------ additive glow layer

static func draw_glow(b, c) -> void:
	_textures()
	if b.game == null:
		return
	var game = b.game
	var m = game.sim.map
	var st: Dictionary = _state(b)
	var cur: PackedByteArray = st["cur"]
	var f: int = st["f"]
	# soft light pools on the floor
	var cx: float = b.origin.x + m.w * b.ts * 0.5
	var cy: float = b.origin.y + m.h * b.ts * 0.5
	_glow_blob(c, Vector2(cx, cy), maxf(m.w, m.h) * b.ts * 0.55, Color(0.1, 0.28, 0.9, 0.10))
	# drifting blue debris cubes (atmosphere)
	var dseed: int = m.w * 31 + m.h * 17
	for i in range(46):
		var h1: int = (dseed + i * 7919) % 1000
		var h2: int = (dseed * 3 + i * 104729) % 1000
		var dp := Vector2(b.origin.x + float(h1) / 1000.0 * m.w * b.ts, b.origin.y + float(h2) / 1000.0 * m.h * b.ts)
		dp += Vector2(sin(Time.get_ticks_msec() * 0.0004 + i), cos(Time.get_ticks_msec() * 0.0003 + i * 2.0)) * 4.0
		var sz: float = 3.0 + float((h1 * h2) % 6)
		var da: float = float(h1 % 90) * 0.0175
		var pts := PackedVector2Array()
		for q in range(4):
			var qa: float = da + q * PI * 0.5
			pts.append(dp + Vector2(cos(qa), sin(qa)) * sz)
		c.draw_colored_polygon(pts, Color(0.3, 0.55, 1.0, 0.18))
	# glowing wall-top edges
	var ctr: Vector2 = b.size * 0.5
	for e in _sorted_blocks(b, cur, m):
		var tx: int = e[1]
		var ty: int = e[2]
		var is_wall: bool = e[3] == SimMap.WALL
		var inset := 0.0 if is_wall else 0.17
		var h: float = H_WALL if is_wall else H_LOW
		var base: PackedVector2Array = _corners(b, tx, ty, inset)
		var top := PackedVector2Array()
		for v in base:
			top.append(lean(b, v, h))
		for i in range(4):
			var nb: Vector2i = EDGE_NB[i]
			if is_wall and _tile_kind(cur, m, tx + nb.x, ty + nb.y) == SimMap.WALL:
				continue
			var gc := Color(0.3, 0.65, 1.0, 0.13) if is_wall else Color(0.45, 0.75, 1.0, 0.12)
			c.draw_line(top[i], top[(i + 1) % 4], gc, 5.0)
	# zones glow slightly
	var md: Dictionary = game.sim.mode
	if md.get("type", "") == "secure":
		_glow_blob(c, _rect_px(b, md["zone"]).get_center(), b.ts * 3.0, Color(1.0, 0.8, 0.2, 0.18))
	# units
	if b.phase == "replay":
		_glow_replay_units(b, c, st)
	else:
		var visible_ids: Array = game.visible_enemy_ids(b.view_team)
		for u in game.sim.units:
			if not u.alive:
				continue
			if u.team == b.view_team or visible_ids.has(u.id):
				var col: Color = TEAM_COL[u.team]
				col.a = 0.13
				_glow_blob(c, b._p(u.x, u.y), b.ts * 1.1, col)
		if b.selected >= 0 and b._unit(b.selected) != null and b._unit(b.selected).alive:
			var su = b._unit(b.selected)
			var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006)
			c.draw_arc(b._p(su.x, su.y), b.ts * (0.62 + 0.04 * pulse), 0, TAU, 32, Color(1, 1, 1, 0.9), 2.0)
			_glow_blob(c, b._p(su.x, su.y), b.ts * 1.3, Color(1, 1, 1, 0.2))
		# orders glow
		for id in b.orders.keys():
			var u2 = b._unit(id)
			if u2 == null:
				continue
			var prev: Vector2 = b._p(u2.x, u2.y)
			for wp in b.orders[id].get("path", []):
				var q: Vector2 = b._p(wp["x"], wp["y"])
				c.draw_line(prev, q, Color(0.3, 1.0, 0.6, 0.12), 6.0)
				prev = q
			if b.orders[id].has("fire"):
				_glow_blob(c, b._p(b.orders[id]["fire"]["x"], b.orders[id]["fire"]["y"]), b.ts * 1.6, Color(1.0, 0.5, 0.1, 0.18))

static func _glow_replay_units(b, c, st: Dictionary) -> void:
	var game = b.game
	var f: int = st["f"]
	var fa: float = st["fa"]
	var fr: Dictionary = b.rframes[f]
	var nxt: Dictionary = b.rframes[mini(f + 1, b.rframes.size() - 1)]
	var seen: Dictionary = {}
	if game.dark and not b.rshow_all:
		seen = b._replay_visible(f)
	var hidden := {}
	for a in fr["u"]:
		var u = b._unit(a[0])
		var visible_unit: bool = u.team == b.rview or not game.dark or b.rshow_all or seen.has(a[0])
		if not visible_unit:
			hidden[a[0]] = true
			continue
		if not a[4]:
			continue
		var nb: Array = b._frame_unit(nxt, a[0])
		var pos: Vector2 = b._p(lerpf(a[1], nb[1], fa), lerpf(a[2], nb[2], fa))
		var col: Color = TEAM_COL[u.team]
		col.a = 0.13
		_glow_blob(c, pos, b.ts * 1.1, col)
	var dashoff: float = b.rt * 70.0
	for pr in fr["p"]:
		var pp: Vector2 = b._p(pr[1], pr[2])
		_glow_blob(c, pp, b.ts * 0.9, Color(1.0, 0.75, 0.3, 0.7))
		c.draw_circle(pp, 3.0, Color(1, 1, 1, 1))
	for e in b.revents:
		var age: int = f - e["tick"]
		if age < 0:
			continue
		match e["type"]:
			"shot":
				if age <= 2 and not hidden.has(e["shooter"]):
					var s: Array = b._frame_unit(b.rframes[e["tick"]], e["shooter"])
					var t: Array = b._frame_unit(b.rframes[e["tick"]], e["target"])
					if not s.is_empty() and not t.is_empty():
						var a0: Vector2 = b._p(s[1], s[2])
						var a1: Vector2 = b._p(t[1], t[2])
						if e["hit"]:
							c.draw_line(a0, a1, Color(1.0, 0.5, 0.45, 0.28), 8.0)
							_dash(c, a0, a1, Color(1, 1, 1, 0.95), 2.4, 7.0, 4.0, dashoff)
							_glow_blob(c, a1, b.ts * 1.4, Color(1.0, 0.45, 0.35, 0.55))
						else:
							c.draw_line(a0, a1, Color(0.7, 0.85, 1.0, 0.08), 5.0)
							_dash(c, a0, a1, Color(0.9, 0.95, 1.0, 0.7), 1.4, 6.0, 6.0, dashoff)
						var dir: Vector2 = (a1 - a0).normalized()
						var muzzle: Vector2 = a0 + dir * b.ts * 1.1
						_glow_blob(c, muzzle, b.ts * 0.9, Color(1.0, 0.95, 0.7, 0.8))
						for si in range(6):
							var sa: float = dir.angle() + (float(si) - 2.5) * 0.35
							c.draw_line(muzzle, muzzle + Vector2(cos(sa), sin(sa)) * b.ts * 0.7, Color(1, 1, 0.9, 0.85), 1.4)
			"explosion":
				if age <= 26:
					_explosion(b, c, e, age)
			"kill":
				if age <= 8:
					var v: Array = b._frame_unit(b.rframes[e["tick"]], e["victim"])
					if not v.is_empty() and not hidden.has(e["victim"]):
						_glow_blob(c, b._p(v[1], v[2]), b.ts * (1.0 + 0.2 * age), Color(1, 1, 1, 0.5 * (1.0 - float(age) / 8.0)))
	var label_dummy := 0
	label_dummy += 1

static func _explosion(b, c, e: Dictionary, age: int) -> void:
	var center: Vector2 = b._p(e["x"], e["y"])
	var r: float = e["radius"] / 1000.0 * b.ts
	var k: float = float(age) / 26.0
	var fade: float = 1.0 - k
	# white-hot core and a wide blue-white bloom (the bloom is the dominant part of the look)
	_glow_blob(c, center, r * (1.6 + 2.4 * k), Color(0.35, 0.55, 1.0, 0.5 * fade))
	_glow_blob(c, center, r * (1.0 + 1.2 * k), Color(0.7, 0.85, 1.0, 0.8 * fade))
	_glow_blob(c, center, r * (0.7 + 0.5 * k), Color(1, 1, 1, 1.0 * fade))
	_glow_blob(c, center, r * 0.5, Color(1, 1, 1, 1.0 * pow(fade, 2.0)))
	c.draw_arc(center, r * (0.25 + 1.05 * k), 0, TAU, 48, Color(0.8, 0.9, 1.0, 0.5 * fade), 2.0)
	# radial sparks, deterministic per explosion
	var seed_v: int = int(e["tick"]) * 31 + int(e["x"]) % 97
	for i in range(28):
		var h: int = (seed_v + i * 7919) % 1000
		var ang: float = TAU * float(i) / 28.0 + float(h) * 0.002
		var len_f: float = 0.5 + float((h * 37) % 100) / 100.0
		var d0: float = r * (0.15 + 0.5 * k)
		var d1: float = r * (0.35 + (0.9 + len_f * 0.6) * k)
		c.draw_line(center + Vector2(cos(ang), sin(ang)) * d0, center + Vector2(cos(ang), sin(ang)) * d1, Color(1, 1, 1, 0.9 * fade), 1.4)
