extends SceneTree
## Captures the screens used in the overview PDF.
## Run: xvfb-run -a godot --rendering-driver opengl3 --path . -s tests/ui_overview_shots.gd -- <outdir>

const CampaignData = preload("res://campaign/campaign_data.gd")
var out_dir := "/tmp"
var main

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	root.size = Vector2i(1280, 720)
	main = load("res://ui/main.tscn").instantiate()
	root.add_child(main)
	await _shot("01_menu")

	# --- skirmish, Light extermination, with orders
	main.opp_opt.select(0)
	main.mode_opt.select(0)
	main.dark_chk.button_pressed = false
	main.seed_spin.value = 3
	main._on_start()
	var b = main.board
	var mine: Array = []
	var foes: Array = []
	for u in main.game.sim.units:
		(mine if u.team == 0 else foes).append(u)
	var k := 0
	for u in mine:
		b.selected = u.id
		var tx: int = u.x + (5000 + 1500 * k)
		var ty: int = u.y + (2000 if k % 2 == 0 else -2000)
		if main.game.sim.map.walkable(tx, ty):
			b.add_waypoint(u.id, tx, ty)
		var f = foes[k % foes.size()]
		var kind: String = main.game.sim.unit(u.id).type
		if kind == "rocket" or kind == "grenade":
			b.set_fire(u.id, f.x, f.y)
		else:
			b.set_aim(u.id, f.x, f.y)
			if k == 1:
				b.toggle_duck()
			if k == 2:
				b.cycle_wait()
		k += 1
	b.selected = mine[0].id
	main._refresh_side()
	await _shot("02_plan_orders")

	# --- Test preview
	main._on_test()
	for i in range(10):
		await process_frame
	b.rpaused = true
	var t_test := _first_tick(b.revents, "explosion", 60)
	b.rt = float(t_test) / 20.0 + 0.2
	await _shot("03_test_preview")
	b.end_replay()
	await process_frame

	# --- real turn replay
	main._on_commit()
	for i in range(5):
		await process_frame
	b.rpaused = true
	var t_boom := _first_tick(b.revents, "explosion", 50)
	b.rt = float(t_boom) / 20.0 + 0.25
	await _shot("04_replay_explosion")
	var t_kill := _first_tick(b.revents, "kill", 55)
	b.rt = float(t_kill) / 20.0 + 0.1
	await _shot("05_replay_kill")
	b.end_replay()
	await process_frame

	# --- dark disputed
	main._show_phase("menu")
	main.dark_chk.button_pressed = true
	main.mode_opt.select(2)
	main.seed_spin.value = 6
	main._on_start()
	await _shot("06_dark_disputed")

	# --- hotseat secure
	main._show_phase("menu")
	main.dark_chk.button_pressed = false
	main.opp_opt.select(1)
	main.mode_opt.select(1)
	main._on_start()
	await _shot("07_hotseat_pass")
	main.overlay_btn.pressed.emit()
	await _shot("08_secure_plan")
	main.opp_opt.select(0)

	# --- hostage and charge and upload quick looks
	for spec in [[3, "09_hostage"], [4, "10_charge"], [5, "11_upload"]]:
		main._show_phase("menu")
		main.mode_opt.select(spec[0])
		main.dark_chk.button_pressed = false
		main._on_start()
		await _shot(spec[1])

	# --- campaign screens
	main._show_phase("menu")
	main._open_campaign()
	await _shot("12_campaign_list")
	main._show_briefing(0, main.campaign_pack["chapters"][0]["missions"][0])
	await _shot("13_briefing")
	main.overlay.visible = false

	# --- missions
	var shots := [
		["main", 3, "20_m03_extraction"], ["main", 5, "21_m05_breach"], ["main", 9, "22_m09_broadcast"],
		["main", 15, "23_m15_shape_purge"], ["main", 32, "24_m32_hostage"], ["main", 45, "25_m45_protection"],
		["main", 52, "26_m52_corridor"], ["red", 4, "27_red_handshake"], ["red", 1, "28_red_shield_wall"],
		["bonus", 1, "29_bonus_lights_out"],
	]
	for s in shots:
		var pk := CampaignData.load_pack(s[0])
		main.campaign_pack = pk
		var m: Dictionary = pk["flat"][s[1] - 1]["mission"]
		main._start_mission(m)
		await _shot(s[2])
	quit()

func _first_tick(events: Array, type: String, fallback: int) -> int:
	for e in events:
		if e["type"] == type:
			return e["tick"]
	return fallback

func _shot(name: String) -> void:
	for i in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out_dir, name])
	print("saved ", name)
