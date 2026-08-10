extends "res://tests/test_case.gd"

func run() -> void:
	_test_runtime_deck_accepts_fifteen_cards()
	_test_all_failed_round_gets_consolation_and_next_calibration()
	_test_split_undo_quotas()
	_test_score_breakdown_reconciles()
	_test_dealer_intel_card_output_is_doubled()

func _test_runtime_deck_accepts_fifteen_cards() -> void:
	var ids := CardCatalog.new().starter_ids()
	ids.append_array(CardCatalog.new().shop_ids().slice(0, 3))
	var deck := CardDeck.new()
	deck.start_encounter(ids, RunRng.new(1515))
	var exposed: Array[StringName] = []
	for round_index in range(3):
		exposed.append_array(deck.draw_round())
	assert_equal(exposed.size(), 12, "a fifteen-card deck should still draw four cards for three rounds")
	assert_equal(deck.snapshot_draw_pile().size(), 3, "three cards should remain unseen")

func _test_all_failed_round_gets_consolation_and_next_calibration() -> void:
	var setup := EncounterRunSetup.new()
	setup.deck_ids = CardCatalog.new().starter_ids()
	setup.encounter = SingleEncounterFixture.make_encounter()
	setup.prepare_shop_offers = false
	var session := ThreeRoundEncounterSession.new(CardCatalog.new(), 5050, 0, setup)
	assert_true(session.start().accepted, "consolation fixture should start")
	var report := session.current_session.commit()
	assert_equal(report.passed_rule_count, 0, "empty assignment should pass no table")
	assert_equal(report.total, 5, "an all-failed round should receive five points")
	assert_true(report.consolation_awarded, "report should expose the consolation")
	assert_true(session.accept_committed_report(report).accepted, "consolation report should be accepted")
	assert_true(session.advance_round().accepted, "fixture should advance")
	assert_equal(
		session.current_session.controller.state.calibration_points,
		3,
		"the next round should start with one extra calibration"
	)

func _test_split_undo_quotas() -> void:
	var state := RoundState.new()
	state.dice.append(DieState.new(&"d1", 3))
	var controller := RoundController.new(
		state,
		EncounterDefinition.new(),
		null,
		null,
		[],
		RoundController.UndoMode.SPLIT
	)
	assert_true(controller.assign_die(&"d1", &"left", 1).accepted, "placement should succeed")
	assert_true(controller.undo(), "placement should be freely undoable")
	assert_equal(controller.placement_undo_copy(), "落子不限", "placement should not consume a quota")
	assert_true(controller.adjust_die(&"d1", 1).accepted, "calibration should succeed")
	assert_true(controller.undo(), "first calibration undo should succeed")
	assert_equal(controller.calibration_undos_remaining(), 0, "calibration quota should be spent")
	assert_true(controller.adjust_die(&"d1", 1).accepted, "calibration can be performed again")
	assert_false(controller.undo(), "a second calibration undo should reject")

func _test_score_breakdown_reconciles() -> void:
	var report := RoundResolver.new().resolve(RoundState.new(), EncounterDefinition.new())
	var categorized_total := 0
	for value in report.score_breakdown.values():
		categorized_total += int(value)
	assert_equal(categorized_total, report.total, "all score categories must reconcile to total")
	assert_equal(report.score_breakdown.size(), 8, "the ledger should always expose eight categories")

func _test_dealer_intel_card_output_is_doubled() -> void:
	var area := AreaRunSession.new(8181, AreaCatalog.new().gold_corridor())
	assert_true(area.start().accepted, "dealer intel fixture should start")
	var setup := EncounterRunSetup.new()
	setup.deck_ids = area.deck_ids.duplicate()
	setup.encounter = SingleEncounterFixture.make_encounter()
	setup.prepare_shop_offers = false
	setup.resolution_context = ResolutionContext.new(
		area.dealer_catalog.find_dealer(area.area_definition.dealer_id),
		area.engraving_catalog
	)
	area.encounter_session = ThreeRoundEncounterSession.new(
		area.card_catalog,
		8181,
		0,
		setup
	)
	assert_true(area.encounter_session.start().accepted, "dealer fixture should start")
	area.phase = AreaRunSession.Phase.DEALER
	var balance_before := area.intel_tickets
	for round_index in range(3):
		var report := area.encounter_session.current_session.commit()
		report.intel_delta = 1
		assert_true(area.accept_encounter_report(report).accepted, "dealer report should settle")
		if round_index < 2:
			assert_true(area.advance_encounter_round().accepted, "dealer should advance")
	assert_equal(area.intel_tickets, balance_before + 6, "dealer intel output should pay double")
	assert_equal(area.dealer_summary["intel_card_base"], 3, "summary keeps original output")
	assert_equal(area.dealer_summary["intel_card_awarded"], 6, "summary keeps doubled payout")
