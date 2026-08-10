extends SceneTree

var _failed := false
var _config_path := ""

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_config_path = "%s/project-joker-mirror-guide-input-%d.cfg" % [
		OS.get_temp_dir(),
		Time.get_ticks_usec(),
	]
	root.set_meta("mirror_hall_guide_config_path", _config_path)
	change_scene_to_file("res://scenes/run/mirror_hall_run_screen.tscn")
	await process_frame
	await process_frame
	var screen := current_scene as MirrorHallRunScreen
	_assert(screen != null, "mirror guide screen should load")
	if screen == null:
		_finish()
		return
	var opening_narrative := screen.get_node("%NarrativeCard")
	if opening_narrative.is_open():
		opening_narrative.get_node("%NarrativeContinueButton").emit_signal("pressed")
		await process_frame
		await process_frame

	var route_button := screen.get_node("%RouteChoicePanel").get_node(
		"%LeftRouteButton"
	) as Button
	route_button.emit_signal("pressed")
	await process_frame
	await process_frame
	_assert_card(screen, &"direction")
	var before_direction := _business_snapshot(screen)
	screen.get_node("%MirrorHallGuideOverlay").get_node(
		"%GuideAcknowledgeButton"
	).emit_signal("pressed")
	await process_frame
	_assert_equal(
		_business_snapshot(screen),
		before_direction,
		"direction guide should not mutate business state"
	)

	var mirror_index := -1
	for index in range(screen.area_session.encounter_session.current_hand_ids.size()):
		var card_id: StringName = (
			screen.area_session.encounter_session.current_hand_ids[index]
		)
		if not screen.area_session.card_catalog.find_card(card_id).mirror_effects.is_empty():
			mirror_index = index
			break
	_assert(mirror_index >= 0, "first hand should expose a mirror card")
	_press_card(screen, mirror_index)
	await process_frame
	_assert_card(screen, &"mirror")
	var before_mirror := _business_snapshot(screen)
	screen.get_node("%MirrorHallGuideOverlay").get_node(
		"%GuideAcknowledgeButton"
	).emit_signal("pressed")
	await process_frame
	_assert_equal(
		_business_snapshot(screen),
		before_mirror,
		"mirror guide should not mutate business state"
	)

	_drive_domain_to_dealer(screen.area_session)
	screen.bind_current_encounter()
	await process_frame
	await process_frame
	_assert(
		screen.get_node("%NarrativeCard").is_open(),
		"dealer opening should precede the dealer guide"
	)
	_assert(
		not screen.get_node("%MirrorHallGuideOverlay").is_open(),
		"dealer guide should wait behind the opening"
	)
	screen.get_node("%NarrativeCard").get_node(
		"%NarrativeContinueButton"
	).emit_signal("pressed")
	await process_frame
	await process_frame
	_assert_card(screen, &"dealer")
	var before_dealer := _business_snapshot(screen)
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	screen.get_node("%MirrorHallGuideOverlay")._unhandled_key_input(escape)
	await process_frame
	_assert_equal(
		_business_snapshot(screen),
		before_dealer,
		"dealer guide should not mutate business state"
	)

	var store := MirrorHallGuideProgressStore.new(_config_path)
	_assert(store.is_seen(&"direction"), "direction should persist")
	_assert(store.is_seen(&"mirror"), "mirror should persist")
	_assert(store.is_seen(&"dealer"), "dealer should persist")
	_finish()

func _drive_domain_to_dealer(area: AreaRunSession) -> void:
	_complete_encounter(area)
	_resolve_domain_event(area)
	_assert(area.open_shop().accepted, "first shop should open")
	_assert(area.leave_shop().accepted, "first shop should close")
	_assert(
		area.select_route(area.current_route_ids()[0]).accepted,
		"second route should select"
	)
	_complete_encounter(area)
	_resolve_domain_event(area)
	_assert(area.open_shop().accepted, "second shop should open")
	_assert(area.leave_shop().accepted, "second shop should open dealer")

func _complete_encounter(area: AreaRunSession) -> void:
	area.encounter_session.target_total = 0
	var round_count := area.encounter_session.round_count
	for round_index in range(round_count):
		var report := area.encounter_session.current_session.commit()
		var accepted := area.accept_encounter_report(report)
		_assert(
			accepted.accepted,
			"report should be accepted; error=%s" % accepted.reason
		)
		if round_index < round_count - 1:
			var advanced := area.advance_encounter_round()
			_assert(
				advanced.accepted,
				"round should advance; error=%s" % advanced.reason
			)

func _resolve_domain_event(area: AreaRunSession) -> void:
	_assert(area.phase == AreaRunSession.Phase.EVENT, "normal room should enter event")
	var result: OperationResult
	match area.current_event_id:
		AreaRunSession.EVENT_DICE_ARTISAN:
			result = area.resolve_event(&"reroll", &"d1")
		AreaRunSession.EVENT_REST_STOP:
			result = area.resolve_event(&"rest")
		_:
			result = area.resolve_event(&"intel")
	_assert(result != null and result.accepted, "event should resolve before shop")

func _press_card(screen: MirrorHallRunScreen, card_index: int) -> void:
	for child in screen.get_node("%EncounterScreen").get_node("%Hand").get_children():
		if (
			child is CardToken
			and not child.is_queued_for_deletion()
			and child.card_index == card_index
		):
			child.emit_signal("pressed")
			return
	_assert(false, "mirror card token should exist")

func _assert_card(screen: MirrorHallRunScreen, checkpoint_id: StringName) -> void:
	var overlay := screen.get_node("%MirrorHallGuideOverlay") as IronAbacusGuideOverlay
	_assert(overlay.is_open(), "%s guide should open" % checkpoint_id)
	_assert(
		overlay.active_checkpoint_id() == checkpoint_id,
		"%s guide should be active" % checkpoint_id
	)

func _business_snapshot(screen: MirrorHallRunScreen) -> Dictionary:
	var encounter := screen.area_session.encounter_session
	var state := encounter.current_session.controller.state
	var dice: Array = []
	for die in state.dice:
		dice.append([
			die.id,
			die.rolled_value,
			die.value,
			die.engraving_id,
			die.engraved_face,
		])
	var cards: Array = []
	for card in state.played_cards:
		cards.append([
			card.definition.id,
			card.primary_target,
			card.secondary_target,
			card.is_mirror_copy,
		])
	return {
		"round": encounter.current_round,
		"deck": screen.area_session.deck_ids.duplicate(),
		"tickets": screen.area_session.intel_tickets,
		"rng": screen.area_session.run_rng.snapshot_state(),
		"dice": dice,
		"assignments": state.assignments.duplicate(true),
		"cards": cards,
		"calibration": state.calibration_points,
	}

func _assert_equal(actual, expected, message: String) -> void:
	_assert(actual == expected, "%s; expected=%s actual=%s" % [message, expected, actual])

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)

func _finish() -> void:
	if not _config_path.is_empty():
		DirAccess.remove_absolute(_config_path)
	if _failed:
		quit(1)
	else:
		print("MIRROR HALL GUIDE INPUT SELF CHECK PASSED")
		quit(0)
