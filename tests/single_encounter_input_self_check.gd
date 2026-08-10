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
	var second_slot := _find_slot(left, 1)
	var second_slot_label_point := (
		second_slot.get_global_rect().position
		+ Vector2(second_slot.size.x * 0.5, -8.0)
	)
	await _drag_to_point(d1, second_slot_label_point)
	_assert_true(
		screen.session.controller.state.assignments.get(&"left", [])
		== [&"", &"d1"],
		"real drag should assign d1 to slot 2 instead of the first empty slot"
	)
	_assert_true(
		screen.get_node("%InteractionMotionLayer").get_child_count() == 0,
		"a completed pointer drag must not replay a second automatic die flight"
	)
	_assert_true(
		_find_die(&"d1").modulate.a == 1.0,
		"the dropped die should be visible immediately after the drag preview ends"
	)
	_assert_true(
		screen.get_node("%InteractionMotionLayer").get_meta(
			"last_response_sequence", []
		) == [&"source", &"affected", &"prediction"],
		"partial placement should update the die and prediction without flashing the lane"
	)
	await _drag(_find_die(&"d2"), _find_die(&"d1"))
	_assert_true(
		screen.session.controller.state.assignments.get(&"left", [])
		== [&"", &"d2"],
		"a free die dropped on occupied slot 2 should replace its occupant"
	)
	var swap_tray: Control = screen.get_node("%DiceTray")
	var displaced_d1 := _find_die(&"d1")
	_assert_true(
		displaced_d1 != null and swap_tray.is_ancestor_of(displaced_d1),
		"the displaced die should reappear in the tray"
	)
	_assert_true(
		screen.get_node("%ErrorLabel").text.is_empty(),
		"a successful free-to-occupied drag should not show an error"
	)
	_assert_true(
		screen.get_node("%InteractionMotionLayer").get_meta(
			"last_response_sequence", []
		) == [&"source", &"affected", &"prediction"],
		"replacing one die should update the source, target, and prediction"
	)
	await _click(screen.get_node("%UndoButton"))
	_assert_true(
		screen.session.controller.state.assignments.get(&"left", [])
		== [&"", &"d1"],
		"one undo should restore the displaced die to its original slot"
	)
	var reverted_d2 := _find_die(&"d2")
	_assert_true(
		reverted_d2 != null and swap_tray.is_ancestor_of(reverted_d2),
		"undo should return the incoming die to the tray"
	)
	_assert_true(
		screen.session.controller.undo_remaining() == 0
		and screen.get_node("%UndoButton").disabled,
		"one successful undo should exhaust and disable the per-round allowance"
	)

	await _reset_round()
	left = screen.get_node("%LeftLane")
	screen.session.controller.assign_die_to_slot(&"d1", &"left", 1, 2)
	screen.refresh_from_session()
	await process_frame
	await _right_click(_find_die(&"d1"))
	_assert_true(
		screen.session.controller.state.assigned_die_ids(&"left").is_empty(),
		"right-clicking an assigned die should return it to the tray"
	)
	await _click(screen.get_node("%UndoButton"))
	_assert_true(
		screen.session.controller.state.assigned_die_ids(&"left") == [&"d1"],
		"undo should restore a die returned by right-click"
	)

	await _reset_round()
	left = screen.get_node("%LeftLane")
	screen.session.controller.assign_die_to_slot(&"d1", &"left", 1, 2)
	screen.refresh_from_session()
	await process_frame
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

	await _reset_round()
	left = screen.get_node("%LeftLane")
	screen.session.controller.assign_die_to_slot(&"d1", &"left", 1, 2)
	screen.refresh_from_session()
	await process_frame
	await _click(_find_die(&"d2"))
	await _click(_find_slot(left, 1))
	_assert_true(
		screen.session.controller.state.assignments.get(&"left", [])
		== [&"", &"d2"],
		"clicking an occupied slot with a free die selected should replace its occupant"
	)
	var clicked_out_d1 := _find_die(&"d1")
	_assert_true(
		clicked_out_d1 != null and tray.is_ancestor_of(clicked_out_d1),
		"the die displaced by a click exchange should reappear in the tray"
	)
	_assert_true(
		screen.get_node("%ErrorLabel").text.is_empty(),
		"a successful free-to-occupied click should not show an error"
	)
	await _click(screen.get_node("%UndoButton"))
	_assert_true(
		screen.session.controller.state.assignments.get(&"left", [])
		== [&"", &"d1"]
		and not screen.session.controller.state.is_assigned(&"d2"),
		"one undo should reverse the complete click exchange"
	)

	await _reset_round()
	left = screen.get_node("%LeftLane")
	screen.session.controller.assign_die_to_slot(&"d6", &"left", 0, 2)
	screen.session.controller.assign_die_to_slot(&"d1", &"left", 1, 2)
	screen.refresh_from_session()
	await process_frame
	_assert_true(
		screen.session.controller.state.assigned_die_ids(&"left")
		== [&"d6", &"d1"],
		"click fallback should assign d6 to left"
	)

	await _click(_find_die(&"d1"))
	await _click(_find_slot(left, 0))
	_assert_true(
		screen.session.controller.state.assignments.get(&"left", [])
		== [&"d1", &"d6"],
		"clicking an occupied slot with an assigned die selected should swap"
	)
	await _click(screen.get_node("%UndoButton"))
	_assert_true(
		screen.session.controller.state.assignments.get(&"left", [])
		== [&"d6", &"d1"],
		"one undo should reverse the whole slot swap"
	)

	await _reset_round()
	left = screen.get_node("%LeftLane")
	screen.session.controller.assign_die_to_slot(&"d6", &"left", 0, 2)
	screen.session.controller.assign_die_to_slot(&"d1", &"left", 1, 2)
	screen.refresh_from_session()
	await process_frame
	await _drag(_find_die(&"d1"), _find_die(&"d6"))
	_assert_true(
		screen.session.controller.state.assignments.get(&"left", [])
		== [&"d1", &"d6"],
		"dragging an assigned die onto another assigned die should swap slots"
	)
	await _click(screen.get_node("%UndoButton"))
	_assert_true(
		screen.session.controller.state.assignments.get(&"left", [])
		== [&"d6", &"d1"],
		"one undo should reverse a drag-based slot swap"
	)

	await _reset_round()
	left = screen.get_node("%LeftLane")
	var right: Control = screen.get_node("%RightLane")
	screen.session.controller.assign_die_to_slot(&"d6", &"left", 0, 2)
	screen.session.controller.assign_die_to_slot(&"d1", &"left", 1, 2)
	screen.session.controller.assign_die_to_slot(&"d2", &"right", 0, 1)
	screen.refresh_from_session()
	await process_frame
	await _drag(_find_die(&"d1"), _find_die(&"d2"))
	_assert_true(
		screen.session.controller.state.assignments.get(&"left", [])
		== [&"d6", &"d2"]
		and screen.session.controller.state.assignments.get(&"right", [])
		== [&"d1"],
		"dragging between occupied lanes should swap both slot assignments"
	)
	await _click(screen.get_node("%UndoButton"))
	_assert_true(
		screen.session.controller.state.assignments.get(&"left", [])
		== [&"d6", &"d1"]
		and screen.session.controller.state.assigned_die_ids(&"right") == [&"d2"],
		"undo should restore both lanes after a cross-lane drag swap"
	)

	await _reset_round()
	left = screen.get_node("%LeftLane")
	screen.session.controller.assign_die_to_slot(&"d6", &"left", 0, 2)
	screen.session.controller.assign_die_to_slot(&"d1", &"left", 1, 2)
	screen.refresh_from_session()
	await process_frame
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

	var left_evaluation_color := left.self_modulate
	await _click(_find_card(0))
	_assert_true(
		_find_die(&"d2").self_modulate != Color.WHITE,
		"die cards should highlight dice"
	)
	_assert_true(
		screen.get_node("%LeftLane").self_modulate == left_evaluation_color,
		"die cards should preserve rather than replace the rule evaluation color"
	)
	await _click(_find_card(2))
	_assert_true(
		screen.get_node("%LeftGap").self_modulate != Color.WHITE
		and screen.get_node("%LeftLane").self_modulate == left_evaluation_color,
		"gap cards should highlight gaps without replacing table evaluation"
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

	await _reset_round()
	await _click(_find_card(0))
	await _click(_find_die(&"d2"))
	_assert_true(
		_find_card(0).get_node("%CommittedBadge").visible
		and "D2" in _find_card(0).get_node("%CommittedBadge").text,
		"a committed point card should visibly lock its die target"
	)
	await _click(_find_card(3))
	_assert_true(
		_find_card(1).disabled,
		"unused cards should be disabled after the two-card round limit"
	)
	await _click(_find_card(1))
	_assert_true(
		screen.session.selection.kind == InteractionState.Kind.NONE,
		"clicking a card at the round limit must not select it"
	)
	await _click(screen.get_node("%UndoButton"))
	_assert_true(
		not _find_card(1).disabled,
		"undoing below the round limit should re-enable unused cards"
	)
	_assert_true(
		screen.get_node("%UndoButton").disabled,
		"the same round should not offer a second undo"
	)

	await _reset_round()
	await _click(_find_die(&"d5"))
	await _click(screen.get_node("%MinusButton"))
	_assert_true(
		screen.session.selection.kind == InteractionState.Kind.NONE,
		"calibration should finish immediately and clear the die selection"
	)
	_assert_true(
		"已确认：D5 5→4" in screen.get_node("%SelectionHintLabel").text,
		"calibration should show an explicit completion message"
	)
	screen.session.activate_die(&"d1")
	screen.session.activate_table(&"left")
	screen.session.activate_die(&"d6")
	screen.session.activate_table(&"left")
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

func _reset_round() -> void:
	screen.reset_teaching_encounter()
	await process_frame
	await process_frame

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

func _right_click(control: Control) -> void:
	_assert_true(control != null, "right-click target should exist")
	if control == null:
		return
	var point := control.get_global_rect().get_center()
	await _move_pointer(point)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_RIGHT
	press.pressed = true
	press.position = point
	root.push_input(press, true)
	await process_frame
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_RIGHT
	release.pressed = false
	release.position = point
	root.push_input(release, true)
	await process_frame

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
