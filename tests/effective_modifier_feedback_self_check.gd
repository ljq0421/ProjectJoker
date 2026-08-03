extends SceneTree

var _failed := false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var screen: SingleEncounterScreen = load(
		"res://scenes/run/single_encounter_screen.tscn"
	).instantiate()
	screen.tutorial_auto_start = false
	root.add_child(screen)
	await process_frame

	var catalog := CardCatalog.new()
	var hand: Array[CardDefinition] = [
		catalog.find_card(&"starter_nudge_down_2"),
		catalog.find_card(&"starter_amplified_repeat"),
	]
	var session := SingleEncounterSession.new(
		SingleEncounterFixture.make_state(),
		SingleEncounterFixture.make_encounter(),
		hand
	)
	screen.bind_external_session(session, "反馈自检", "显示手法牌后的有效值")
	await process_frame
	var center: Control = screen.get_node("SafeArea/RootColumn/Body/Center")
	var hand_control: Control = screen.get_node("%Hand")
	var root_column: Control = screen.get_node("SafeArea/RootColumn")
	var center_min_before := center.get_combined_minimum_size()
	var hand_min_before := hand_control.get_combined_minimum_size()
	var root_size_before := root_column.size

	_press_card(screen, 0)
	await process_frame
	_assert(
		center.get_combined_minimum_size().is_equal_approx(center_min_before),
		"selecting a card should not increase center minimum size; before=%s after=%s"
		% [center_min_before, center.get_combined_minimum_size()]
	)
	_assert(
		hand_control.get_combined_minimum_size().is_equal_approx(hand_min_before),
		"selecting a card should not increase hand minimum size; before=%s after=%s"
		% [hand_min_before, hand_control.get_combined_minimum_size()]
	)
	_assert(
		root_column.size.is_equal_approx(root_size_before),
		"selecting a card should not stretch the page; before=%s after=%s"
		% [root_size_before, root_column.size]
	)
	_find_die(screen, &"d5").emit_signal("pressed")
	await process_frame
	var adjusted_die := _find_die(screen, &"d5")
	_assert(adjusted_die.text == "3", "die face should directly show 3 after deep drop")
	_assert(
		adjusted_die.tooltip_text.contains("初始 5，手法牌后 3"),
		"die tooltip should explain the initial and adjusted values"
	)

	_press_card(screen, 1)
	await process_frame
	screen.get_node("%LeftLane").emit_signal("lane_activated", &"left")
	await process_frame
	var rule_copy: String = screen.get_node("%LeftLane/%Condition").text
	_assert(
		rule_copy.begins_with("2 个骰位 · 系数 ×2 → ×3 · 结算 2 次"),
		"rule lane should show coefficient and repeat changes"
	)

	screen.free()
	if _failed:
		quit(1)
	else:
		print("EFFECTIVE MODIFIER FEEDBACK SELF CHECK PASSED")
		quit(0)

func _find_die(screen: Control, die_id: StringName) -> DieToken:
	for node in screen.find_children("*", "Button", true, false):
		if (
			node is DieToken
			and not node.is_queued_for_deletion()
			and node.die_id == die_id
		):
			return node
	return null

func _press_card(screen: Control, card_index: int) -> void:
	for node in screen.get_node("%Hand").get_children():
		if (
			node is CardToken
			and not node.is_queued_for_deletion()
			and node.card_index == card_index
		):
			node.emit_signal("pressed")
			return
	_assert(false, "card %d should exist" % card_index)

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
