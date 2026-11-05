extends Control
## Menus, turn flow (vs AI / hotseat), side panel and overlays.

const Match = preload("res://sim/match.gd")
const AI = preload("res://sim/ai.gd")
const Board = preload("res://ui/board.gd")
const Balance = preload("res://sim/balance.gd")

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

# widgets
var menu_box: Control
var game_box: Control
var side_label: Label
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
	_build_menu()
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
	return b

func _build_menu() -> void:
	var bg := ColorRect.new()
	bg.color = Color("070b16")
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
	v.add_child(_button("Start", _on_start))
	v.add_child(_button("Quit", func(): get_tree().quit()))

func _build_game() -> void:
	game_box = HBoxContainer.new()
	game_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(game_box)
	board = Board.new()
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	game_box.add_child(board)
	board.orders_changed.connect(_refresh_side)
	board.selection_changed.connect(_refresh_side)
	board.replay_finished.connect(_on_replay_finished)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(250, 0)
	game_box.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)
	side_label = _label("", 15)
	side_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(side_label)
	unit_label = _label("", 14)
	v.add_child(unit_label)
	plan_buttons = VBoxContainer.new()
	v.add_child(plan_buttons)
	for spec in [
		["Aim  (A)", func(): board.set_tool("aim")],
		["Duck / stand  (D)", func(): board.toggle_duck()],
		["Wait at last point  (W)", func(): board.cycle_wait()],
		["Fire at point  (F)", func(): board.set_tool("fire")],
		["Ignore enemy  (I)", func(): board.set_tool("ignore")],
		["Continue on sight  (C)", func(): board.toggle_cos()],
		["Undo last  (Backspace)", func(): board.remove_last_waypoint()],
		["Clear unit orders  (Del)", func(): board.clear_orders()],
		["Next unit  (Tab)", func(): board.select_next()],
		["Test preview  (Space)", _on_test],
		["Commit turn  (Enter)", _on_commit],
		["Watch last turn", _on_watch_last],
	]:
		plan_buttons.add_child(_button(spec[0], spec[1]))
	replay_buttons = VBoxContainer.new()
	v.add_child(replay_buttons)
	pause_btn = _button("Pause  (Space)", _toggle_pause)
	replay_buttons.add_child(pause_btn)
	replay_buttons.add_child(_button("Speed  (+/-)", func(): board.rspeed = 1.0 if board.rspeed >= 4.0 else board.rspeed * 2.0))
	replay_buttons.add_child(_button("Skip  (Enter)", func(): board.end_replay()))
	timeline = HSlider.new()
	timeline.min_value = 0.0
	timeline.max_value = 5.0
	timeline.step = 0.05
	timeline.focus_mode = Control.FOCUS_NONE
	timeline.value_changed.connect(func(val): if not _updating_slider: board.rt = val; board.rpaused = true; board.queue_redraw())
	replay_buttons.add_child(timeline)
	help_label = _label("Click a unit to select. Click the map to add waypoints (paths avoid walls). Right-click removes the last waypoint.", 12)
	help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(help_label)
	v.add_child(_button("Menu", func(): _show_phase("menu")))

func _build_overlay() -> void:
	overlay = ColorRect.new()
	overlay.color = Color(0.03, 0.05, 0.1, 0.97)
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
	overlay.visible = false

func _show_overlay(text: String, button: String, action: Callable) -> void:
	overlay_label.text = text
	overlay_btn.text = button
	overlay_action = action
	overlay.visible = true

# ------------------------------------------------------------------ flow

func _show_phase(p: String) -> void:
	phase = p
	menu_box.get_parent().get_child(0).visible = (p == "menu")  # backdrop
	menu_box.visible = (p == "menu")
	game_box.visible = (p != "menu")
	if p == "menu":
		overlay.visible = false
	plan_buttons.visible = (p == "plan")
	replay_buttons.visible = (p == "replay")
	_refresh_side()

func _on_start() -> void:
	vs_ai = opp_opt.selected == 0
	var opts := {"squad": int(squad_spin.value)}
	var mode: String = MODES[mode_opt.selected]
	if mode == "charge":
		opts["bid0"] = 14
		opts["bid1"] = 12
	game = Match.create(mode, int(seed_spin.value), dark_chk.button_pressed, opts)
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
	var s := "%s\nTurn %d — %s%s\n\n%s\n" % [
		game.mode_name.capitalize(), game.turn + 1,
		"Dark" if game.dark else "Light", "" if not game.over else " (over)",
		MODE_TEXT[game.mode_name]]
	if phase == "plan":
		s += "\nPlanning: %s" % _team_name(plan_team)
	elif phase == "replay":
		s += "\n" + ("Test preview" if board.rtest else "Replay")
	side_label.text = s
	unit_label.text = board.unit_info() if phase == "plan" else ""

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
		committed[1] = AI.plan(game, 1, int(seed_spin.value))
		_run_turn()
	elif plan_team == 0:
		_pass_to(1)
	else:
		_run_turn()

func _run_turn() -> void:
	var pending := {}
	for t in committed.keys():
		game.submit_orders(t, committed[t])
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
	var txt := "Draw — %s" % game.reason
	if game.winner >= 0:
		txt = "%s wins — %s" % [_team_name(game.winner), game.reason]
	_show_overlay(txt, "Main menu", func(): _show_phase("menu"))

func _toggle_pause() -> void:
	board.rpaused = not board.rpaused
	pause_btn.text = "Resume  (Space)" if board.rpaused else "Pause  (Space)"

func _process(_d: float) -> void:
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
