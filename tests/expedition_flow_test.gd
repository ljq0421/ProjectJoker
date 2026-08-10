extends "res://tests/test_case.gd"

const SEED := 20260729

func run() -> void:
	_test_three_real_area_sessions_flow_in_order()

func _test_three_real_area_sessions_flow_in_order() -> void:
	var expedition := ExpeditionSession.new()
	assert_true(expedition.start_new(SEED).accepted, "expedition should start")
	for area_id in ExpeditionSession.AREA_ORDER:
		var area := AreaRunSession.new(
			SEED,
			_area_definition(area_id)
		)
		if not expedition.current_entry_state().is_empty():
			assert_true(
				area.configure_entry_state(
					expedition.current_entry_state()
				).accepted,
				"later area should accept inherited build"
			)
		assert_true(area.start().accepted, "%s should start" % area_id)
		for _room_index in range(2):
			assert_true(
				area.select_route(area.current_route_ids()[0]).accepted,
				"offered room should start"
			)
			_complete_encounter(area, false)
			assert_equal(
				area.phase,
				AreaRunSession.Phase.AFTER_NORMAL_ROOM,
				"normal room should reach a save boundary"
			)
			assert_true(area.open_shop().accepted, "boundary shop should open")
			assert_true(area.leave_shop().accepted, "shop should settle")
		assert_equal(area.phase, AreaRunSession.Phase.DEALER, "dealer should start")
		_complete_encounter(area, area_id == &"faceless_hub")
		assert_equal(
			area.phase,
			AreaRunSession.Phase.ENGRAVING_REWARD,
			"dealer should reach reward boundary"
		)
		var engraving_id: StringName = area.engraving_offer_ids[0]
		assert_true(area.select_engraving(engraving_id).accepted, "reward selects")
		var target := _first_blank_die(area.die_profiles)
		assert_false(target == &"", "each area should have a blank die")
		assert_true(
			area.install_selected_engraving(target, 2).accepted,
			"reward should install"
		)
		var completion := area.completion_snapshot()
		assert_true(
			expedition.complete_current_area(completion).accepted,
			"ordered area completion should advance expedition"
		)
	assert_equal(
		expedition.status,
		ExpeditionSession.Status.COMPLETE,
		"three actual area sessions complete the expedition"
	)
	var engraved_count := 0
	for profile in expedition.inherited_state["die_profiles"]:
		if profile["engraving_id"] != &"":
			engraved_count += 1
	assert_equal(engraved_count, 3, "one engraving from each area should carry")

func _complete_encounter(area: AreaRunSession, choose_restriction: bool) -> void:
	area.encounter_session.target_total = 0
	var round_total := area.encounter_session.round_count
	for round_index in range(round_total):
		_prepare_distribution_restriction(
			area.encounter_session.current_session.controller
		)
		var report := area.encounter_session.current_session.commit()
		assert_true(report.valid, "fixture round should commit")
		assert_true(
			area.accept_encounter_report(report).accepted,
			"area should accept committed report"
		)
		if round_index >= round_total - 1:
			continue
		if (
			choose_restriction
			and area.encounter_session.status
				== ThreeRoundEncounterSession.Status.AWAITING_RESTRICTION
		):
			assert_true(
				area.choose_dealer_restriction(&"solo_verdict").accepted,
				"faceless dealer restriction should confirm"
			)
		else:
			assert_true(
				area.advance_encounter_round().accepted,
				"next encounter round should start"
			)
	if area.phase == AreaRunSession.Phase.EVENT:
		_resolve_event(area)

func _resolve_event(area: AreaRunSession) -> void:
	var result: OperationResult
	match area.current_event_id:
		AreaRunSession.EVENT_DICE_ARTISAN:
			result = area.resolve_event(&"reroll", &"d1")
		AreaRunSession.EVENT_REST_STOP:
			result = area.resolve_event(&"rest")
		_:
			result = area.resolve_event(&"intel")
	assert_true(result.accepted, "fixture event should resolve")

func _prepare_distribution_restriction(controller: RoundController) -> void:
	var restriction := controller.active_restriction
	if (
		restriction == null
		or restriction.operation
			!= FinalRestrictionDefinition.Operation.REQUIRE_ALL_TABLES_OCCUPIED
	):
		return
	for index in range(3):
		var rule := controller.encounter.rules[index]
		controller.assign_die(
			StringName("d%d" % (index + 1)),
			rule.id,
			controller.effective_slot_count(rule.id)
		)

func _first_blank_die(profiles: Array[DieState]) -> StringName:
	for profile in profiles:
		if profile.engraving_id == &"":
			return profile.id
	return &""

func _area_definition(area_id: StringName) -> AreaDefinition:
	var catalog := AreaCatalog.new()
	match area_id:
		&"gold_corridor":
			return catalog.gold_corridor()
		&"mirror_hall":
			return catalog.mirror_hall()
		&"faceless_hub":
			return catalog.faceless_hub()
	return null
