extends SceneTree
## Screenshots of the campaign UI. Run: xvfb-run -a godot --rendering-driver opengl3 --path . -s tests/ui_campaign_shots.gd -- <outdir>
var out_dir := "/tmp"
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	root.size = Vector2i(1280, 720)
	var main = load("res://ui/main.tscn").instantiate()
	root.add_child(main)
	await _shot("c1_menu")
	main._open_campaign()
	await _shot("c2_campaign")
	main._show_briefing(1, main.campaign_pack["chapters"][1]["missions"][1])
	await _shot("c3_briefing")
	main.overlay.visible = false
	main._start_mission(main.campaign_pack["chapters"][1]["missions"][1])
	await _shot("c4_mission_plan")
	quit()
func _shot(name: String) -> void:
	for i in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out_dir, name])
	print("saved ", name)
