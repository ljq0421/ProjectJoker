extends SceneTree

var failures: Array[String] = []
var screen: SingleEncounterScreen
var pointer_position := Vector2.ZERO

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	screen = load("res://scenes/run/single_encounter_screen.tscn").instantiate()
	screen.tutorial_auto_start = false
	root.add_child(screen)
	await process_frame
	await process_frame

	_assert_true(
		screen.get_node("%EntryGroups").visible,
		"standalone encounter should expose grouped practice and area entries"
	)
	var d1 := _find_die(&"d1")
	var left: Control = screen.get_node("%LeftLane")
	await _drag(d1, _find_slot(left, 0))
	_assert_true(
		screen.session.controller.state.assignments.get(&"left", [])
		== [&"d1", &""],
		"real drag should assign d1 to the chosen left slot"
	)

	var tray: Control = screen.get_node("%DiceTray")
	var tray_drop_point := tray.get_global_rect().position + Vector2(12.0, tray.size.y * 0.5)
	await _drag_to_point(_find_die(&"d1"), tray_drop_point)
	_assert_true(
		screen.session.controller.state.assigned_die_ids(&"left").is_empty(),
		"dropping an assigned die on the tray should unassign it"
	)
	await _click(screen.get_node("%UndoButton"))
	_assert_true(
		screen.session.controller.state.assigned_die_ids(&"left") == [&"d1"],
		"undo should restore a die returned to the tray"
	)

	await _click(_find_die(&"d6"))
	await _click_lane(left)
	_assert_true(
		screen.session.controller.state.assigned_die_ids(&"left")
		== [&"d1", &"d6"],
		"click fallback should assign d6 to left"
	)

	await _click(_find_die(&"d1"))
	await _click(_find_slot(left, 1))
	_assert_true(
		screen.session.controller.state.assignments.get(&"left", [])
		== [&"d6", &"d1"],
		"clicking an occupied slot with an assigned die selected should swap"
	)
	await _click(screen.get_node("%UndoButton"))
	_assert_true(
		screen.session.controller.state.assignments.get(&"left", [])
		== [&"d1", &"d6"],
		"one undo should reverse the whole slot swap"
	)

	await _click(_find_die(&"d2"))
	await _click_lane(left)
	_assert_true(
		screen.get_node("%ErrorLabel").text == "规则轨已经放满",
		"invalid target should show a concrete Chinese reason"
	)
	_assert_true(
		&"d2" not in screen.session.controller.state.assignments.get(&"left", []),
		"full lane must reject another die"
	)

	await _click(_find_card(0))
	_assert_true(
		_find_die(&"d2").self_modulate != Color.WHITE,
		"die cards should highlight dice"
	)
	_assert_true(
		screen.get_node("%LeftLane").self_modulate == Color.WHITE,
		"die cards should not highlight tables"
	)
	await _click(_find_card(2))
	_assert_true(
		screen.get_node("%LeftGap").self_modulate != Color.WHITE
		and screen.get_node("%LeftLane").self_modulate == Color.WHITE,
		"gap cards should highlight gaps without highlighting tables"
	)

	var table_card := _find_card(1)
	await _click(table_card)
	_assert_true(
		screen.get_node("%LeftLane").self_modulate != Color.WHITE,
		"selecting a table card should highlight legal table targets"
	)
	await _click_lane(left)
	_assert_true(screen.session.preview().total >= 21, "table card should affect preview")

	await _click(screen.get_node("%UndoButton"))
	_assert_true(not screen.session.is_card_used(1), "undo should restore the card")

	await _click(_find_die(&"d5"))
	await _click(screen.get_node("%MinusButton"))
	screen.session.activate_die(&"d2")
	screen.session.activate_table(&"middle")
	screen.session.activate_die(&"d3")
	screen.session.activate_table(&"middle")
	screen.session.activate_die(&"d4")
	screen.session.activate_table(&"middle")
	screen.session.activate_die(&"d5")
	screen.session.activate_table(&"right")
	screen.session.activate_card(1)
	screen.session.activate_table(&"left")
	screen.refresh_from_session()
	await process_frame
	_assert_true(screen.session.preview().total == 51, "complete UI state should preview 51")
	var preview_signature := screen.session.preview().event_signature()

	await _click(screen.get_node("%ConfirmButton"))
	_assert_true(screen.session.controller.committed, "confirm button should commit")
	_assert_true(screen.session.commit().total == 51, "committed report should remain 51")
	_assert_true(
		screen.session.commit().event_signature() == preview_signature,
		"commit should preserve the preview event signature"
	)
	screen.bind_external_session(screen.session, "区域测试", "目标测试")
	_assert_true(
		not screen.get_node("%EntryGroups").visible,
		"externally owned encounters should hide the complete entry container"
	)

	screen.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS single_encounter_input_self_check")
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

func _find_slot(lane: Control, slot_index: int) -> RuleSlot:
	for node in lane.find_children("*", "Button", true, false):
		if node is RuleSlot and node.index == slot_index:
			return node
	return null

func _click(control: Control) -> void:
	_assert_true(control != null, "click target should exist")
	if control == null:
		return
	var point := control.get_global_rect().get_center()
	await _click_at_point(point)

func _click_lane(lane: Control) -> void:
	var point := lane.get_global_rect().position + Vector2(18.0, 18.0)
	await _click_at_point(point)

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
	var finish := target.get_global_rect().get_center()
	await _drag_to_point(source, finish)

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
