extends SceneTree
## Renders the real UI under a virtual display and saves screenshots.
## Run: xvfb-run -a godot --rendering-driver opengl3 --path . -s tests/ui_smoke.gd -- <outdir>

var out_dir := "/tmp"

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	root.size = Vector2i(1280, 720)
	var main = load("res://ui/main.tscn").instantiate()
	root.add_child(main)
	await _shot("1_menu")
	main.mode_opt.select(0)
	main.dark_chk.button_pressed = false
	main.seed_spin.value = 3
	main._on_start()
	await _shot("2_plan_empty")
	# give orders to the first two friendly units
	var b = main.board
	var mine: Array = []
	for u in main.game.sim.units:
		if u.team == 0:
			mine.append(u)
	b.selected = mine[0].id
	b.add_waypoint(mine[0].id, 12500, 9500)
	b.set_aim(mine[0].id, 20500, 9500)
	b.selected = mine[1].id
	b.add_waypoint(mine[1].id, 10500, 5500)
	b.toggle_duck()
	main._refresh_side()
	await _shot("3_plan_orders")
	main._on_test()
	for i in range(30):
		await process_frame
	b.rt = 2.5
	b.rpaused = true
	await _shot("4_test_preview")
	b.end_replay()
	main._on_commit()
	await process_frame
	b.rt = 4.0
	b.rpaused = true
	await _shot("5_replay")
	b.end_replay()
	await process_frame
	print("phase after replay: ", main.phase, " turn ", main.game.turn)
	# dark mode
	main._show_phase("menu")
	main.dark_chk.button_pressed = true
	main.mode_opt.select(2)
	main._on_start()
	await _shot("6_dark_disputed")
	quit()

func _shot(name: String) -> void:
	for i in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png("%s/%s.png" % [out_dir, name])
	print("saved ", name, " ", img.get_size())
