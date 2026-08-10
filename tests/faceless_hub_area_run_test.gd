extends "res://tests/test_case.gd"

const SEED := 20260727

func run() -> void:
	_test_fixed_build_starts()
	_test_all_route_combinations_complete()

func _test_fixed_build_starts() -> void:
	var area := _new_run()
	assert_true(area.start().accepted, "faceless area should start")
	assert_equal(area.market_ids.size(), 34, "faceless market should contain thirty-four cards")
	assert_equal(area.intel_tickets, 8, "fixed build starts with eight intel")
	assert_equal(area.deck_ids, area.area_definition.starting_deck_ids, "deck is fixed")
	var d3 := area.die_profiles.filter(
		func(die: DieState) -> bool: return die.id == &"d3"
	)[0] as DieState
	assert_equal(d3.engraving_id, &"engraving_backflow_bridge", "d3 has backflow")
	assert_equal(d3.engraved_face, 4, "backflow face is four")

func _test_all_route_combinations_complete() -> void:
	var combinations := [
		[&"faceless_room_crossed_archive", &"faceless_room_single_hand_agenda"],
		[&"faceless_room_crossed_archive", &"faceless_room_three_seat_protocol"],
		[&"faceless_room_reverse_index", &"faceless_room_single_hand_agenda"],
		[&"faceless_room_reverse_index", &"faceless_room_three_seat_protocol"],
	]
	for combination in combinations:
		var area := _new_run()
		assert_true(area.start().accepted, "route fixture starts")
		for room_id in combination:
			assert_true(room_id in area.current_route_ids(), "selected room is offered")
			assert_true(area.select_route(room_id).accepted, "selected route starts")
			_complete_normal_encounter(area)
			assert_true(area.open_shop().accepted, "shop opens after room")
			assert_equal(area.shop_session.offer_ids.size(), 3, "shop exposes three cards")
			if area.room_index == 0:
				assert_equal(
					area.current_shop_intel().kind,
					ShopIntelSnapshot.Kind.ROUTE_PAIR,
					"first shop exposes route intel"
				)
			else:
				var dealer_intel: ShopIntelSnapshot = area.current_shop_intel()
				assert_equal(
					dealer_intel.kind,
					ShopIntelSnapshot.Kind.DEALER,
					"second shop exposes dealer intel"
				)
				assert_equal(
					dealer_intel.dealer_id,
					&"dealer_faceless_master",
					"faceless dealer intel identifies the owner"
				)
			assert_true(area.leave_shop().accepted, "shop can be left without gambling")

		assert_equal(area.phase, AreaRunSession.Phase.DEALER, "second shop starts dealer")
		var session := area.encounter_session
		session.target_total = 0
		_commit_current_round(area)
		assert_true(area.advance_encounter_round().accepted, "advance to reverse round")
		_commit_current_round(area)
		assert_equal(
			session.status,
			ThreeRoundEncounterSession.Status.AWAITING_RESTRICTION,
			"round two waits for a public choice"
		)
		assert_true(
			area.choose_dealer_restriction(&"solo_verdict").accepted,
			"choose operation restriction"
		)
		assert_equal(session.current_round, 3, "choice creates third round")
		_commit_current_round(area)
		assert_equal(area.phase, AreaRunSession.Phase.ENGRAVING_REWARD, "dealer opens reward")
		assert_equal(area.engraving_offer_ids.size(), 2, "reward offers two engravings")
		assert_equal(area.rare_card_offer_ids.size(), 1, "reward offers one rare card")
		assert_true(area.select_engraving(area.engraving_offer_ids[0]).accepted, "select reward")
		assert_true(area.install_selected_engraving(&"d1", 2).accepted, "install reward")
		assert_equal(area.phase, AreaRunSession.Phase.COMPLETE, "faceless run completes")
		var snapshot := area.completion_snapshot()
		assert_equal(snapshot.area_id, &"faceless_hub", "snapshot identifies faceless hub")
		assert_equal(snapshot.rooms.size(), 2, "snapshot keeps two rooms")
		assert_equal(snapshot.dealer.id, &"dealer_faceless_master", "snapshot keeps dealer")
		assert_true(snapshot.has("services"), "snapshot exposes service records")
		assert_true(snapshot.services is Array, "service records use an array")

func _complete_normal_encounter(area: AreaRunSession) -> void:
	area.encounter_session.target_total = 0
	var round_total := area.encounter_session.round_count
	for round_index in range(round_total):
		_prepare_fixed_restriction(area.encounter_session.current_session.controller)
		_commit_current_round(area)
		if round_index < round_total - 1:
			assert_true(area.advance_encounter_round().accepted, "advance normal round")
	if area.phase == AreaRunSession.Phase.EVENT:
		_resolve_event(area)
	elif area.phase == AreaRunSession.Phase.CHOICE_ROOM:
		assert_true(
			area.resolve_choice_room(&"raise_target").accepted,
			"fixture choice room resolves"
		)
	elif area.phase == AreaRunSession.Phase.ENGRAVING_ROOM:
		assert_true(
			area.resolve_engraving_room().accepted,
			"fixture engraving room allows skip"
		)

func _resolve_event(area: AreaRunSession) -> void:
	var result: OperationResult
	match area.current_event_id:
		AreaRunSession.EVENT_DICE_ARTISAN:
			result = area.resolve_event(&"reroll", &"d1")
		AreaRunSession.EVENT_REST_STOP:
			result = area.resolve_event(&"rest")
		_:
			result = area.resolve_event(&"intel")
	assert_true(result.accepted, "fixture event resolves")

func _prepare_fixed_restriction(controller: RoundController) -> void:
	var restriction := controller.active_restriction
	if (
		restriction == null
		or restriction.operation
			!= FinalRestrictionDefinition.Operation.REQUIRE_ALL_TABLES_OCCUPIED
	):
		return
	for index in range(3):
		var rule := controller.encounter.rules[index]
		assert_true(
			controller.assign_die(
				StringName("d%d" % (index + 1)),
				rule.id,
				controller.effective_slot_count(rule.id)
			).accepted,
			"distribution fixture occupies every table"
		)

func _commit_current_round(area: AreaRunSession) -> void:
	var report := area.encounter_session.current_session.commit()
	assert_true(report.valid, "fixture report should commit")
	assert_true(area.accept_encounter_report(report).accepted, "area accepts report")

func _new_run() -> AreaRunSession:
	return AreaRunSession.new(SEED, AreaCatalog.new().faceless_hub())
