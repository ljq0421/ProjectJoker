extends "res://tests/test_case.gd"

func run() -> void:
	_test_two_room_shop_loop()
	_test_same_seed_replays_route_shop_and_dealer_start()

func _test_two_room_shop_loop() -> void:
	var area := AreaRunSession.new(20260726)
	assert_true(area.start().accepted, "Gold Corridor should start")
	assert_equal(area.phase, AreaRunSession.Phase.ROUTE_CHOICE, "start opens first route")
	assert_equal(
		_sorted_ids(area.current_route_ids()),
		_sorted_ids(area.room_catalog.first_route_ids()),
		"first route should contain the fixed first group"
	)
	assert_equal(area.deck_ids, area.card_catalog.starter_ids(), "start owns starter deck")
	assert_equal(area.intel_tickets, 0, "start has no tickets")
	assert_equal(area.die_profiles.size(), 6, "start creates six die profiles")

	var before_invalid := _snapshot(area)
	assert_false(area.select_route(&"missing_room").accepted, "unknown route should reject")
	assert_equal(_snapshot(area), before_invalid, "invalid route should preserve full state")
	assert_false(area.open_shop().accepted, "shop cannot open before a room succeeds")

	var first_room_id: StringName = area.current_route_ids()[0]
	var first_room := area.room_catalog.find_room(first_room_id)
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
	assert_true(
		area.shop_session.purchase(first_offer, first_replaced).accepted,
		"first shop replacement should succeed"
	)
	assert_true(area.leave_shop().accepted, "first shop should settle")
	assert_equal(area.phase, AreaRunSession.Phase.ROUTE_CHOICE, "first shop opens second route")
	assert_equal(
		_sorted_ids(area.current_route_ids()),
		_sorted_ids(area.room_catalog.second_route_ids()),
		"second route should contain the fixed second group"
	)
	assert_equal(area.shop_purchase_history.size(), 1, "first purchase should enter history")
	assert_true(first_offer in area.deck_ids, "settled first purchase should enter area deck")
	assert_false(first_replaced in area.deck_ids, "settled outgoing card should leave area deck")

	var second_room_id: StringName = area.current_route_ids()[0]
	var second_room := area.room_catalog.find_room(second_room_id)
	assert_true(area.select_route(second_room_id).accepted, "second route should select")
	_complete_current_encounter(area)
	assert_equal(
		area.intel_tickets,
		first_room.success_intel_reward - ShopSession.CARD_PRICE
			+ second_room.success_intel_reward,
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
	assert_equal(area.deck_ids.size(), 12, "dealer deck should keep twelve cards")
	assert_equal(_unique_count(area.deck_ids), 12, "dealer deck should remain unique")
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

func _complete_current_encounter(area: AreaRunSession) -> void:
	area.encounter_session.target_total = 0
	for round_index in range(ThreeRoundEncounterSession.ROUND_COUNT):
		var report := area.encounter_session.current_session.commit()
		assert_true(area.accept_encounter_report(report).accepted, "formal report should be accepted")
		if round_index < ThreeRoundEncounterSession.ROUND_COUNT - 1:
			assert_true(area.advance_encounter_round().accepted, "next round should begin")

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
	}

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
