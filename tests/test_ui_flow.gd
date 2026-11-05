extends SceneTree
## Scripted UI flow test (vs AI and hotseat). Run: godot --headless --path . -s tests/test_ui_flow.gd

var passed := 0
var failed := 0

func check(cond: bool, name: String) -> void:
	if cond:
		passed += 1
		print("  ok   ", name)
	else:
		failed += 1
		print("  FAIL ", name)

func wait_for(main, cond: Callable, max_frames: int = 900) -> bool:
	for i in range(max_frames):
		if cond.call():
			return true
		await process_frame
	return cond.call()

func _init() -> void:
	root.size = Vector2i(1280, 720)
	var main = load("res://ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	print("versus computer")
	main.opp_opt.select(0)
	main.seed_spin.value = 4
	main._on_start()
	check(main.phase == "plan" and main.plan_team == 0, "game starts in the plan phase for player 1")
	var b = main.board
	var mine = []
	for u in main.game.sim.units:
		if u.team == 0:
			mine.append(u)
	b.selected = mine[0].id
	b.add_waypoint(mine[0].id, mine[0].x + 3000, mine[0].y)
	check(b.orders[mine[0].id]["path"].size() >= 1, "click adds a waypoint")
	b.remove_last_waypoint()
	check(b.orders[mine[0].id]["path"].is_empty(), "undo removes it")
	b.add_waypoint(mine[0].id, mine[0].x + 3000, mine[0].y)
	b.toggle_duck()
	b.cycle_wait()
	main._on_test()
	check(main.phase == "replay" and b.rtest, "Test preview starts a replay")
	var tick_before: int = main.game.turn
	b.rspeed = 8.0
	var ok: bool = await wait_for(main, func(): return main.phase == "plan")
	check(ok, "test preview ends and returns to planning")
	check(main.game.turn == tick_before, "test preview does not advance the real game")
	check(b.orders[mine[0].id]["path"].size() >= 1, "orders survive the preview")
	main._on_commit()
	check(main.phase == "replay" and not b.rtest, "commit runs the real turn")
	b.rspeed = 8.0
	ok = await wait_for(main, func(): return main.phase == "plan" or main.phase == "over")
	check(ok and main.game.turn == 1, "next turn begins after the replay")
	check(not main.last_replay.is_empty(), "last turn is stored for rewatching")

	print("hotseat")
	main._show_phase("menu")
	main.opp_opt.select(1)
	main.dark_chk.button_pressed = true
	main.mode_opt.select(1)
	main._on_start()
	check(main.phase == "pass" and main.overlay.visible, "hotseat starts with a pass-the-device screen")
	main.overlay_btn.pressed.emit()
	check(main.phase == "plan" and main.plan_team == 0 and not main.overlay.visible, "player 1 plans after Ready")
	main._on_commit()
	check(main.phase == "pass" and main.committed.has(0) and not main.committed.has(1), "player 1 commit hands over to player 2")
	check(main.game.turn == 0, "turn does not run until both players commit")
	main.overlay_btn.pressed.emit()
	check(main.phase == "plan" and main.plan_team == 1, "player 2 plans")
	# player 2 must not see player 1's orders in a Test preview
	main._on_test()
	check(main.phase == "replay", "player 2 can test")
	b.rspeed = 8.0
	await wait_for(main, func(): return main.phase == "plan")
	main._on_commit()
	check(main.phase == "replay" and not b.rtest, "both committed: real turn replay")
	b.rspeed = 8.0
	ok = await wait_for(main, func(): return main.phase == "pass" or main.phase == "over")
	check(ok and main.game.turn == 1, "after replay the device passes back to player 1")
	print("\n%d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)
