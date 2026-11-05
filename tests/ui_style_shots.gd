extends SceneTree
## Look-and-feel captures: neon board, hidden orders bar (shown on top-edge hover), context menu.
## Run: xvfb-run -a godot --rendering-driver opengl3 --path . -s tests/ui_style_shots.gd -- <outdir>
var out_dir := "/tmp"
var main
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	root.size = Vector2i(1280, 720)
	main = load("res://ui/main.tscn").instantiate()
	root.add_child(main)
	await _shot("s1_menu")
	main.opp_opt.select(0)
	main.mode_opt.select(0)
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
		var tx: int = u.x + 5000 + 1500 * k
		var ty: int = u.y + (2000 if k % 2 == 0 else -2000)
		if main.game.sim.map.walkable(tx, ty):
			b.add_waypoint(u.id, tx, ty)
		var f = foes[k % foes.size()]
		var kind: String = main.game.sim.unit(u.id).type
		if kind == "rocket" or kind == "grenade":
			b.set_fire(u.id, f.x, f.y)
		else:
			b.set_aim(u.id, f.x, f.y)
		k += 1
	b.selected = mine[0].id
	main._refresh_side()
	await _shot("s2_plan_clean")
	main.bar_pinned = true
	await _shot("s3_plan_topbar")
	main.bar_pinned = false
	main._bar_timer = 0.0
	main._on_context(Vector2(560, 330), Vector2i(12000, 8000), -1)
	await _shot("s4_context_menu")
	main.ctx.hide()
	main._on_test()
	for i in range(8):
		await process_frame
	b.rpaused = true
	var tick := 50
	for e in b.revents:
		if e["type"] == "explosion":
			tick = e["tick"]
			break
	b.rt = float(tick) / 20.0 + 0.2
	await _shot("s5_explosion")
	b.rt = float(tick) / 20.0 + 0.7
	await _shot("s6_explosion_late")
	main.bar_pinned = true
	await _shot("s7_replay_bar")
	quit()
func _shot(name: String) -> void:
	for i in range(5):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out_dir, name])
	print("saved ", name)
