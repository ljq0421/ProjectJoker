extends SceneTree

var failures: Array[String] = []
var screen: SingleEncounterScreen
var pointer_position := Vector2.ZERO

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var config_path := OS.get_temp_dir().path_join(
		"project-joker-tutorial-input-%d.cfg" % Time.get_ticks_usec()
	)
	DirAccess.remove_absolute(config_path)
	screen = load("res://scenes/run/single_encounter_screen.tscn").instantiate()
	screen.tutorial_config_path = config_path
	root.add_child(screen)
	await process_frame
	await process_frame
	await process_frame

	var tutorial: SingleEncounterTutorial = screen.get_node("%SingleEncounterTutorial")
	_assert_true(tutorial.active and tutorial.flow.step_index == 0, "fresh config should auto-start")

	await _click(_find_die(&"d6"))
	_assert_true(
		screen.session.selection.kind == InteractionState.Kind.NONE,
		"welcome should block unrelated gameplay"
	)
	await _click(tutorial.get_node("%TutorialSkipButton"))
	_assert_true(not tutorial.active, "skip should close onboarding")
	_assert_true(TutorialProgressStore.new(config_path).is_done(), "skip should persist done")

	await _click(screen.get_node("%ReplayTutorialButton"))
	_assert_true(tutorial.active and tutorial.flow.step_index == 0, "replay should restart")
	_assert_true(
		screen.session.controller.state.assignments.is_empty(),
		"replay should reset teaching encounter"
	)
	await _click(tutorial.get_node("%TutorialContinueButton"))

	await _drag(_find_die(&"d1"), screen.get_node("%LeftLane"))
	_assert_true(tutorial.flow.step_index == 2, "drag lesson should advance")

	await _click(_find_die(&"d6"))
	await _click_lane(screen.get_node("%LeftLane"))
	_assert_true(tutorial.flow.step_index == 3, "click assignment lesson should advance")

	for die_id in [&"d2", &"d3", &"d4"]:
		await _click(_find_die(die_id))
		await _click_lane(screen.get_node("%MiddleLane"))
	_assert_true(tutorial.flow.step_index == 4, "middle lane lesson should advance")

	await _click(_find_die(&"d5"))
	await _click(screen.get_node("%MinusButton"))
	await _click(_find_die(&"d5"))
	await _click_lane(screen.get_node("%RightLane"))
	_assert_true(tutorial.flow.step_index == 5, "calibration lesson should advance")
	_assert_true(screen.session.preview().total == 44, "base tutorial state should be 44")

	await _click(_find_card(1))
	await _click_lane(screen.get_node("%LeftLane"))
	_assert_true(tutorial.flow.step_index == 6, "card lesson should advance")
	_assert_true(screen.session.preview().total == 51, "card lesson should reach 51")
	await _click(tutorial.get_node("%TutorialContinueButton"))

	await _click(screen.get_node("%UndoButton"))
	_assert_true(tutorial.flow.step_index == 8, "undo lesson should advance")
	_assert_true(screen.session.preview().total == 44, "undo should restore 44")

	await _click(_find_card(1))
	await _click_lane(screen.get_node("%LeftLane"))
	_assert_true(tutorial.flow.step_index == 9, "reapply lesson should advance")
	await _click(screen.get_node("%ConfirmButton"))
	_assert_true(tutorial.flow.step_index == 10, "commit should reach completion")
	_assert_true(screen.session.commit().total == 51, "tutorial commit should remain 51")

	await _click(tutorial.get_node("%TutorialFinishButton"))
	_assert_true(not tutorial.active, "finish should close onboarding")
	_assert_true(TutorialProgressStore.new(config_path).is_done(), "finish should persist done")

	screen.queue_free()
	await process_frame
	DirAccess.remove_absolute(config_path)
	if failures.is_empty():
		print("PASS tutorial_input_self_check")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _find_die(id: StringName) -> DieToken:
	for node in screen.find_children("*", "Button", true, false):
		if node is DieToken and not node.is_queued_for_deletion() and node.die_id == id:
			return node
	return null

func _find_card(index: int) -> CardToken:
	for node in screen.find_children("*", "Button", true, false):
		if node is CardToken and not node.is_queued_for_deletion() and node.card_index == index:
			return node
	return null

func _click(control: Control) -> void:
	_assert_true(control != null, "click target should exist")
	if control == null:
		return
	await _click_at_point(control.get_global_rect().get_center())

func _click_lane(lane: Control) -> void:
	await _click_at_point(lane.get_global_rect().position + Vector2(18, 18))

func _click_at_point(point: Vector2) -> void:
	await _move_pointer(point)
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

func _drag(source: Control, target: Control) -> void:
	await _drag_to_point(source, target.get_global_rect().get_center())

func _drag_to_point(source: Control, finish: Vector2) -> void:
	_assert_true(source != null, "drag source should exist")
	if source == null:
		return
	var start := source.get_global_rect().get_center()
	await _move_pointer(start)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = start
	root.push_input(press, true)
	await process_frame
	for index in range(1, 7):
		var motion := InputEventMouseMotion.new()
		motion.position = start.lerp(finish, float(index) / 6.0)
		motion.relative = motion.position - pointer_position
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		root.push_input(motion, true)
		pointer_position = motion.position
		await process_frame
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = finish
	root.push_input(release, true)
	await process_frame
	await process_frame

func _move_pointer(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.relative = point - pointer_position
	root.push_input(motion, true)
	pointer_position = point
	await process_frame

func _assert_true(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
