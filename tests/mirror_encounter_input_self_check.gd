extends SceneTree

var _failed := false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var screen: SingleEncounterScreen = load(
		"res://scenes/run/single_encounter_screen.tscn"
	).instantiate()
	screen.tutorial_auto_start = false
	root.add_child(screen)
	await process_frame

	var catalog := CardCatalog.new()
	var area := AreaCatalog.new().mirror_hall()
	var state := RoundState.new()
	for index in range(1, 7):
		state.dice.append(DieState.new(StringName("d%d" % index), index))
	var hand: Array[CardDefinition] = [
		catalog.find_card(&"mirror_folded_map"),
		catalog.find_card(&"starter_link"),
		catalog.find_card(&"starter_map_1"),
		catalog.find_card(&"starter_reverse"),
	]
	var session := SingleEncounterSession.new(
		state,
		area.find_room(&"mirror_room_reverse_drill").encounter,
		hand,
		ResolutionContext.new(null, EngravingCatalog.new())
	)
	screen.bind_external_session(session, "反照牌厅", "输入自检")
	await process_frame

	_assert(
		screen.get_node("%DirectionBadge").text == "← 从右向左结算",
		"direction badge should bind public RTL direction"
	)
	_press_card(screen, 0)
	screen.get_node("%LeftGap").emit_signal("pressed")
	await process_frame
	_assert(screen.get_node("%RightMirrorLayer").visible, "left play should show right mirror")
	_assert(
		screen.get_node("%RightMirrorLayer").text.contains("镜像"),
		"derived copy should have a textual mirror label"
	)

	screen.get_node("%UndoButton").emit_signal("pressed")
	await process_frame
	_assert(
		not screen.get_node("%RightMirrorLayer").visible,
		"undo should remove the derived mirror layer"
	)

	_press_card(screen, 0)
	screen.get_node("%LeftGap").emit_signal("pressed")
	await process_frame
	_press_card(screen, 1)
	screen.get_node("%RightGap").emit_signal("pressed")
	await process_frame
	var real_count := 0
	var mirror_count := 0
	for played_card in session.controller.state.played_cards:
		if played_card.is_mirror_copy:
			mirror_count += 1
		else:
			real_count += 1
	_assert(real_count == 2, "virtual mirror must not block a second real gap card")
	_assert(mirror_count == 1, "round should keep exactly one derived mirror")
	_assert(
		screen.get_node("%RightMirrorLayer").visible,
		"mirror remains visible beside the second real card"
	)

	screen.free()
	if _failed:
		quit(1)
	else:
		print("MIRROR ENCOUNTER INPUT SELF CHECK PASSED")
		quit(0)

func _press_card(screen: Control, card_index: int) -> void:
	for child in screen.get_node("%Hand").get_children():
		if (
			child is CardToken
			and not child.is_queued_for_deletion()
			and child.card_index == card_index
		):
			child.emit_signal("pressed")
			return
	_assert(false, "card token %d should exist" % card_index)

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
