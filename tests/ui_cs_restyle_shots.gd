extends SceneTree
## Screenshots of the restyled game: briefing, planning in Dark mode with orders, context menu, NEXT TURN flash.
## Run: xvfb-run -a godot --rendering-driver opengl3 --path . -s tests/ui_cs_restyle_shots.gd -- <outdir>
var out_dir := "/tmp"
var main
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	root.size = Vector2i(1280, 720)
	main = load("res://ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main._open_campaign()
	await process_frame
	main._show_briefing(4, main.campaign_pack["chapters"][4]["missions"][0])
	await _shot("r1_briefing")
	main.briefing.queue_free()
	main.briefing = null
	# Dark mode game with check/focus orders and a last-seen marker
	main._show_phase("menu")
	main.opp_opt.select(0)
	main.mode_opt.select(0)
	main.dark_chk.button_pressed = true
	main.seed_spin.value = 9
	main._on_start()
	var b = main.board
	var mine: Array = []
	for u in main.game.sim.units:
		if u.team == 0:
			mine.append(u)
	for k in range(mine.size()):
		var u = mine[k]
		b.selected = u.id
		b.add_waypoint(u.id, u.x + 4500 + k * 800, u.y + (1500 if k % 2 == 0 else -1500))
		if k == 0:
			b.set_check(u.id, u.x + 5000, u.y + 4000)
			b.cycle_wait()
		if k == 1:
			b.toggle_duck()
	b.selected = mine[0].id
	main._refresh_side()
	await _shot("r2_dark_plan")
	main._on_commit()
	for i in range(5):
		await process_frame
	b.rspeed = 8.0
	for i in range(400):
		await process_frame
		if main.phase == "plan":
			break
	b.flash_t = 1.2
	await _shot("r3_next_turn_flash")
	b.flash_t = 0.0
	main.bar_pinned = true
	await _shot("r4_orders_bar")
	main.bar_pinned = false
	main._bar_timer = 0.0
	var foe = null
	for u in main.game.sim.units:
		if u.team == 1 and u.alive:
			foe = u
	main._on_context(Vector2(700, 300), Vector2i(12000, 8000), foe.id if foe != null else -1)
	await _shot("r5_context_menu")
	quit()
func _shot(name: String) -> void:
	for i in range(6):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out_dir, name])
	print("saved ", name)
