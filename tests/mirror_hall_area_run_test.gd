extends "res://tests/test_case.gd"

const SEED := 20260727

func run() -> void:
	_test_mirror_area_starts_with_fixed_build()
	_test_all_route_combinations_complete()
	_test_same_seed_replays_full_completion()
	_test_restart_restores_fixed_build()
	_test_invalid_definition_is_atomic()
	_test_shop_shortage_is_atomic()
	_test_mismatched_report_is_atomic()

func _test_mirror_area_starts_with_fixed_build() -> void:
	var area := _new_mirror_run()
	assert_true(area.start().accepted, "mirror area should start")
	assert_equal(area.phase, AreaRunSession.Phase.ROUTE_CHOICE, "start opens routes")
	assert_equal(area.deck_ids, area.area_definition.starting_deck_ids, "deck is fixed")
	assert_equal(area.intel_tickets, 6, "tickets are fixed")
	assert_equal(area.current_route_ids().size(), 2, "first route offers two rooms")
	var d3: DieState = area.die_profiles.filter(
		func(die: DieState) -> bool: return die.id == &"d3"
	)[0]
	assert_equal(d3.engraving_id, &"engraving_bridge", "d3 should be pre-engraved")
	assert_equal(d3.engraved_face, 4, "engraving face should be four")

func _test_all_route_combinations_complete() -> void:
	var combinations := [
		[&"mirror_room_reverse_drill", &"mirror_room_echo_bridge"],
		[&"mirror_room_reverse_drill", &"mirror_room_symmetric_page"],
		[&"mirror_room_double_ledger", &"mirror_room_echo_bridge"],
		[&"mirror_room_double_ledger", &"mirror_room_symmetric_page"],
	]
	for combination in combinations:
		var area := _complete_run(combination[0], combination[1])
		assert_equal(area.phase, AreaRunSession.Phase.COMPLETE, "%s completes" % [combination])
		var summary := area.completion_snapshot()
		assert_equal(summary.area_id, &"mirror_hall", "summary identifies mirror hall")
		assert_equal(summary.deck_ids.size(), 12, "summary keeps twelve cards")
		assert_equal(summary.die_profiles.size(), 6, "summary keeps six dice")
		assert_equal(summary.rooms.size(), 2, "summary keeps both rooms")
		assert_equal(summary.dealer.id, &"dealer_mirror_lady", "summary keeps Mirror Lady")
		assert_equal(summary.rng_state, area.run_rng.snapshot_state(), "summary keeps RNG")

func _test_same_seed_replays_full_completion() -> void:
	var first := _complete_run(
		&"mirror_room_reverse_drill",
		&"mirror_room_symmetric_page"
	)
	var second := _complete_run(
		&"mirror_room_reverse_drill",
		&"mirror_room_symmetric_page"
	)
	assert_equal(first.engraving_offer_ids, second.engraving_offer_ids, "offers replay")
	assert_equal(
		first.completion_snapshot(),
		second.completion_snapshot(),
		"same operation sequence should replay the complete snapshot"
	)

func _test_restart_restores_fixed_build() -> void:
	var area := _complete_run(
		&"mirror_room_double_ledger",
		&"mirror_room_echo_bridge"
	)
	assert_true(area.restart().accepted, "completed mirror area should restart")
	assert_equal(area.phase, AreaRunSession.Phase.ROUTE_CHOICE, "restart opens first routes")
	assert_equal(area.deck_ids, area.area_definition.starting_deck_ids, "restart restores deck")
	assert_equal(area.intel_tickets, 6, "restart restores tickets")
	var d3: DieState = area.die_profiles.filter(
		func(die: DieState) -> bool: return die.id == &"d3"
	)[0]
	assert_equal(d3.engraving_id, &"engraving_bridge", "restart restores bridge")
	assert_equal(d3.engraved_face, 4, "restart restores bridge face")

func _test_invalid_definition_is_atomic() -> void:
	var invalid := AreaCatalog.new().mirror_hall().duplicate(true) as AreaDefinition
	invalid.starting_deck_ids[1] = invalid.starting_deck_ids[0]
	var area := AreaRunSession.new(SEED, invalid)
	assert_false(area.start().accepted, "duplicate starting card should reject")
	assert_equal(area.phase, AreaRunSession.Phase.NOT_STARTED, "invalid start keeps phase")
	assert_true(area.run_rng == null, "invalid start should not create or consume RNG")
	assert_equal(area.deck_ids, [], "invalid start keeps deck empty")

func _test_shop_shortage_is_atomic() -> void:
	var invalid_shop := AreaCatalog.new().mirror_hall().duplicate(true) as AreaDefinition
	invalid_shop.shop_offer_ids = invalid_shop.starting_deck_ids.slice(0, 3)
	var area := AreaRunSession.new(SEED, invalid_shop)
	assert_false(area.start().accepted, "market with fewer than six off-deck cards should reject")
	assert_equal(area.phase, AreaRunSession.Phase.NOT_STARTED, "shortage keeps initial phase")
	assert_true(area.run_rng == null, "shortage should not create or consume RNG")
	assert_true(area.market_ids.is_empty(), "shortage should not commit a market")

func _test_mismatched_report_is_atomic() -> void:
	var area := _new_mirror_run()
	assert_true(area.start().accepted, "mismatch fixture should start")
	assert_true(area.select_route(area.current_route_ids()[0]).accepted, "fixture selects")
	var before := _snapshot(area)
	assert_false(
		area.accept_encounter_report(ResolutionReport.new()).accepted,
		"foreign report should reject"
	)
	assert_equal(_snapshot(area), before, "foreign report should preserve state and RNG")

func _complete_run(
	first_room_id: StringName,
	second_room_id: StringName
) -> AreaRunSession:
	var area := _new_mirror_run()
	assert_true(area.start().accepted, "completion fixture starts")
	for room_id in [first_room_id, second_room_id]:
		assert_true(room_id in area.current_route_ids(), "chosen room should be offered")
		assert_true(area.select_route(room_id).accepted, "chosen route selects")
		_complete_current_encounter(area)
		assert_true(area.open_shop().accepted, "shop opens")
		assert_equal(area.shop_session.offer_ids.size(), 3, "shop has three offers")
		assert_true(
			area.shop_session.purchase(
				area.shop_session.offer_ids[0],
				area.shop_session.deck_ids[0]
			).accepted,
			"one deterministic replacement succeeds"
		)
		assert_true(area.leave_shop().accepted, "shop settles")

	assert_equal(area.phase, AreaRunSession.Phase.DEALER, "second shop opens dealer")
	assert_equal(
		area.encounter_session.setup.resolution_context.dealer.id,
		&"dealer_mirror_lady",
		"dealer context should be Mirror Lady"
	)
	_complete_current_encounter(area)
	assert_equal(area.phase, AreaRunSession.Phase.ENGRAVING_REWARD, "dealer opens reward")
	assert_equal(area.engraving_offer_ids.size(), 3, "reward offers three engravings")
	assert_equal(_unique_count(area.engraving_offer_ids), 3, "reward offers are unique")
	for engraving_id in area.engraving_offer_ids:
		assert_true(
			engraving_id in area.area_definition.engraving_offer_ids,
			"reward should stay inside mirror pool"
		)
	assert_true(
		area.select_engraving(area.engraving_offer_ids[0]).accepted,
		"reward selection succeeds"
	)
	assert_true(area.install_selected_engraving(&"d1", 2).accepted, "reward installs")
	return area

func _complete_current_encounter(area: AreaRunSession) -> void:
	area.encounter_session.target_total = 0
	for round_index in range(ThreeRoundEncounterSession.ROUND_COUNT):
		var report := area.encounter_session.current_session.commit()
		assert_true(area.accept_encounter_report(report).accepted, "report should be accepted")
		if round_index < ThreeRoundEncounterSession.ROUND_COUNT - 1:
			assert_true(area.advance_encounter_round().accepted, "next round should begin")

func _new_mirror_run() -> AreaRunSession:
	return AreaRunSession.new(SEED, AreaCatalog.new().mirror_hall())

func _snapshot(area: AreaRunSession) -> Dictionary:
	return {
		"phase": area.phase,
		"rng": area.run_rng.snapshot_state() if area.run_rng != null else 0,
		"routes": area.current_route_ids(),
		"selected": area.selected_room_ids.duplicate(),
		"deck": area.deck_ids.duplicate(),
		"tickets": area.intel_tickets,
		"offers": area.engraving_offer_ids.duplicate(),
	}

func _unique_count(ids: Array[StringName]) -> int:
	var unique: Dictionary = {}
	for id in ids:
		unique[id] = true
	return unique.size()
