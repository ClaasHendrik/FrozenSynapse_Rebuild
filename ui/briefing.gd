extends Control
## Green satellite-style briefing screen: monochrome map with a wireframe building, a bracket marker and the mission
## title, a news ticker, speaker portraits, a dossier list and START OPERATION. Drawn entirely in code.

signal start_pressed
signal back_pressed

const GREEN_BG := Color("1d3a26")
const GREEN_MID := Color("4f8a58")
const GREEN_LITE := Color("b8f0c0")

var title_text := ""
var sub_text := ""
var objective_lines: Array = []
var ticker_text := ""
var speakers: Array = []         # [{name}]
var dossier: Array = []          # mission titles of the chapter
var current_index := 0
var _map_tex: ImageTexture = null
var _seed := 1
var _start_btn: Button
var _back_btn: Button
var _list: ItemList
var _t := 0.0

func setup(title: String, sub: String, objectives: Array, ticker: String, who: Array, doss: Array, cur: int, seed_value: int) -> void:
	title_text = title
	sub_text = sub
	objective_lines = objectives
	ticker_text = ticker
	speakers = who
	dossier = doss
	current_index = cur
	_seed = seed_value
	_build_map()
	_build_ui()
	queue_redraw()

func _build_map() -> void:
	var w := 320
	var h := 180
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed
	var f1 := FastNoiseLite.new()
	f1.seed = _seed
	f1.frequency = 0.012
	var f2 := FastNoiseLite.new()
	f2.seed = _seed + 7
	f2.frequency = 0.05
	for y in range(h):
		for x in range(w):
			var v: float = 0.5 + 0.5 * f1.get_noise_2d(x, y) * 0.8 + 0.2 * f2.get_noise_2d(x, y)
			var lvl: float = floorf(v * 9.0) / 9.0
			var c: Color = GREEN_BG.lerp(GREEN_MID, lvl * 0.9)
			# "roads": thin dark bands
			if absf(f2.get_noise_2d(x * 0.4 + 90.0, y * 0.4)) < 0.018:
				c = c.darkened(0.35)
			img.set_pixel(x, y, c)
	_map_tex = ImageTexture.create_from_image(img)

func _build_ui() -> void:
	for ch in get_children():
		ch.queue_free()
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.offset_bottom = -26
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.07, 0.2, 0.93)
	sb.border_color = Color(0.45, 0.7, 1.0, 0.9)
	sb.set_border_width_all(2)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)
	# speakers
	var sp := HBoxContainer.new()
	sp.add_theme_constant_override("separation", 10)
	row.add_child(sp)
	for s in speakers:
		var col := VBoxContainer.new()
		var pic := Control.new()
		pic.custom_minimum_size = Vector2(64, 78)
		pic.draw.connect(func(): _draw_portrait(pic, String(s)))
		col.add_child(pic)
		var l := Label.new()
		l.text = String(s)
		l.add_theme_font_size_override("font_size", 12)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(l)
		sp.add_child(col)
	# dossier
	var dv := VBoxContainer.new()
	var dh := Label.new()
	dh.text = "Dossier"
	dh.add_theme_font_size_override("font_size", 13)
	dv.add_child(dh)
	_list = ItemList.new()
	_list.custom_minimum_size = Vector2(300, 118)
	_list.add_theme_font_size_override("font_size", 12)
	for i in range(dossier.size()):
		_list.add_item("%d. %s" % [i + 1, dossier[i]])
	if current_index >= 0 and current_index < dossier.size():
		_list.select(current_index)
	dv.add_child(_list)
	row.add_child(dv)
	# objectives and buttons
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 6)
	var ol := Label.new()
	ol.text = "\n".join(objective_lines)
	ol.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ol.custom_minimum_size = Vector2(330, 0)
	ol.add_theme_font_size_override("font_size", 12)
	bv.add_child(ol)
	_start_btn = Button.new()
	_start_btn.text = "START OPERATION"
	_start_btn.pressed.connect(func(): start_pressed.emit())
	bv.add_child(_start_btn)
	_back_btn = Button.new()
	_back_btn.text = "BACK"
	_back_btn.pressed.connect(func(): back_pressed.emit())
	bv.add_child(_back_btn)
	row.add_child(bv)

func _draw_portrait(c: Control, name: String) -> void:
	var r := Rect2(Vector2.ZERO, c.size)
	c.draw_rect(r, Color(0.04, 0.1, 0.22))
	c.draw_rect(r, Color(0.45, 0.7, 1.0, 0.8), false, 1.5)
	var h: int = name.hash()
	var skin := Color.from_hsv(0.07 + float(h % 10) / 200.0, 0.25, 0.75)
	var cl := Color.from_hsv(float((h >> 4) % 100) / 100.0, 0.35, 0.45)
	c.draw_rect(Rect2(8, 54, 48, 24), cl)
	c.draw_circle(Vector2(32, 38), 16.0, skin)
	c.draw_rect(Rect2(16, 18, 32, 11), Color.from_hsv(float((h >> 8) % 100) / 100.0, 0.5, 0.25))
	c.draw_line(Vector2(24, 40), Vector2(40, 40), Color(0.1, 0.1, 0.12), 2.0)

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	var s := size
	draw_rect(Rect2(Vector2.ZERO, s), GREEN_BG)
	if _map_tex != null:
		draw_texture_rect(_map_tex, Rect2(Vector2.ZERO, s), false, Color(1, 1, 1, 0.95))
	# scanlines
	var y := 0.0
	while y < s.y:
		draw_line(Vector2(0, y), Vector2(s.x, y), Color(0, 0.1, 0, 0.18), 1.0)
		y += 3.0
	# wireframe building, isometric stepped tower
	var cx := s.x * 0.34
	var cy := s.y * 0.40
	var u: float = minf(s.x, s.y * 1.6) / 30.0
	for tier in range(5):
		var w: float = (9.0 - tier * 1.5) * u
		var d: float = (6.0 - tier * 1.0) * u
		var z: float = tier * 1.3 * u
		var top := Vector2(cx, cy - z - 1.3 * u)
		var pts := [
			top + Vector2(-w * 0.5, 0), top + Vector2(0, -d * 0.5), top + Vector2(w * 0.5, 0), top + Vector2(0, d * 0.5)]
		var base: Array = []
		for p in pts:
			base.append(p + Vector2(0, 1.3 * u))
		var fillc := Color(0.25, 0.5, 0.3, 0.55)
		draw_colored_polygon(PackedVector2Array([pts[0], pts[3], base[3], base[0]]), fillc.darkened(0.15))
		draw_colored_polygon(PackedVector2Array([pts[3], pts[2], base[2], base[3]]), fillc.lightened(0.05))
		draw_colored_polygon(PackedVector2Array(pts), fillc.lightened(0.25))
		var edge := GREEN_LITE
		edge.a = 0.9
		for i in range(4):
			draw_line(pts[i], pts[(i + 1) % 4], edge, 1.5)
			draw_line(base[i], base[(i + 1) % 4], edge, 1.0)
			draw_line(pts[i], base[i], edge, 1.0)
		for k in range(1, 6):
			var a: Vector2 = pts[0].lerp(pts[3], float(k) / 6.0)
			var b: Vector2 = pts[1].lerp(pts[2], float(k) / 6.0)
			draw_line(a, b, Color(edge, 0.35), 1.0)
	# bracket marker + title
	var bp := Vector2(cx - 40.0, cy - 40.0)
	var bs := 64.0
	var bc := Color(1, 1, 1, 0.9)
	for corner in [[Vector2(0, 0), Vector2(1, 0), Vector2(0, 1)], [Vector2(bs, 0), Vector2(-1, 0), Vector2(0, 1)], [Vector2(0, bs), Vector2(1, 0), Vector2(0, -1)], [Vector2(bs, bs), Vector2(-1, 0), Vector2(0, -1)]]:
		var o: Vector2 = bp + corner[0]
		draw_line(o, o + corner[1] * 16.0, bc, 2.0)
		draw_line(o, o + corner[2] * 16.0, bc, 2.0)
	var font := ThemeDB.fallback_font
	draw_string(font, bp + Vector2(bs + 14.0, 36.0), title_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1, 0.95))
	draw_string(font, bp + Vector2(bs + 14.0, 60.0), sub_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.8, 1.0, 0.85, 0.85))
	# ticker
	var ty := s.y - 262.0
	draw_rect(Rect2(0, ty, s.x, 20), Color(0.02, 0.07, 0.2, 0.92))
	draw_rect(Rect2(0, ty, s.x, 20), Color(0.45, 0.7, 1.0, 0.7), false, 1.0)
	var tw: float = font.get_string_size(ticker_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	var off: float = fposmod(_t * 60.0, tw + s.x)
	draw_string(font, Vector2(s.x - off, ty + 15.0), ticker_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.9, 0.95, 1.0))
