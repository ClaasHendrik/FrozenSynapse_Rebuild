extends SceneTree
## Captures figures in action: planning icons, firefight, deaths. 
## Run: xvfb-run -a godot --rendering-driver opengl3 --path . -s tests/ui_figure_shots.gd -- <outdir>
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
	main.opp_opt.select(0)
	main.mode_opt.select(0)
	main.seed_spin.value = 12
	main._on_start()
	var b = main.board
	var mine: Array = []
	for u in main.game.sim.units:
		if u.team == 0:
			mine.append(u)
	# rush everybody to the middle so a fight happens
	var k := 0
	for u in mine:
		b.selected = u.id
		var tx: int = main.game.sim.map.w * 500 + (k - 2) * 1500
		var ty: int = main.game.sim.map.h * 500 + (k % 3 - 1) * 2500
		if main.game.sim.map.walkable(tx, ty):
			b.add_waypoint(u.id, tx, ty)
		if k == 1:
			b.toggle_duck()
		if k == 2:
			b.cycle_wait()
		k += 1
	b.selected = mine[0].id
	main._refresh_side()
	await _shot("f1_plan_icons")
	main._on_commit()
	for i in range(6):
		await process_frame
	b.rpaused = true
	var first_shot := 40
	var first_kill := -1
	for e in b.revents:
		if e["type"] == "shot" and first_shot == 40:
			first_shot = e["tick"]
		if e["type"] == "kill" and first_kill < 0:
			first_kill = e["tick"]
	print("first shot ", first_shot, " first kill ", first_kill, " events ", b.revents.size())
	b.rt = 1.0
	await _shot("f2_moving")
	b.rt = float(first_shot) / 20.0 + 0.05
	await _shot("f3_firefight")
	if first_kill >= 0:
		b.rt = float(first_kill) / 20.0 + 0.1
		await _shot("f4_kill")
		b.rt = float(first_kill) / 20.0 + 0.5
		await _shot("f5_after_kill")
	b.rt = b.replay_length()
	await _shot("f6_end_of_turn")
	b.end_replay()
	for i in range(5):
		await process_frame
	await _shot("f7_next_plan_corpses")
	quit()
func _shot(name: String) -> void:
	for i in range(5):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out_dir, name])
	print("saved ", name)
