extends SceneTree

var _failed := false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	change_scene_to_file("res://scenes/run/single_encounter_screen.tscn")
	await _settle()
	var entry := current_scene as SingleEncounterScreen
	_assert(entry != null, "main entry should load")
	entry.get_node("%FacelessHubRunButton").emit_signal("pressed")
	await _settle()
	var screen := current_scene as FacelessHubRunScreen
	_assert(screen != null, "faceless entry button should open the area")
	if screen == null:
		quit(1)
		return
	screen.guide_auto_start = false

	for room_number in range(2):
		screen._on_route_selected(screen.area_session.current_route_ids()[0])
		await _settle()
		await _complete_normal_encounter(screen)
		screen._on_shop_requested()
		await _settle()
		_assert(screen.shop_screen.visible, "shop %d should open" % (room_number + 1))
		screen._on_shop_leave_requested()
		await _settle()

	_assert(
		screen.area_session.phase == AreaRunSession.Phase.DEALER,
		"two rooms and shops should reach Faceless Master"
	)
	var narrative := screen.get_node("%NarrativeCard")
	_assert(narrative.is_open(), "dealer entry should show Faceless Master opening")
	_assert(
		"三轮都在这里" in narrative.get_node("%NarrativeBody").text,
		"dealer opening should expose the confirmed Faceless Master line"
	)
	var restored: FacelessHubRunScreen = load(
		"res://scenes/run/faceless_hub_run_screen.tscn"
	).instantiate()
	restored.guide_auto_start = false
	restored.configure_for_expedition(
		AreaCatalog.new().faceless_hub(),
		FacelessHubRunScreen.FACELESS_SEED,
		{},
		screen.area_session.checkpoint_snapshot(),
		false
	)
	root.add_child(restored)
	await _settle()
	_assert(
		restored.area_session.phase == AreaRunSession.Phase.DEALER
			and restored.get_node("%NarrativeCard").is_open(),
		"dealer-entry checkpoint restore should re-show the opening"
	)
	restored.queue_free()
	await _settle()
	narrative.get_node("%NarrativeContinueButton").emit_signal("pressed")
	await _settle()
	screen.area_session.encounter_session.target_total = 0
	await _commit_round(screen)
	screen._on_next_round_requested()
	await _settle()
	await _commit_round(screen)
	await _settle()
	_assert(
		screen.final_restriction_panel.visible,
		"round two should require final restriction"
	)
	screen.final_restriction_panel.get_node(
		"%OperationRestrictionButton"
	).emit_signal("pressed")
	screen.final_restriction_panel.get_node(
		"%RestrictionConfirmButton"
	).emit_signal("pressed")
	await _settle()
	_assert(
		screen.area_session.encounter_session.current_round == 3,
		"restriction confirmation should enter round three"
	)
	await _commit_round(screen)
	await _settle()
	_assert(
		screen.area_session.phase == AreaRunSession.Phase.ENGRAVING_REWARD,
		"dealer success should open engraving reward"
	)
	var engraving_id: StringName = screen.area_session.engraving_offer_ids[0]
	screen._on_engraving_selected(engraving_id)
	screen._on_install_requested(engraving_id, &"d1", 2)
	await _settle()
	_assert(
		screen.area_session.phase == AreaRunSession.Phase.COMPLETE,
		"engraving install should complete the area"
	)
	_assert(
		screen.complete_panel.visible,
		"completion summary should be visible"
	)
	var snapshot := screen.area_session.completion_snapshot()
	_assert(snapshot.rooms.size() == 2, "completion should retain both rooms")
	_assert(
		snapshot.dealer.id == &"dealer_faceless_master",
		"completion should retain Faceless Master"
	)

	screen.free()
	if _failed:
		quit(1)
	else:
		print("FACELESS HUB END TO END SELF CHECK PASSED")
		quit(0)

func _complete_normal_encounter(screen: FacelessHubRunScreen) -> void:
	screen.area_session.encounter_session.target_total = 0
	for round_index in range(3):
		await _commit_round(screen)
		if round_index < 2:
			screen._on_next_round_requested()
			await _settle()

func _commit_round(screen: FacelessHubRunScreen) -> void:
	var controller := (
		screen.area_session.encounter_session.current_session.controller
	)
	var restriction := controller.active_restriction
	if (
		restriction != null
		and restriction.operation
			== FinalRestrictionDefinition.Operation.REQUIRE_ALL_TABLES_OCCUPIED
	):
		for index in range(3):
			var rule := controller.encounter.rules[index]
			controller.assign_die(
				StringName("d%d" % (index + 1)),
				rule.id,
				controller.effective_slot_count(rule.id)
			)
	screen.encounter_screen.refresh_from_session()
	await process_frame
	screen.encounter_screen.get_node("%ConfirmButton").emit_signal("pressed")
	screen.encounter_screen.resolution_panel.finish_playback()
	await _settle()

func _settle() -> void:
	await process_frame
	await process_frame

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
