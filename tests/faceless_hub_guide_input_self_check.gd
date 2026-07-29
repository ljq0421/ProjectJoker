extends SceneTree

var _failed := false
var _config_path := ""

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	_config_path = "%s/project-joker-faceless-guide-input-%d.cfg" % [
		OS.get_temp_dir(),
		Time.get_ticks_usec(),
	]
	root.set_meta("faceless_hub_guide_config_path", _config_path)
	change_scene_to_file("res://scenes/run/faceless_hub_run_screen.tscn")
	await _settle()
	var screen := current_scene as FacelessHubRunScreen
	_assert(screen != null, "faceless guide screen should load")
	if screen == null:
		_finish()
		return

	var route_button := screen.get_node("%RouteChoicePanel").get_node(
		"%LeftRouteButton"
	) as Button
	route_button.emit_signal("pressed")
	await _settle()
	_assert_card(screen, &"composite")
	var composite_snapshot := _business_snapshot(screen)
	screen.guide_overlay.get_node("%GuideAcknowledgeButton").emit_signal(
		"pressed"
	)
	await process_frame
	_assert_equal(
		_business_snapshot(screen),
		composite_snapshot,
		"composite guide must not mutate the encounter"
	)

	var history: Array[ShopPurchaseRecord] = []
	var service_history: Array[ShopServiceRecord] = []
	var dealer_result := screen.area_session._create_dealer(
		screen.area_session.deck_ids,
		screen.area_session.intel_tickets,
		history,
		service_history
	)
	_assert(dealer_result.accepted, "dealer fixture should start")
	screen.area_session.encounter_session.target_total = 1
	screen.bind_current_encounter()
	await _settle()
	_assert_card(screen, &"schedule")
	var schedule_snapshot := _business_snapshot(screen)
	screen.guide_overlay.get_node("%GuideAcknowledgeButton").emit_signal(
		"pressed"
	)
	await process_frame
	_assert_equal(
		_business_snapshot(screen),
		schedule_snapshot,
		"schedule guide must not mutate the encounter"
	)

	await _commit_and_advance(screen)
	await _commit_current_round(screen)
	await _settle()
	_assert_card(screen, &"restriction")
	var panel := screen.final_restriction_panel
	_assert(
		panel.visible and panel.selected_restriction_id == &"",
		"restriction guide should coexist with an unselected modal"
	)
	var restriction_snapshot := _business_snapshot(screen)
	screen.guide_overlay.get_node("%GuideAcknowledgeButton").emit_signal(
		"pressed"
	)
	await process_frame
	_assert_equal(
		_business_snapshot(screen),
		restriction_snapshot,
		"restriction guide must not mutate the encounter"
	)
	_assert(
		panel.visible and panel.selected_restriction_id == &"",
		"closing the guide should leave restriction choice open"
	)

	var store := FacelessHubGuideProgressStore.new(_config_path)
	for checkpoint_id in [&"composite", &"schedule", &"restriction"]:
		_assert(store.is_seen(checkpoint_id), "%s should persist" % checkpoint_id)
	_finish()

func _commit_and_advance(screen: FacelessHubRunScreen) -> void:
	await _commit_current_round(screen)
	screen._on_next_round_requested()
	await _settle()

func _commit_current_round(screen: FacelessHubRunScreen) -> void:
	var session := screen.area_session.encounter_session.current_session
	for pair in [
		[&"d1", &"left"],
		[&"d2", &"middle"],
		[&"d3", &"right"],
	]:
		session.activate_die(pair[0])
		session.activate_table(pair[1])
	screen.encounter_screen.refresh_from_session()
	await process_frame
	screen.encounter_screen.get_node("%ConfirmButton").emit_signal("pressed")
	screen.encounter_screen.resolution_panel.finish_playback()
	await process_frame

func _assert_card(
	screen: FacelessHubRunScreen,
	checkpoint_id: StringName
) -> void:
	_assert(screen.guide_overlay.is_open(), "%s guide should open" % checkpoint_id)
	_assert(
		screen.guide_overlay.active_checkpoint_id() == checkpoint_id,
		"%s guide should be active" % checkpoint_id
	)

func _business_snapshot(screen: FacelessHubRunScreen) -> Dictionary:
	var encounter := screen.area_session.encounter_session
	if encounter == null:
		return {"phase": screen.area_session.phase}
	return {
		"phase": screen.area_session.phase,
		"round": encounter.current_round,
		"status": encounter.status,
		"cards": encounter.current_session.controller.state.played_cards.size(),
		"assignments": (
			encounter.current_session.controller.state.assignments.duplicate(true)
		),
		"restriction": (
			encounter.selected_final_restriction.id
			if encounter.selected_final_restriction != null
			else &""
		),
	}

func _settle() -> void:
	await process_frame
	await process_frame
	await process_frame

func _assert_equal(actual, expected, message: String) -> void:
	_assert(actual == expected, "%s; expected=%s actual=%s" % [
		message,
		expected,
		actual,
	])

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
		print("FACELESS HUB GUIDE INPUT SELF CHECK PASSED")
		quit(0)
