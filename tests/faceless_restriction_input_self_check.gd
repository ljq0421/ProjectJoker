extends SceneTree

var _failed := false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var screen: FacelessHubRunScreen = load(
		"res://scenes/run/faceless_hub_run_screen.tscn"
	).instantiate()
	root.add_child(screen)
	await process_frame

	var area: AreaDefinition = AreaCatalog.new().faceless_hub().duplicate(true)
	area.dealer_target = 1
	var area_session := AreaRunSession.new(
		FacelessHubRunScreen.FACELESS_SEED,
		area
	)
	var start_result := area_session.start()
	_assert(start_result.accepted, "faceless session should start")
	var history: Array[ShopPurchaseRecord] = []
	var dealer_result := area_session._create_dealer(
		area_session.deck_ids,
		area_session.intel_tickets,
		history
	)
	_assert(dealer_result.accepted, "faceless dealer should be creatable")
	screen.area_session = area_session
	screen.bind_current_encounter()
	await process_frame

	_assert(
		screen.get_node("%RoundScheduleStrip").visible,
		"dealer start should expose all three public rounds"
	)
	_assert(
		screen.round_schedule_strip.get_node("%RoundOneCard") != null
		and screen.round_schedule_strip.get_node("%RoundTwoCard") != null
		and screen.round_schedule_strip.get_node("%RoundThreeCard") != null,
		"schedule should keep three fixed cards"
	)

	await _commit_and_advance(screen)
	await _commit_current_round(screen)
	var panel: FinalRestrictionPanel = screen.get_node("%FinalRestrictionPanel")
	_assert(panel.visible, "round two completion should open restriction choice")
	_assert(
		panel.get_node("%RestrictionConfirmButton").disabled,
		"restriction choice should have no default selection"
	)
	panel.get_node("%OperationRestrictionButton").emit_signal("pressed")
	await process_frame
	_assert(
		not panel.get_node("%RestrictionConfirmButton").disabled,
		"choosing a candidate should enable confirmation"
	)
	panel.get_node("%DistributionRestrictionButton").emit_signal("pressed")
	await process_frame
	_assert(
		panel.selected_restriction_id == &"three_seats_present",
		"candidate buttons should switch the pending choice"
	)
	panel.get_node("%OperationRestrictionButton").emit_signal("pressed")
	panel.get_node("%RestrictionConfirmButton").emit_signal("pressed")
	await process_frame
	_assert(not panel.visible, "confirmation should close the modal")
	_assert(
		screen.area_session.encounter_session.current_round == 3,
		"confirmation should bind the third round directly"
	)
	var badge: Label = screen.encounter_screen.get_node(
		"%ActiveRestrictionBadge"
	)
	_assert(
		badge.visible and badge.text.contains("独手裁决"),
		"third round should show the chosen restriction"
	)
	_assert(
		screen.round_schedule_strip.get_node(
			"%RoundThreeDetail"
		).text.contains("独手裁决"),
		"schedule should retain the chosen restriction"
	)

	await _verify_restriction_reasons()
	screen.free()
	if _failed:
		quit(1)
	else:
		print("FACELESS RESTRICTION INPUT SELF CHECK PASSED")
		quit(0)

func _commit_and_advance(screen: FacelessHubRunScreen) -> void:
	await _commit_current_round(screen)
	screen._on_next_round_requested()
	await process_frame

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
	await process_frame

func _verify_restriction_reasons() -> void:
	var area := AreaCatalog.new().faceless_hub()
	var encounter: EncounterDefinition = area.rooms[0].encounter
	var catalog := CardCatalog.new()
	var state := RoundState.new()
	for die_index in range(1, 7):
		state.dice.append(DieState.new(
			StringName("d%d" % die_index),
			die_index
		))
	var hand: Array[CardDefinition] = [
		catalog.find_card(&"starter_nudge_up_1"),
		catalog.find_card(&"starter_nudge_down_1"),
		catalog.find_card(&"starter_map_2"),
		catalog.find_card(&"starter_repeat_1"),
	]
	var operation: FinalRestrictionDefinition = load(
		"res://resources/restrictions/faceless_hub/solo_verdict.tres"
	)
	var operation_session := SingleEncounterSession.new(
		state,
		encounter,
		hand,
		ResolutionContext.empty(),
		operation
	)
	_assert(operation_session.activate_card(0), "first real card should remain legal")
	_assert(operation_session.activate_die(&"d1"), "first real card should play")
	_assert(
		not operation_session.activate_card(1)
		and operation_session.last_error.contains("最多使用 1 张真实手法牌"),
		"second real card should name the solo-verdict limit"
	)

	var distribution: FinalRestrictionDefinition = load(
		"res://resources/restrictions/faceless_hub/three_seats_present.tres"
	)
	var distribution_session := SingleEncounterSession.new(
		state,
		encounter,
		hand,
		ResolutionContext.empty(),
		distribution
	)
	var report := distribution_session.commit()
	_assert(
		not report.valid
		and report.reason.contains("左侧规则台")
		and report.reason.contains("中间规则台")
		and report.reason.contains("右侧规则台"),
		"distribution failure should name every missing table"
	)

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
