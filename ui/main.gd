extends Control
## Menus, turn flow (vs AI / hotseat), side panel and overlays.

const Match = preload("res://sim/match.gd")
const AI = preload("res://sim/ai.gd")
const Board = preload("res://ui/board.gd")
const View = preload("res://ui/board_view.gd")
const Balance = preload("res://sim/balance.gd")
const CampaignData = preload("res://campaign/campaign_data.gd")
const MissionRules = preload("res://sim/mission.gd")

const MODES := ["extermination", "secure", "disputed", "hostage", "charge", "upload"]
const MODE_TEXT := {
	"extermination": "Extermination — destroy every enemy unit (8 turns).",
	"secure": "Secure — the defender deploys in the yellow zone. The attacker must survive 3 s inside it after turn 2.",
	"disputed": "Disputed — boxes appear after turn 4. Carry a box into a green edge zone to score it.",
	"hostage": "Hostage — the rescuer (green) orders the hostages from turn 2 and gets one to a green edge. Hostages are safe inside the yellow square.",
	"charge": "Charge — the attacker must hold a unit on or past the yellow line for the last 3 s of turn 6.",
	"upload": "Upload — kill the enemy hacker (H) before they kill yours (8 turns). Hackers are marked K.",
}

var game
var board
var vs_ai := true
var plan_team := 0
var committed := {}
var phase := "menu"
var last_replay := {}
var campaign_mode := false
var campaign_pack: Dictionary = {}
var campaign_mission: Dictionary = {}
var progress: Dictionary = {}
var unlock_all := false
var campaign_box: Control
var campaign_list: VBoxContainer
var pack_opt: OptionButton
var packs: Array = []
var overlay_btn2: Button
var overlay_action2: Callable

# widgets
var menu_box: Control
var game_box: Control
var side_label: Label
var plan_row: HBoxContainer
var replay_row: HBoxContainer
var unit_row: HBoxContainer
var turn_label: Label
var weapon_label: Label
var topbar: PanelContainer
var ctx: PopupMenu
var _ctx_world := Vector2i.ZERO
var _ctx_unit := -1
var bar_pinned := false
var _bar_timer := 0.0
var unit_label: Label
var help_label: Label
var plan_buttons: Control
var replay_buttons: Control
var timeline: HSlider
var overlay: ColorRect
var overlay_label: Label
var overlay_btn: Button
var overlay_action: Callable
var mode_opt: OptionButton
var dark_chk: CheckBox
var opp_opt: OptionButton
var seed_spin: SpinBox
var squad_spin: SpinBox
var pause_btn: Button
var _updating_slider := false

func _ready() -> void:
	progress = CampaignData.load_progress()
	_build_menu()
	_build_campaign()
	_build_game()
	_build_overlay()
	_show_phase("menu")

# ------------------------------------------------------------------ UI construction

func _label(text: String, size: int = 16) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	return l

func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_stylebox_override("normal", _neon_style(Color(0.03, 0.09, 0.3, 0.92), Color(0.3, 0.6, 1.0, 0.55)))
	b.add_theme_stylebox_override("hover", _neon_style(Color(0.08, 0.22, 0.6, 1.0), Color(0.7, 0.9, 1.0, 0.95)))
	b.add_theme_stylebox_override("pressed", _neon_style(Color(0.12, 0.35, 0.85, 1.0), Color(1, 1, 1, 1)))
	b.add_theme_stylebox_override("disabled", _neon_style(Color(0.02, 0.04, 0.1, 0.8), Color(0.2, 0.3, 0.5, 0.3)))
	return b

func _build_menu() -> void:
	View._textures()
	var bg := TextureRect.new()
	bg.texture = View._tex_bg
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	menu_box = CenterContainer.new()
	menu_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(menu_box)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(460, 0)
	v.add_theme_constant_override("separation", 10)
	menu_box.add_child(v)
	var title := _label("COLD SYNAPSE", 44)
	title.add_theme_color_override("font_color", Color("5cc8ff"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var sub := _label("simultaneous-turn tactics", 16)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	mode_opt = OptionButton.new()
	for m in MODES:
		mode_opt.add_item(m.capitalize())
	v.add_child(_label("Mode"))
	v.add_child(mode_opt)
	dark_chk = CheckBox.new()
	dark_chk.text = "Dark (fog of war)"
	v.add_child(dark_chk)
	opp_opt = OptionButton.new()
	opp_opt.add_item("Versus computer")
	opp_opt.add_item("Hotseat (two players, one screen)")
	v.add_child(_label("Opponent"))
	v.add_child(opp_opt)
	seed_spin = SpinBox.new()
	seed_spin.min_value = 1
	seed_spin.max_value = 999999
	seed_spin.value = randi_range(1, 99999)
	v.add_child(_label("Map seed"))
	v.add_child(seed_spin)
	squad_spin = SpinBox.new()
	squad_spin.min_value = 3
	squad_spin.max_value = 8
	squad_spin.value = 5
	v.add_child(_label("Units per side"))
	v.add_child(squad_spin)
	v.add_child(_button("Start skirmish", _on_start))
	v.add_child(_button("Campaign and mission packs", _open_campaign))
	v.add_child(_button("Quit", func(): get_tree().quit()))

func _build_campaign() -> void:
	campaign_box = PanelContainer.new()
	campaign_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(campaign_box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	campaign_box.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	top.add_child(_label("Campaign", 28))
	pack_opt = OptionButton.new()
	packs = CampaignData.list_packs()
	for pk in packs:
		pack_opt.add_item("%s  (%d missions)" % [pk["title"], pk["flat"].size()])
	pack_opt.item_selected.connect(func(_i): _refresh_campaign())
	top.add_child(pack_opt)
	var unlock := CheckBox.new()
	unlock.text = "Unlock all missions"
	unlock.toggled.connect(func(on): unlock_all = on; _refresh_campaign())
	top.add_child(unlock)
	top.add_child(_button("Back", func(): _show_phase("menu")))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)
	campaign_list = VBoxContainer.new()
	campaign_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	campaign_list.add_theme_constant_override("separation", 4)
	scroll.add_child(campaign_list)

func _open_campaign() -> void:
	_show_phase("campaign")
	_refresh_campaign()

func _refresh_campaign() -> void:
	for ch in campaign_list.get_children():
		ch.queue_free()
	if packs.is_empty():
		return
	campaign_pack = packs[pack_opt.selected]
	var done_n := 0
	for item in campaign_pack["flat"]:
		if CampaignData.is_done(progress, campaign_pack["id"], item["mission"]["id"]):
			done_n += 1
	var blurb := _label("%s — %d / %d complete" % [campaign_pack["blurb"], done_n, campaign_pack["flat"].size()], 14)
	campaign_list.add_child(blurb)
	for ci in range(campaign_pack["chapters"].size()):
		var chap: Dictionary = campaign_pack["chapters"][ci]
		var head := _label("%d. %s" % [ci + 1, chap["title"]], 20)
		head.add_theme_color_override("font_color", Color("5cc8ff"))
		campaign_list.add_child(head)
		var row := HBoxContainer.new()
		campaign_list.add_child(row)
		for m in chap["missions"]:
			var done: bool = CampaignData.is_done(progress, campaign_pack["id"], m["id"])
			var b := Button.new()
			b.text = "%s%d  %s" % ["✓ " if done else "", m["id"], m["title"]]
			b.disabled = not CampaignData.is_unlocked(progress, campaign_pack["id"], m["id"], unlock_all)
			b.focus_mode = Control.FOCUS_NONE
			var mm: Dictionary = m
			var cc: int = ci
			b.pressed.connect(func(): _show_briefing(cc, mm))
			row.add_child(b)

const TICKERS := [
	"SYNDICATED NEWS: The Ministry of Optimism reports that supplies are not low, merely ambitious.   ***   Weather: unsettled, with a chance of paperwork.",
	"SYNDICATED NEWS: Local committee forms subcommittee to study the committee.   ***   Cheese prices steady, which the cheese inspectorate calls 'suspicious'.",
	"SYNDICATED NEWS: Official statement: nothing happened. Unofficial statement: it happened quietly.   ***   Reminder: Form 14-B requires Form 14-A.",
	"SYNDICATED NEWS: Border patrol praised for 'thoroughly observing' the weather.   ***   Canteen coffee declared a strategic asset.",
]
const SPEAKERS := {"Nashar Ward": ["Nox", "Soulsbury"], "Power Station": ["Smith", "Nox"], "The Broadcast Studio": ["Nox", "Davies"], "Blue Daylight": ["Cole", "Davies"],
	"Cairn Dwelling": ["Cole", "Davies"], "Novena Quarter": ["Eshe", "Nox"], "Ninstar Tower": ["Eshe", "Nox"], "Dillenger's Villa": ["Riordan", "Nox"]}

var briefing: Control = null

func _show_briefing(ci: int, m: Dictionary) -> void:
	var chap: Dictionary = campaign_pack["chapters"][ci]
	var probe = Match.create_mission(m)
	var objectives: Array = [m["brief"], ""]
	objectives.append_array(probe.objective_lines())
	objectives.append("Squad %d  ·  enemy %d  ·  %d turns%s" % [probe.sim.alive_count(0), probe.sim.alive_count(1), m.get("turns", 8), "  ·  Dark" if m.get("dark", false) else ""])
	var titles: Array = []
	var idx := 0
	for k in range(chap["missions"].size()):
		titles.append(chap["missions"][k]["title"])
		if chap["missions"][k]["id"] == m["id"]:
			idx = k
	var who: Array = SPEAKERS.get(chap["title"], ["Nox", "Davies"])
	if briefing != null:
		briefing.queue_free()
	briefing = load("res://ui/briefing.gd").new()
	briefing.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(briefing)
	briefing.setup("%s - %s" % [chap["title"], m["title"]], "Mission %d  ·  %s" % [m["id"], campaign_pack.get("title", "")], objectives, TICKERS[int(m["id"]) % TICKERS.size()], who, titles, idx, int(m["id"]) * 31 + 5)
	if m["id"] == chap["missions"][0]["id"]:
		briefing.ticker_text = chap["intro"] + "   ***   " + briefing.ticker_text
	briefing.start_pressed.connect(func(): briefing.queue_free(); briefing = null; _start_mission(m))
	briefing.back_pressed.connect(func(): briefing.queue_free(); briefing = null; _show_phase("campaign"))

func _start_mission(m: Dictionary) -> void:
	campaign_mode = true
	campaign_mission = m
	vs_ai = true
	game = Match.create_mission(m)
	help_label.visible = true
	board.set_game(game)
	committed = {}
	last_replay = {}
	_begin_turn()

func _neon_style(bg: Color, border: Color, radius: int = 4) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	return sb

func _build_game() -> void:
	game_box = Control.new()
	game_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	game_box.clip_contents = true
	add_child(game_box)
	board = Board.new()
	board.set_anchors_preset(Control.PRESET_FULL_RECT)
	game_box.add_child(board)
	board.orders_changed.connect(_refresh_side)
	board.selection_changed.connect(_refresh_side)
	board.replay_finished.connect(_on_replay_finished)
	board.context_requested.connect(_on_context)
	# --- small status readout, bottom-left (mode, objectives, selected unit)
	var hud := PanelContainer.new()
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_theme_stylebox_override("panel", _neon_style(Color(0.01, 0.03, 0.12, 0.45), Color(0.3, 0.6, 1.0, 0.2), 4))
	hud.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hud.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hud.offset_left = 10
	hud.offset_bottom = -40
	game_box.add_child(hud)
	var hv := VBoxContainer.new()
	hv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(hv)
	side_label = _label("", 12)
	side_label.custom_minimum_size = Vector2(300, 0)
	side_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hv.add_child(side_label)
	unit_label = _label("", 11)
	unit_label.add_theme_color_override("font_color", Color(0.65, 0.85, 1.0))
	unit_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	unit_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hv.add_child(unit_label)
	help_label = _label("Mouse to the top edge: orders. Right-click: menu.", 11)
	help_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6))
	help_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hv.add_child(help_label)
	# --- small buttons top-left (MAIN MENU / GAME / RESTART) and ORDERS bottom-left, like the original
	var tl := HBoxContainer.new()
	tl.add_theme_constant_override("separation", 2)
	tl.position = Vector2(4, 4)
	game_box.add_child(tl)
	for spec in [["MAIN MENU", func(): _show_phase("menu")], ["GAME", func(): bar_pinned = not bar_pinned], ["RESTART", _on_restart]]:
		var tb := _button(spec[0], spec[1])
		tb.add_theme_font_size_override("font_size", 10)
		tl.add_child(tb)
	var orders_btn := _button("ORDERS", func(): bar_pinned = not bar_pinned)
	orders_btn.add_theme_font_size_override("font_size", 10)
	orders_btn.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	orders_btn.grow_vertical = Control.GROW_DIRECTION_BEGIN
	orders_btn.offset_left = 4
	orders_btn.offset_bottom = -4
	game_box.add_child(orders_btn)
	# --- control block, bottom centre: PREV UNIT | weapon | NEXT UNIT, PRIME, turn, time bar
	var blk := PanelContainer.new()
	blk.add_theme_stylebox_override("panel", _neon_style(Color(0.01, 0.04, 0.16, 0.9), Color(0.35, 0.65, 1.0, 0.8), 2))
	blk.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	blk.grow_vertical = Control.GROW_DIRECTION_BEGIN
	blk.grow_horizontal = Control.GROW_DIRECTION_BOTH
	blk.offset_bottom = -4
	game_box.add_child(blk)
	var bk := VBoxContainer.new()
	bk.add_theme_constant_override("separation", 2)
	blk.add_child(bk)
	plan_row = HBoxContainer.new()
	plan_row.add_theme_constant_override("separation", 4)
	bk.add_child(plan_row)
	var test_btn := _button("TEST", _on_test)
	test_btn.tooltip_text = "Preview this turn on a copy of the game  [Space]"
	plan_row.add_child(test_btn)
	turn_label = _label("TURN 1", 14)
	turn_label.custom_minimum_size = Vector2(130, 0)
	turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plan_row.add_child(turn_label)
	var prime_btn := _button("PRIME  ▶", _on_commit)
	prime_btn.tooltip_text = "Lock in the turn  [Enter]"
	plan_row.add_child(prime_btn)
	replay_row = HBoxContainer.new()
	replay_row.add_theme_constant_override("separation", 4)
	bk.add_child(replay_row)
	pause_btn = _button("PAUSE", _toggle_pause)
	replay_row.add_child(pause_btn)
	replay_row.add_child(_button("SPEED", func(): board.rspeed = 1.0 if board.rspeed >= 4.0 else board.rspeed * 2.0))
	replay_row.add_child(_button("SKIP", func(): board.end_replay()))
	unit_row = HBoxContainer.new()
	unit_row.add_theme_constant_override("separation", 4)
	bk.add_child(unit_row)
	unit_row.add_child(_button("◀ PREV UNIT", func(): board.select_prev()))
	weapon_label = _label("", 12)
	weapon_label.custom_minimum_size = Vector2(160, 0)
	weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	unit_row.add_child(weapon_label)
	unit_row.add_child(_button("NEXT UNIT ▶", func(): board.select_next()))
	timeline = HSlider.new()
	timeline.min_value = 0.0
	timeline.max_value = 5.0
	timeline.step = 0.05
	timeline.custom_minimum_size = Vector2(380, 14)
	timeline.focus_mode = Control.FOCUS_NONE
	timeline.value_changed.connect(func(val): if not _updating_slider: board.rt = val; board.rpaused = true; board.queue_redraw())
	bk.add_child(timeline)
	# --- orders bar: slides in when the cursor touches the top edge
	topbar = PanelContainer.new()
	topbar.add_theme_stylebox_override("panel", _neon_style(Color(0.01, 0.04, 0.16, 0.94), Color(0.35, 0.7, 1.0, 0.85), 0))
	topbar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	topbar.visible = false
	game_box.add_child(topbar)
	var bv := VBoxContainer.new()
	topbar.add_child(bv)
	plan_buttons = HBoxContainer.new()
	plan_buttons.add_theme_constant_override("separation", 4)
	bv.add_child(plan_buttons)
	for spec in [
		["Aim [A]", "Face a point; a pre-aimed unit wins the first shot", func(): board.set_tool("aim")],
		["Check [K]", "Glance at a point for 1 s while moving, then carry on", func(): board.set_tool("check")],
		["Stand", "Stand at the last waypoint", func(): board.set_stance(false)],
		["Duck [D]", "Duck at the last waypoint", func(): board.set_stance(true)],
		["Wait [W]", "Wait 1 s more at the last waypoint", func(): board.cycle_wait()],
		["Fire [F]", "Rocket / grenade: fire at a point", func(): board.set_tool("fire")],
		["Focus [O]", "Engage only a chosen enemy", func(): board.set_tool("focus")],
		["Ignore [I]", "Do not engage a chosen enemy", func(): board.set_tool("ignore")],
		["Clear F/I", "Clear focus and ignore", func(): board.clear_focus_ignore()],
		["Hold fire [C]", "Continue on sight: engage nobody", func(): board.toggle_cos()],
		["Engage", "Engage on sight again", func(): board.engage_on_sight()],
		["Undo [Bksp]", "Remove the last waypoint", func(): board.remove_last_waypoint()],
		["Clear [Del]", "Clear this unit's orders", func(): board.clear_orders()],
		["Last turn", "Watch the last turn again", _on_watch_last],
	]:
		var btn := _button(spec[0], spec[2])
		btn.tooltip_text = spec[1]
		btn.add_theme_font_size_override("font_size", 12)
		plan_buttons.add_child(btn)
	replay_buttons = HBoxContainer.new()
	bv.add_child(replay_buttons)
	replay_buttons.add_child(_label("Replay controls are in the block at the bottom.", 12))
	# --- right-click context menu
	ctx = PopupMenu.new()
	ctx.add_theme_stylebox_override("panel", _neon_style(Color(0.01, 0.04, 0.16, 0.97), Color(0.4, 0.75, 1.0, 0.9), 4))
	ctx.add_theme_stylebox_override("hover", _neon_style(Color(0.1, 0.3, 0.8, 1.0), Color(0.7, 0.9, 1.0, 0.0), 2))
	ctx.add_theme_color_override("font_color", Color(0.85, 0.93, 1.0))
	ctx.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	ctx.add_theme_color_override("font_separator_color", Color(0.4, 0.6, 1.0))
	ctx.add_theme_font_size_override("font_size", 14)
	ctx.id_pressed.connect(_on_ctx_item)
	add_child(ctx)

func _on_context(screen_pos: Vector2, world: Vector2i, unit_id: int) -> void:
	_ctx_world = world
	_ctx_unit = unit_id
	ctx.clear()
	help_label.visible = false
	if phase == "plan":
		var sel = game.sim.unit(board.selected) if board.selected >= 0 else null
		var own_hit = game.sim.unit(unit_id) if unit_id >= 0 else null
		if own_hit != null and board.game.can_order(plan_team, own_hit):
			ctx.add_item("Select this unit", 10)
		if sel != null and sel.alive:
			ctx.add_item("Add Waypoint", 1)
			ctx.add_item("Aim here", 2)
			ctx.add_item("Cancel Aim", 11)
			ctx.add_item("Check", 12)
			var kind: String = Balance.TYPES[sel.type]["kind"]
			if kind == "rocket" or kind == "grenade":
				ctx.add_item("Fire here", 3)
			ctx.add_separator()
			ctx.add_item("Engage on Sight", 13)
			ctx.add_item("Continue on Sight", 7)
			ctx.add_item("Stand", 14)
			ctx.add_item("Duck", 15)
			ctx.add_item("Wait 1 s more", 6)
			ctx.add_separator()
			if own_hit != null and own_hit.team != sel.team:
				ctx.add_item("Focus on Enemy", 16)
				ctx.add_item("Ignore Enemy", 4)
			ctx.add_item("Clear Focus/Ignore", 17)
			ctx.add_item("Undo last waypoint", 8)
			ctx.add_item("Clear this unit's orders", 9)
			ctx.add_separator()
		ctx.add_item("Next unit", 20)
		ctx.add_item("Test preview", 21)
		ctx.add_item("Commit turn", 22)
		if not last_replay.is_empty():
			ctx.add_item("Watch last turn", 23)
		ctx.add_item("Main menu", 24)
	elif phase == "replay":
		ctx.add_item("Resume" if board.rpaused else "Pause", 30)
		ctx.add_item("Change speed", 31)
		ctx.add_item("Skip", 32)
	else:
		return
	ctx.position = Vector2i(screen_pos)
	ctx.popup()

func _on_ctx_item(id: int) -> void:
	var w := _ctx_world
	match id:
		10: board.selected = _ctx_unit; board.selection_changed.emit(); board.queue_redraw()
		1: if board.selected >= 0: board.add_waypoint(board.selected, w.x, w.y)
		2: if board.selected >= 0: board.set_aim(board.selected, w.x, w.y)
		3: if board.selected >= 0: board.set_fire(board.selected, w.x, w.y)
		4: if board.selected >= 0 and _ctx_unit >= 0: board.toggle_ignore(board.selected, _ctx_unit)
		5: board.toggle_duck()
		11: board.cancel_aim()
		12: if board.selected >= 0: board.set_check(board.selected, w.x, w.y)
		13: board.engage_on_sight()
		14: board.set_stance(false)
		15: board.set_stance(true)
		16: if board.selected >= 0 and _ctx_unit >= 0: board.toggle_focus(board.selected, _ctx_unit)
		17: board.clear_focus_ignore()
		6: board.cycle_wait()
		7: board.toggle_cos()
		8: board.remove_last_waypoint()
		9: board.clear_orders()
		20: board.select_next()
		21: _on_test()
		22: _on_commit()
		23: _on_watch_last()
		24: _show_phase("menu")
		30: _toggle_pause()
		31: board.rspeed = 1.0 if board.rspeed >= 4.0 else board.rspeed * 2.0
		32: board.end_replay()

func _build_overlay() -> void:
	overlay = ColorRect.new()
	overlay.color = Color(0.03, 0.05, 0.1, 1.0)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(c)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	c.add_child(v)
	overlay_label = _label("", 28)
	overlay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(overlay_label)
	overlay_btn = _button("OK", func(): overlay.visible = false; overlay_action.call())
	v.add_child(overlay_btn)
	overlay_btn2 = _button("Cancel", func(): overlay.visible = false; overlay_action2.call())
	overlay_btn2.visible = false
	v.add_child(overlay_btn2)
	overlay.visible = false

func _show_overlay(text: String, button: String, action: Callable, button2: String = "", action2: Callable = Callable()) -> void:
	overlay_label.text = text
	overlay_label.add_theme_font_size_override("font_size", 20 if button2 != "" else 28)
	overlay_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	overlay_label.custom_minimum_size = Vector2(900 if button2 != "" else 640, 0)
	overlay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_btn.text = button
	overlay_action = action
	overlay_btn2.visible = button2 != ""
	overlay_btn2.text = button2
	overlay_action2 = action2
	overlay.visible = true

# ------------------------------------------------------------------ flow

func _show_phase(p: String) -> void:
	phase = p
	menu_box.get_parent().get_child(0).visible = (p == "menu" or p == "campaign")  # backdrop
	menu_box.visible = (p == "menu")
	campaign_box.visible = (p == "campaign")
	game_box.visible = (p != "menu" and p != "campaign")
	if p == "plan" or p == "pass":
		pass
	if p == "menu" or p == "campaign":
		overlay.visible = false
	plan_buttons.visible = (p == "plan")
	replay_buttons.visible = (p == "replay")
	plan_row.visible = (p == "plan")
	unit_row.visible = (p == "plan")
	replay_row.visible = (p == "replay")
	timeline.visible = (p == "replay")
	if p == "menu" or p == "campaign":
		topbar.visible = false
	_refresh_side()

func _on_start() -> void:
	campaign_mode = false
	vs_ai = opp_opt.selected == 0
	var opts := {"squad": int(squad_spin.value)}
	var mode: String = MODES[mode_opt.selected]
	if mode == "charge":
		opts["bid0"] = 14
		opts["bid1"] = 12
	game = Match.create(mode, int(seed_spin.value), dark_chk.button_pressed, opts)
	help_label.visible = true
	board.set_game(game)
	committed = {}
	last_replay = {}
	_begin_turn()

func _begin_turn() -> void:
	committed = {}
	if game.over:
		_show_end()
		return
	if vs_ai:
		_enter_plan(0)
	else:
		_pass_to(0)

func _pass_to(team: int) -> void:
	phase = "pass"
	_show_phase("pass")
	game_box.visible = true
	plan_buttons.visible = false
	_show_overlay("Player %d — get ready\n(Player %d, look away)" % [team + 1, 2 - team], "Ready", func(): _enter_plan(team))

func _enter_plan(team: int) -> void:
	plan_team = team
	board.begin_plan(team)
	_show_phase("plan")

func _team_name(team: int) -> String:
	if vs_ai:
		return "You (green)" if team == 0 else "Computer (red)"
	return "Player %d (%s)" % [team + 1, "green" if team == 0 else "red"]

func _refresh_side() -> void:
	if game == null or side_label == null:
		return
	var s := "%s - turn %d%s" % [game.mode_name.capitalize(), game.turn + 1, " (Dark)" if game.dark else ""]
	if game.is_mission:
		s = "%s %d: %s - turn %d of %d%s\n%s" % [campaign_pack.get("title", "Mission"), campaign_mission.get("id", 0), campaign_mission.get("title", ""), game.turn + 1, campaign_mission.get("turns", 8), " (Dark)" if game.dark else "", "  |  ".join(game.objective_lines())]
	elif game.turn == 0:
		s += "\n" + MODE_TEXT.get(game.mode_name, "")
	if phase == "plan":
		s += "  |  Planning: %s" % _team_name(plan_team)
	elif phase == "replay":
		s += "  |  " + ("Test preview" if board.rtest else "Replay")
	side_label.text = s
	unit_label.text = board.unit_info().replace("\n", "  |  ") if phase == "plan" else ""
	turn_label.text = "TURN %d" % (game.turn + 1)
	weapon_label.text = board.selected_weapon_name() if phase == "plan" else ""

func _on_test() -> void:
	if phase != "plan":
		return
	var sim = game.fog_clone(plan_team)
	for u in sim.units:
		sim.set_orders(u.id, {})
	for id in board.orders.keys():
		if sim.unit(id) != null:
			sim.set_orders(id, board.orders[id])
	for id in board.test_orders.keys():
		var u = sim.unit(id)
		if u != null and u.alive:
			sim.set_orders(id, board.test_orders[id])
	var before = sim.map.duplicate_map()
	sim.run_turn()
	_start_replay(sim.frames, sim.events, before, plan_team, true, false)
	phase = "replay"
	_show_phase("replay")

func _on_restart() -> void:
	if game == null:
		return
	if campaign_mode:
		_start_mission(campaign_mission)
	else:
		_on_start()

func _on_watch_last() -> void:
	if last_replay.is_empty() or phase != "plan":
		return
	_start_replay(last_replay["frames"], last_replay["events"], last_replay["map"], plan_team, true, not vs_ai)
	phase = "replay"
	_show_phase("replay")

func _start_replay(frames, events, map_before, team, is_test, show_all) -> void:
	board.start_replay(frames, events, map_before, team, is_test, show_all)
	timeline.max_value = board.replay_length()

func _on_commit() -> void:
	if phase != "plan":
		return
	committed[plan_team] = board.orders.duplicate(true)
	if vs_ai:
		var sd: int = int(seed_spin.value) + (campaign_mission.get("seed", 0) if campaign_mode else 0)
		committed[1] = AI.plan(game, 1, sd)
		if campaign_mode:
			var ally_ids: Array = []
			for u in game.sim.units:
				if u.alive and u.team == 0 and (u.tag == "ally" or u.tag == "leaver"):
					ally_ids.append(u.id)
			if not ally_ids.is_empty():
				committed[0].merge(AI.plan(game, 0, sd, 6, ally_ids))
		_run_turn()
	elif plan_team == 0:
		_pass_to(1)
	else:
		_run_turn()

func _run_turn() -> void:
	var pending := {}
	for t in committed.keys():
		game.submit_orders(t, committed[t], true)
		pending.merge(committed[t])
	var before = game.sim.map.duplicate_map()
	game.play_turn(pending)
	last_replay = {"frames": game.sim.frames.duplicate(), "events": game.sim.events.duplicate(), "map": before}
	_start_replay(game.sim.frames, game.sim.events, before, 0, false, not vs_ai)
	phase = "replay"
	_show_phase("replay")

func _on_replay_finished(was_test: bool) -> void:
	if was_test:
		phase = "plan"
		_show_phase("plan")
		board.phase = "plan"
		board.queue_redraw()
		return
	if game.over:
		_show_end()
	else:
		_begin_turn()

func _show_end() -> void:
	phase = "over"
	if campaign_mode:
		var won: bool = game.winner == 0
		if won:
			CampaignData.mark_done(progress, campaign_pack["id"], campaign_mission["id"])
			CampaignData.save_progress(progress)
		var nxt := "Mission complete — %s." % game.reason if won else "Mission failed — %s." % game.reason
		_show_overlay(nxt, "Back to missions", func(): _open_campaign(), "Retry" if not won else "", func(): _start_mission(campaign_mission))
		return
	var txt := "Draw — %s" % game.reason
	if game.winner >= 0:
		txt = "%s wins — %s" % [_team_name(game.winner), game.reason]
	_show_overlay(txt, "Main menu", func(): _show_phase("menu"))

func _toggle_pause() -> void:
	board.rpaused = not board.rpaused
	pause_btn.text = "Resume  (Space)" if board.rpaused else "Pause  (Space)"

func _process(d: float) -> void:
	if topbar != null:
		var want := bar_pinned
		if (phase == "plan" or phase == "replay") and not overlay.visible and not ctx.visible:
			var my: float = get_viewport().get_mouse_position().y
			var inside: bool = get_viewport().get_visible_rect().has_point(get_viewport().get_mouse_position())
			if inside and (my <= 6.0 or (topbar.visible and my <= topbar.size.y + 12.0)):
				want = true
		if want:
			_bar_timer = 0.5
		else:
			_bar_timer -= d
		topbar.visible = (phase == "plan" or phase == "replay") and not overlay.visible and (want or _bar_timer > 0.0)
		if topbar.visible:
			help_label.visible = false
	if phase == "replay" and timeline != null:
		_updating_slider = true
		timeline.value = board.rt
		_updating_slider = false

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if phase == "plan":
		match event.keycode:
			KEY_A: board.set_tool("aim")
			KEY_F: board.set_tool("fire")
			KEY_I: board.set_tool("ignore")
			KEY_K: board.set_tool("check")
			KEY_O: board.set_tool("focus")
			KEY_C: board.toggle_cos()
			KEY_D: board.toggle_duck()
			KEY_W: board.cycle_wait()
			KEY_TAB: board.select_next()
			KEY_BACKSPACE: board.remove_last_waypoint()
			KEY_DELETE: board.clear_orders()
			KEY_SPACE: _on_test()
			KEY_ENTER, KEY_KP_ENTER: _on_commit()
			KEY_ESCAPE: board.set_tool("path")
	elif phase == "replay":
		match event.keycode:
			KEY_SPACE: _toggle_pause()
			KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE: board.end_replay()
			KEY_EQUAL, KEY_KP_ADD: board.rspeed = minf(board.rspeed * 2.0, 8.0)
			KEY_MINUS, KEY_KP_SUBTRACT: board.rspeed = maxf(board.rspeed / 2.0, 0.25)
