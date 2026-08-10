extends "res://tests/test_case.gd"

func run() -> void:
	_test_two_room_shop_loop()
	_test_area_market_and_future_intel()
	_test_same_seed_replays_route_shop_and_dealer_start()
	_test_all_route_combinations_complete()
	_test_failures_end_the_area()
	_test_restart_replays_from_seed()
	_test_same_seed_replays_full_completion()

func _test_area_market_and_future_intel() -> void:
	var area := AreaRunSession.new(20260729)
	assert_true(area.start().accepted, "shop-service area should start")
	assert_equal(area.market_ids.size(), 22, "gold market should contain twenty-two cards")
	assert_equal(_unique_count(area.market_ids), 22, "gold market should be unique")
	for card_id in area.deck_ids:
		assert_true(card_id in area.market_ids, "entry deck should belong to market")

	assert_true(area.select_route(area.current_route_ids()[0]).accepted, "first route selects")
	_complete_current_encounter(area)
	assert_true(area.open_shop().accepted, "first formal shop opens")
	var route_intel: ShopIntelSnapshot = area.current_shop_intel()
	assert_true(route_intel != null, "first shop should expose an intel snapshot")
	assert_equal(
		route_intel.kind,
		ShopIntelSnapshot.Kind.ROUTE_PAIR,
		"first shop should precompute route intel"
	)
	assert_equal(
		route_intel.validate(area.area_definition, area.dealer_catalog),
		"",
		"precomputed route intel should validate"
	)
	assert_true(area.shop_session.purchase_intel().accepted, "route intel purchase succeeds")
	assert_true(area.shop_session.refresh_offers().accepted, "first shop refresh succeeds")
	var rng_before_leave := area.run_rng.snapshot_state()
	var expected_routes: Array[StringName] = route_intel.route_ids.duplicate()
	assert_true(area.leave_shop().accepted, "first shop settles")
	assert_equal(area.current_route_ids(), expected_routes, "actual routes should match intel")
	assert_equal(
		area.run_rng.snapshot_state(),
		rng_before_leave,
		"first leave should not reshuffle the precomputed routes"
	)
	assert_equal(area.shop_service_history.size(), 2, "first services should transfer")

	assert_true(area.select_route(area.current_route_ids()[0]).accepted, "second route selects")
	_complete_current_encounter(area)
	assert_true(area.open_shop().accepted, "second formal shop opens")
	var dealer_intel: ShopIntelSnapshot = area.current_shop_intel()
	assert_equal(
		dealer_intel.kind,
		ShopIntelSnapshot.Kind.DEALER,
		"second shop should precompute dealer intel"
	)
	assert_equal(dealer_intel.dealer_id, &"dealer_iron_abacus", "intel identifies dealer")
	assert_equal(dealer_intel.dealer_target, 150, "intel identifies dealer target")
	assert_true(area.shop_session.purchase_intel().accepted, "dealer intel purchase succeeds")
	assert_true(area.leave_shop().accepted, "second shop settles")
	assert_equal(area.shop_service_history.size(), 3, "dealer intel should transfer")
	assert_equal(area.phase, AreaRunSession.Phase.DEALER, "second leave starts dealer")
	assert_equal(
		area.encounter_session.setup.resolution_context.dealer.id,
		dealer_intel.dealer_id,
		"actual dealer should match intel"
	)

func _test_two_room_shop_loop() -> void:
	var area := AreaRunSession.new(20260726)
	assert_true(area.start().accepted, "Gold Corridor should start")
	assert_equal(area.phase, AreaRunSession.Phase.ROUTE_CHOICE, "start opens first route")
	assert_equal(
		_sorted_ids(area.current_route_ids()),
		_sorted_ids(area.area_definition.first_route_ids),
		"first route should contain the fixed first group"
	)
	assert_equal(
		area.deck_ids,
		area.area_definition.starting_deck_ids,
		"start owns configured deck"
	)
	assert_equal(area.intel_tickets, 0, "start has no tickets")
	assert_equal(area.die_profiles.size(), 6, "start creates six die profiles")

	var before_invalid := _snapshot(area)
	assert_false(area.select_route(&"missing_room").accepted, "unknown route should reject")
	assert_equal(_snapshot(area), before_invalid, "invalid route should preserve full state")
	assert_false(area.open_shop().accepted, "shop cannot open before a room succeeds")

	var first_room_id: StringName = area.current_route_ids()[0]
	var first_room := area.area_definition.find_room(first_room_id)
	assert_true(area.select_route(first_room_id).accepted, "first route should select")
	assert_equal(area.phase, AreaRunSession.Phase.NORMAL_ROOM, "selection opens normal room")
	assert_equal(area.encounter_session.setup.encounter, first_room.encounter, "room rules should bind")
	assert_equal(area.encounter_session.target_total, first_room.target_total, "room target should bind")
	_complete_current_encounter(area)
	assert_equal(
		area.intel_tickets,
		first_room.success_intel_reward,
		"first room should award configured tickets once"
	)

	assert_true(area.open_shop().accepted, "first successful room should open shop")
	assert_equal(area.shop_session.offer_ids.size(), 3, "shop should show three offers")
	for offer_id in area.shop_session.offer_ids:
		assert_false(offer_id in area.deck_ids, "first-shop offers should be unowned")
	var first_offer: StringName = area.shop_session.offer_ids[0]
	var first_replaced: StringName = area.shop_session.deck_ids[0]
	var first_price := area.shop_session.card_price(first_offer)
	assert_true(
		area.shop_session.purchase(first_offer, first_replaced).accepted,
		"first shop replacement should succeed"
	)
	assert_true(area.leave_shop().accepted, "first shop should settle")
	assert_equal(area.phase, AreaRunSession.Phase.ROUTE_CHOICE, "first shop opens second route")
	assert_equal(
		_sorted_ids(area.current_route_ids()),
		_sorted_ids(area.area_definition.second_route_ids),
		"second route should contain the fixed second group"
	)
	assert_equal(area.shop_purchase_history.size(), 1, "first purchase should enter history")
	assert_true(first_offer in area.deck_ids, "settled first purchase should enter area deck")
	assert_true(first_replaced in area.deck_ids, "formal purchases append below the cap")

	var second_room_id: StringName = area.current_route_ids()[0]
	var second_room := area.area_definition.find_room(second_room_id)
	assert_true(area.select_route(second_room_id).accepted, "second route should select")
	_complete_current_encounter(area)
	assert_equal(
		area.intel_tickets,
		first_room.success_intel_reward - first_price
			+ second_room.success_intel_reward
			+ (
				1
				if area.event_history[-1].get("event_id", &"")
					== AreaRunSession.EVENT_MYSTERY_GAMBLE
				else 0
			),
		"second reward should add to the post-shop balance"
	)
	assert_true(area.open_shop().accepted, "second successful room should open shop")
	assert_equal(area.shop_session.offer_ids.size(), 3, "second shop should show three offers")
	for offer_id in area.shop_session.offer_ids:
		assert_false(offer_id in area.deck_ids, "second-shop offers should be unowned")
	var second_offer: StringName = area.shop_session.offer_ids[0]
	var second_replaced: StringName = area.shop_session.deck_ids[0]
	assert_true(
		area.shop_session.purchase(second_offer, second_replaced).accepted,
		"second shop replacement should succeed"
	)
	assert_true(area.leave_shop().accepted, "second shop should create dealer")
	assert_equal(area.phase, AreaRunSession.Phase.DEALER, "second shop enters Iron Abacus")
	assert_equal(area.shop_purchase_history.size(), 2, "both purchases should be recorded")
	assert_equal(area.deck_ids.size(), 14, "dealer deck should include both purchases")
	assert_equal(_unique_count(area.deck_ids), 14, "dealer deck should remain unique")
	assert_true(second_offer in area.deck_ids, "second purchase should reach dealer deck")
	assert_equal(
		area.encounter_session.setup.resolution_context.dealer.id,
		&"dealer_iron_abacus",
		"dealer encounter should use Iron Abacus"
	)

	var after_leave := _snapshot(area)
	assert_false(area.leave_shop().accepted, "duplicate shop leave should reject")
	assert_equal(_snapshot(area), after_leave, "duplicate shop leave should preserve state")

func _test_same_seed_replays_route_shop_and_dealer_start() -> void:
	var first := _drive_to_dealer(20260802)
	var second := _drive_to_dealer(20260802)
	assert_equal(first.selected_room_ids, second.selected_room_ids, "same seed selects same routes")
	assert_equal(first.completed_rooms, second.completed_rooms, "same rooms produce same totals")
	assert_equal(first.deck_ids, second.deck_ids, "same purchases produce same deck")
	assert_equal(first.intel_tickets, second.intel_tickets, "same run keeps same tickets")
	assert_equal(
		_history_signature(first.shop_purchase_history),
		_history_signature(second.shop_purchase_history),
		"same purchases produce same history"
	)
	assert_equal(
		first.encounter_session.current_hand_ids,
		second.encounter_session.current_hand_ids,
		"dealer first hand should replay"
	)
	assert_equal(
		_rolled_values(first.encounter_session),
		_rolled_values(second.encounter_session),
		"dealer first dice should replay"
	)
	assert_equal(
		first.run_rng.snapshot_state(),
		second.run_rng.snapshot_state(),
		"shared RNG state should replay"
	)

func _test_all_route_combinations_complete() -> void:
	var combinations: Array[Array] = [
		[&"gold_room_precise_steps", &"gold_room_narrow_ledger"],
		[&"gold_room_precise_steps", &"gold_room_parallel_proof"],
		[&"gold_room_even_split", &"gold_room_narrow_ledger"],
		[&"gold_room_even_split", &"gold_room_parallel_proof"],
	]
	for combination in combinations:
		var area := _drive_route_combination_to_dealer(
			20260901,
			combination[0],
			combination[1],
			true
		)
		_complete_current_encounter(area)
		assert_equal(
			area.phase,
			AreaRunSession.Phase.ENGRAVING_REWARD,
			"%s should reach engraving reward" % [combination]
		)
		assert_equal(area.engraving_offer_ids.size(), 2, "dealer should offer two engravings")
		assert_equal(area.rare_card_offer_ids.size(), 1, "dealer should offer one rare card")

		var before_invalid := _snapshot(area)
		assert_false(
			area.select_engraving(&"missing_engraving").accepted,
			"unknown engraving offer should reject"
		)
		assert_equal(_snapshot(area), before_invalid, "invalid engraving selection is atomic")

		var engraving_id: StringName = area.engraving_offer_ids[0]
		assert_true(area.select_engraving(engraving_id).accepted, "offered engraving selects")
		var before_install := _snapshot(area)
		assert_false(
			area.install_selected_engraving(&"missing_die", 2).accepted,
			"unknown engraving die should reject"
		)
		assert_equal(_snapshot(area), before_install, "failed engraving install is atomic")
		assert_true(
			area.install_selected_engraving(&"d1", 2).accepted,
			"valid engraving installation should complete area"
		)
		assert_equal(area.phase, AreaRunSession.Phase.COMPLETE, "installation completes area")
		var summary: Dictionary = area.completion_snapshot()
		assert_equal(summary.area_id, &"gold_corridor", "summary should identify the area")
		assert_equal(
			summary.rng_state,
			area.run_rng.snapshot_state(),
			"summary should preserve replay RNG state"
		)
		assert_equal(summary.rooms.size(), 2, "summary should contain two rooms")
		assert_equal(summary.purchases.size(), 2, "summary should contain two purchases")
		assert_equal(summary.deck_ids.size(), 14, "summary should contain final deck")
		assert_equal(summary.dealer.id, &"dealer_iron_abacus", "summary should contain dealer")
		assert_equal(summary.engraving_id, engraving_id, "summary should contain engraving")
		assert_equal(summary.die_id, &"d1", "summary should contain engraved die")
		assert_equal(summary.face, 2, "summary should contain engraved face")
		assert_equal(summary.die_profiles.size(), 6, "summary should preserve all die profiles")
		summary.deck_ids.clear()
		assert_equal(area.deck_ids.size(), 14, "summary data should be defensive")

func _test_failures_end_the_area() -> void:
	var first_room_failure := AreaRunSession.new(20261001)
	assert_true(first_room_failure.start().accepted, "first-failure fixture starts")
	assert_true(
		first_room_failure.select_route(first_room_failure.current_route_ids()[0]).accepted,
		"first-failure route selects"
	)
	_complete_current_encounter(first_room_failure, false)
	_assert_failed_without_boundary_retry(
		first_room_failure,
		AreaRunSession.Phase.NORMAL_ROOM,
		"first room failure"
	)

	var second_room_failure := AreaRunSession.new(20261002)
	assert_true(second_room_failure.start().accepted, "second-failure fixture starts")
	assert_true(
		second_room_failure.select_route(second_room_failure.current_route_ids()[0]).accepted,
		"first route selects"
	)
	_complete_current_encounter(second_room_failure)
	assert_true(second_room_failure.open_shop().accepted, "first shop opens")
	assert_true(second_room_failure.leave_shop().accepted, "first shop leaves")
	assert_true(
		second_room_failure.select_route(second_room_failure.current_route_ids()[0]).accepted,
		"second route selects"
	)
	_complete_current_encounter(second_room_failure, false)
	_assert_failed_without_boundary_retry(
		second_room_failure,
		AreaRunSession.Phase.NORMAL_ROOM,
		"second room failure"
	)

	var dealer_failure := _drive_route_combination_to_dealer(
		20261003,
		&"gold_room_precise_steps",
		&"gold_room_narrow_ledger",
		false
	)
	_complete_current_encounter(dealer_failure, false)
	_assert_failed_without_boundary_retry(
		dealer_failure,
		AreaRunSession.Phase.DEALER,
		"dealer failure"
	)

func _test_restart_replays_from_seed() -> void:
	var seed_value := 20261101
	var completed := _drive_route_combination_to_dealer(
		seed_value,
		&"gold_room_even_split",
		&"gold_room_parallel_proof",
		true
	)
	_complete_current_encounter(completed)
	assert_true(
		completed.select_engraving(completed.engraving_offer_ids[0]).accepted,
		"restart fixture engraving selects"
	)
	assert_true(
		completed.install_selected_engraving(&"d3", 5).accepted,
		"restart fixture completes"
	)
	assert_true(completed.restart().accepted, "completed area should restart")

	var fresh := AreaRunSession.new(seed_value)
	assert_true(fresh.start().accepted, "fresh comparison should start")
	assert_equal(completed.current_route_ids(), fresh.current_route_ids(), "route order replays")
	var replay_room_id: StringName = completed.current_route_ids()[0]
	assert_true(completed.select_route(replay_room_id).accepted, "restarted route selects")
	assert_true(fresh.select_route(replay_room_id).accepted, "fresh route selects")
	assert_equal(
		completed.encounter_session.current_hand_ids,
		fresh.encounter_session.current_hand_ids,
		"restarted first hand should replay"
	)
	assert_equal(
		_rolled_values(completed.encounter_session),
		_rolled_values(fresh.encounter_session),
		"restarted first dice should replay"
	)
	assert_equal(completed.shop_purchase_history.size(), 0, "restart clears purchase history")
	assert_equal(completed.selected_room_ids.size(), 1, "only replayed route remains selected")
	assert_equal(completed.selected_engraving_id, &"", "restart clears engraving selection")
	assert_equal(completed.installed_die_id, &"", "restart clears engraved die")

func _test_same_seed_replays_full_completion() -> void:
	var first := _complete_fixed_run(20261201)
	var second := _complete_fixed_run(20261201)
	assert_equal(
		first.engraving_offer_ids,
		second.engraving_offer_ids,
		"same seed should replay engraving offers"
	)
	assert_equal(
		first.completion_snapshot(),
		second.completion_snapshot(),
		"same complete operation sequence should replay summary"
	)
	assert_equal(
		first.run_rng.snapshot_state(),
		second.run_rng.snapshot_state(),
		"same complete operation sequence should replay RNG"
	)

func _complete_fixed_run(seed_value: int) -> AreaRunSession:
	var area := _drive_route_combination_to_dealer(
		seed_value,
		&"gold_room_precise_steps",
		&"gold_room_parallel_proof",
		true
	)
	_complete_current_encounter(area)
	assert_true(area.select_engraving(area.engraving_offer_ids[0]).accepted, "offer selects")
	assert_true(area.install_selected_engraving(&"d4", 3).accepted, "engraving installs")
	return area

func _drive_to_dealer(seed_value: int) -> AreaRunSession:
	var area := AreaRunSession.new(seed_value)
	assert_true(area.start().accepted, "determinism fixture should start")
	for room_number in range(2):
		var room_id: StringName = area.current_route_ids()[0]
		assert_true(area.select_route(room_id).accepted, "fixture route should select")
		_complete_current_encounter(area)
		assert_true(area.open_shop().accepted, "fixture shop should open")
		var offer_id: StringName = area.shop_session.offer_ids[0]
		var replaced_id: StringName = area.shop_session.deck_ids[0]
		assert_true(area.shop_session.purchase(offer_id, replaced_id).accepted, "fixture buys")
		assert_true(area.leave_shop().accepted, "fixture shop should settle")
		if room_number == 0:
			assert_equal(area.phase, AreaRunSession.Phase.ROUTE_CHOICE, "fixture continues")
	return area

func _drive_route_combination_to_dealer(
	seed_value: int,
	first_room_id: StringName,
	second_room_id: StringName,
	purchase_each_shop: bool
) -> AreaRunSession:
	var area := AreaRunSession.new(seed_value)
	assert_true(area.start().accepted, "combination fixture should start")
	for room_id in [first_room_id, second_room_id]:
		assert_true(room_id in area.current_route_ids(), "chosen room should be offered")
		assert_true(area.select_route(room_id).accepted, "chosen room should select")
		_complete_current_encounter(area)
		assert_true(area.open_shop().accepted, "combination shop should open")
		if purchase_each_shop:
			assert_true(
				area.shop_session.purchase(
					area.shop_session.offer_ids[0],
					area.shop_session.deck_ids[0]
				).accepted,
				"combination shop should purchase"
			)
		assert_true(area.leave_shop().accepted, "combination shop should settle")
	return area

func _complete_current_encounter(
	area: AreaRunSession,
	force_success: bool = true
) -> void:
	if force_success:
		area.encounter_session.target_total = 0
	var round_total := area.encounter_session.round_count
	for round_index in range(round_total):
		var report := area.encounter_session.current_session.commit()
		assert_true(area.accept_encounter_report(report).accepted, "formal report should be accepted")
		if round_index < round_total - 1:
			assert_true(area.advance_encounter_round().accepted, "next round should begin")
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
	assert_true(result.accepted, "fixture event resolves")

func _snapshot(area: AreaRunSession) -> Dictionary:
	return {
		"phase": area.phase,
		"rng": area.run_rng.snapshot_state() if area.run_rng != null else 0,
		"room_index": area.room_index,
		"route_ids": area.route_ids.duplicate(),
		"selected": area.selected_room_ids.duplicate(),
		"completed": area.completed_rooms.duplicate(true),
		"deck": area.deck_ids.duplicate(),
		"tickets": area.intel_tickets,
		"profiles": _profile_signature(area.die_profiles),
		"history": _history_signature(area.shop_purchase_history),
		"services": _service_signature(area.shop_service_history),
		"market": area.market_ids.duplicate(),
		"pending_routes": area.pending_route_ids.duplicate(),
		"engraving_offers": area.engraving_offer_ids.duplicate(),
		"selected_engraving": area.selected_engraving_id,
		"installed_die": area.installed_die_id,
		"installed_face": area.installed_face,
		"failure_origin": area.failure_origin,
	}

func _service_signature(history: Array[ShopServiceRecord]) -> Array:
	var signature: Array = []
	for record in history:
		signature.append([
			record.shop_index,
			record.service_type,
			record.price,
			record.intel_kind,
		])
	return signature

func _assert_failed_without_boundary_retry(
	area: AreaRunSession,
	expected_origin: AreaRunSession.Phase,
	message: String
) -> void:
	assert_equal(area.phase, AreaRunSession.Phase.FAILED, "%s should end area" % message)
	assert_equal(area.failure_origin, expected_origin, "%s should record origin" % message)
	assert_false(area.has_method("retry_dealer"), "%s should not expose dealer retry" % message)
	assert_false(
		area.has_method("retry_verification"),
		"%s should not expose verification retry" % message
	)
	var before := _snapshot(area)
	assert_false(area.open_shop().accepted, "%s cannot open shop afterward" % message)
	assert_equal(_snapshot(area), before, "%s rejected continuation should be atomic" % message)

func _history_signature(history: Array[ShopPurchaseRecord]) -> Array:
	var signature: Array = []
	for record in history:
		signature.append([record.offer_id, record.replaced_id, record.price])
	return signature

func _profile_signature(profiles: Array[DieState]) -> Array:
	var signature: Array = []
	for profile in profiles:
		signature.append([profile.id, profile.engraving_id, profile.engraved_face])
	return signature

func _rolled_values(session: ThreeRoundEncounterSession) -> Array[int]:
	var values: Array[int] = []
	for die in session.current_session.controller.state.dice:
		values.append(die.rolled_value)
	return values

func _sorted_ids(ids: Array[StringName]) -> Array[StringName]:
	var result := ids.duplicate()
	result.sort()
	return result

func _unique_count(ids: Array[StringName]) -> int:
	var unique: Dictionary = {}
	for id in ids:
		unique[id] = true
	return unique.size()
