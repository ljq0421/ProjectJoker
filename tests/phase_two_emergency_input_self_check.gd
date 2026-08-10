extends SceneTree

var failures: Array[String] = []
var screen: GoldCorridorRunScreen
var checkpoint_count := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.content_scale_size = Vector2i(1920, 1080)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.size = Vector2i(1920, 1080)
	screen = load(
		"res://scenes/run/gold_corridor_run_screen.tscn"
	).instantiate()
	screen.guide_auto_start = false
	screen._expedition_mode = true
	screen.configure(AreaCatalog.new().gold_corridor(), 20260810)
	screen.expedition_checkpoint_reached.connect(
		func(_snapshot: Dictionary) -> void: checkpoint_count += 1
	)
	root.add_child(screen)
	current_scene = screen
	await _settle()
	screen.get_node("%GoldCorridorGuideOverlay").close_card()
	var narrative := screen.get_node("%NarrativeCard")
	if narrative.is_open():
		await _click(narrative.get_node("%NarrativeContinueButton"))
		await _settle()
	screen.area_session.intel_tickets = 10
	await _click(screen.get_node("%RouteChoicePanel").get_node("%LeftRouteButton"))
	await _settle()

	var encounter: SingleEncounterScreen = screen.get_node("%EncounterScreen")
	var die_token := _find_die_token(&"d1")
	await _click(die_token)
	await _settle()
	_assert_false(
		encounter.get_node("%PaidRerollButton").disabled,
		"selecting an unlocked die should enable paid reroll"
	)
	var checkpoints_before := checkpoint_count
	var paid_round := screen.area_session.encounter_session.current_round
	await _click(encounter.get_node("%PaidRerollButton"))
	await _settle()
	_assert_equal(screen.area_session.intel_tickets, 9, "paid reroll should spend one intel")
	_assert_true(
		screen.area_session.encounter_session.paid_reroll_rounds.has(paid_round),
		"paid reroll should record the current round"
	)
	_assert_true(
		encounter.get_node("%PaidRerollButton").disabled,
		"paid reroll should disable after one use"
	)

	var calibration_before := encounter.session.controller.state.calibration_points
	await _click(encounter.get_node("%PaidCalibrationButton"))
	await _settle()
	_assert_equal(screen.area_session.intel_tickets, 7, "paid calibration should spend two intel")
	_assert_equal(
		encounter.session.controller.state.calibration_points,
		calibration_before + 1,
		"paid calibration should add one point"
	)

	await _click(encounter.get_node("%PaidRetryButton"))
	await _settle()
	var retry_dialog: ConfirmationDialog = encounter.get_node(
		"%PaidRetryConfirmationDialog"
	)
	_assert_true(retry_dialog.visible, "paid retry should require confirmation")
	await _click(retry_dialog.get_ok_button())
	await _settle()
	_assert_equal(screen.area_session.intel_tickets, 4, "paid retry should spend three intel")
	_assert_true(screen.area_session.area_retry_used, "paid retry should be used for the area")
	_assert_true(
		checkpoint_count >= checkpoints_before + 3,
		"each successful paid emergency should immediately emit a checkpoint"
	)
	await _finish()

func _find_die_token(die_id: StringName) -> DieToken:
	for node in screen.find_children("*", "Button", true, false):
		if node is DieToken and node.die_id == die_id and not node.is_queued_for_deletion():
			return node
	return null

func _click(control: Control) -> void:
	_assert_true(control != null, "click target should exist")
	if control == null:
		return
	var viewport := control.get_viewport()
	var point := control.get_global_rect().get_center()
	if viewport is Window and viewport != root:
		point += Vector2((viewport as Window).position)
		viewport = root
	var motion := InputEventMouseMotion.new()
	motion.position = point
	viewport.push_input(motion, true)
	await process_frame
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = point
	viewport.push_input(press, true)
	await process_frame
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = point
	viewport.push_input(release, true)
	await process_frame

func _settle() -> void:
	await process_frame
	await process_frame
	await process_frame

func _assert_true(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func _assert_false(value: bool, message: String) -> void:
	if value:
		failures.append(message)

func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		failures.append("%s; expected=%s actual=%s" % [message, expected, actual])

func _finish() -> void:
	if screen != null:
		screen.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS phase_two_emergency_input_self_check")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
