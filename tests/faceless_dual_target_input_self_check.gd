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

	var state := RoundState.new()
	for die_index in range(1, 7):
		state.dice.append(DieState.new(
			StringName("d%d" % die_index),
			die_index
		))
	var catalog := CardCatalog.new()
	var hand: Array[CardDefinition] = [
		catalog.find_card(&"faceless_swap_values"),
		catalog.find_card(&"faceless_copy_value"),
		catalog.find_card(&"starter_nudge_up_1"),
		catalog.find_card(&"starter_nudge_down_1"),
	]
	var room := AreaCatalog.new().faceless_hub().rooms[0]
	var session := SingleEncounterSession.new(
		state,
		room.encounter,
		hand,
		ResolutionContext.new(null, EngravingCatalog.new())
	)
	screen.bind_external_session(session, "无面中枢", "双骰输入自检")
	await process_frame

	_press_card(screen, 0)
	await process_frame
	_assert(
		screen.get_node("%SelectionHintLabel").text.contains("来源"),
		"pair card should ask for a source die first"
	)
	_assert(
		_find_die(screen, &"d1").self_modulate != Color.WHITE,
		"legal source dice should be highlighted"
	)

	_find_die(screen, &"d1").emit_signal("pressed")
	await process_frame
	_assert(
		session.selection.card_primary_target == &"d1",
		"first die should be retained as pair source"
	)
	_assert(
		screen.get_node("%SelectionHintLabel").text.contains("目标"),
		"pair card should ask for a target after source selection"
	)
	_assert(
		_find_die(screen, &"d1").self_modulate.a < 1.0,
		"the source die should be shown as an illegal second target"
	)
	_find_die(screen, &"d1").emit_signal("pressed")
	await process_frame
	_assert(
		screen.get_node("%ErrorLabel").text == "双骰手法牌需要两颗不同的骰子",
		"reusing the source die should show a concrete reason"
	)
	_find_die(screen, &"d2").emit_signal("pressed")
	await process_frame
	_assert(
		session.controller.state.played_cards.size() == 1,
		"second target should submit exactly one card play"
	)
	var played: PlayedCard = session.controller.state.played_cards[0]
	_assert(
		played.primary_target == &"d1" and played.secondary_target == &"d2",
		"pair play should preserve source and target order"
	)

	_press_card(screen, 1)
	await process_frame
	_find_die(screen, &"d3").emit_signal("pressed")
	await process_frame
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	screen._unhandled_key_input(escape)
	await process_frame
	_assert(
		session.selection.kind == InteractionState.Kind.NONE,
		"Escape should cancel an incomplete pair selection"
	)

	screen.free()
	if _failed:
		quit(1)
	else:
		print("FACELESS DUAL TARGET INPUT SELF CHECK PASSED")
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
