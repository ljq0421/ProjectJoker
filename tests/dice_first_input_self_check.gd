extends SceneTree

const MAIN_SCENE := preload("res://scenes/run/main_menu_screen.tscn")
var failures: Array[String] = []
var screen: DiceFirstPrototypeScreen
var pointer_position := Vector2.ZERO

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	root.set_meta("dice_first_seed", 8042026)
	root.set_meta("dice_first_rule_id", &"echo")
	var menu: MainMenuScreen = MAIN_SCENE.instantiate()
	menu.demo_scope_override = 0
	root.add_child(menu)
	await _settle(2)
	await _click(menu.get_node("%DiceFirstPrototypeButton"))
	await _settle(4)
	screen = current_scene as DiceFirstPrototypeScreen
	_assert_true(screen != null, "main-menu click should open prototype")
	if screen == null: return _finish()

	await _click(screen.get_node("%RollButton"))
	_assert_true(screen.controller.state.dice.size() == 6, "roll should produce six dice")
	_assert_true(screen.get_node("%BoardColumn").visible, "reroll decision should appear with initial result")
	_assert_true(screen.controller.preview().combo_candidates.size() >= 2, "fixture should expose both initial pairs")
	await _click(_die_button(&"d1"))
	_assert_true(screen.controller.state.selected_reroll_die_ids == [&"d1"], "a die should be directly selectable")
	_assert_true("不动：一对 3" in screen.get_node("%SelectionSummaryLabel").text, "selection should explain which initial combination remains")
	_assert_true("会拆散：一对 5" in screen.get_node("%SelectionSummaryLabel").text, "selection should explain which initial combination is broken")
	_assert_true("−2分 / −1能量" in screen.get_node("%RerollButton").text, "reroll should publish exact cost")
	await _click(screen.get_node("%RerollButton"))
	_assert_true(screen.controller.state.phase == DiceFirstState.Phase.BUILD, "reroll should enter deterministic build")

	await _click(screen.get_node("%UpInstruction"))
	await _click(_die_button(&"d5"))
	var upgraded = screen.controller.preview()
	_assert_true(upgraded.upgraded, "point +1 should upgrade the untouched initial pair into three equal dice")
	_assert_true(upgraded.upgrade_energy == 1, "upgrade should grant one energy")
	_assert_true(upgraded.breakthrough_available, "triplet upgrade minus reroll should charge break")
	for die_id in [&"d1", &"d2", &"d3"]:
		await _click(_die_button(die_id))
		await _click(screen.get_node("%LeftTableButton"))
	for die_id in [&"d4", &"d5", &"d6"]:
		await _click(_die_button(die_id))
		await _click(screen.get_node("%RightTableButton"))
	var table_ready = screen.controller.preview()
	_assert_true(table_ready.table_allocation_complete, "real pointer path should fill both rule tables")
	_assert_true(table_ready.table_matches.size() == 1 and table_ready.table_score == 3, "splitting the threes should trigger the public cross-table echo")
	_assert_true("+3分" in screen.get_node("%CrossTableEchoLabel").text, "UI should explain the spatial rule result")

	await _click(screen.get_node("%BreakthroughButton"))
	_assert_true(screen.controller.state.breakthrough_requested, "first break click should add preview")
	await _click(screen.get_node("%BreakthroughButton"))
	_assert_true(not screen.controller.state.breakthrough_requested, "second break click should undo")
	await _click(screen.get_node("%BreakthroughButton"))
	var final_preview = screen.controller.preview()
	await _click(screen.get_node("%CommitButton"))
	var committed = screen.controller.commit()
	_assert_true(committed != null, "commit should create report")
	_assert_true(committed.event_signature() == final_preview.event_signature(), "preview and commit should share resolver")
	_assert_true(committed.breakthrough_applied, "commit should contain selected break")
	_assert_true(screen.get_node("%BreakthroughOverlay").visible, "break should show climax")
	await create_timer(1.8).timeout
	await _click(screen.get_node("%RestartButton"))
	_assert_true(screen.controller.state.phase == DiceFirstState.Phase.AWAITING_ROLL, "restart should reset encounter")
	_finish()

func _die_button(die_id: StringName) -> Button:
	for child in screen.get_node("%DiceTray").get_children():
		if StringName(child.get("die_id")) == die_id: return child as Button
	return null

func _click(control: Control) -> void:
	_assert_true(control != null, "real pointer target should exist")
	if control == null: return
	var point := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.relative = point - pointer_position
	root.push_input(motion, true)
	pointer_position = point
	await process_frame
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = point
	root.push_input(press, true)
	await process_frame
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = point
	root.push_input(release, true)
	await process_frame

func _settle(frames: int) -> void:
	for _index in range(frames): await process_frame

func _assert_true(value: bool, message: String) -> void:
	if not value: failures.append(message)

func _finish() -> void:
	root.remove_meta("dice_first_seed")
	root.remove_meta("dice_first_rule_id")
	if failures.is_empty():
		print("DICE_FIRST_INPUT_SELF_CHECK: PASS")
		quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)
