extends "res://tests/test_case.gd"

func run() -> void:
	var catalog := CardCatalog.new()
	var inherited_deck := catalog.starter_ids()
	inherited_deck[0] = catalog.shop_ids()[0]

	var first_rng := RunRng.new(20260726)
	var first_snapshot := first_rng.snapshot_state()
	var first := _play_configured(first_rng, inherited_deck)
	assert_equal(first.intel, 0, "configured success reward should remain zero")
	assert_equal(first.offers, [], "configured encounter should not prepare shop offers")
	assert_equal(first.deck, inherited_deck, "configured deck should be inherited exactly")
	assert_true(
		first_rng.snapshot_state() != first_snapshot,
		"configured encounter should advance injected RNG"
	)

	var replay_rng := RunRng.new(999)
	replay_rng.restore_state(first_snapshot)
	var replay := _play_configured(replay_rng, inherited_deck)
	assert_equal(replay.hands, first.hands, "restored RNG should replay hands")
	assert_equal(replay.dice, first.dice, "restored RNG should replay dice")

	var old := ThreeRoundEncounterSession.new(catalog, 20260726, 0)
	assert_true(old.start().accepted, "legacy constructor should still start")
	_commit_three_empty_rounds(old)
	assert_equal(old.intel_tickets, 2, "legacy constructor should keep ticket reward")
	assert_equal(old.shop_offer_ids.size(), 3, "legacy constructor should prepare shop")

	var invalid_rng := RunRng.new(77)
	var invalid_snapshot := invalid_rng.snapshot_state()
	var invalid_setup := EncounterRunSetup.new()
	invalid_setup.run_rng = invalid_rng
	invalid_setup.deck_ids = inherited_deck
	invalid_setup.resolution_context = ResolutionContext.new(
		null,
		EngravingCatalog.new()
	)
	invalid_setup.die_profiles = _profiles_with_anchor()
	invalid_setup.die_profiles[0].engraving_id = &"missing_engraving"
	var invalid := ThreeRoundEncounterSession.new(catalog, 77, 0, invalid_setup)
	assert_false(invalid.start().accepted, "unknown engraving profile should be rejected")
	assert_equal(
		invalid_rng.snapshot_state(),
		invalid_snapshot,
		"invalid setup should fail before consuming RNG"
	)

func _play_configured(rng: RunRng, inherited_deck: Array[StringName]) -> Dictionary:
	var setup := EncounterRunSetup.new()
	setup.run_rng = rng
	setup.deck_ids = inherited_deck
	setup.encounter = SingleEncounterFixture.make_encounter()
	setup.resolution_context = ResolutionContext.new(
		DealerCatalog.new().iron_abacus(),
		EngravingCatalog.new()
	)
	setup.success_intel_reward = 0
	setup.prepare_shop_offers = false
	setup.die_profiles = _profiles_with_anchor()

	var session := ThreeRoundEncounterSession.new(
		CardCatalog.new(),
		20260726,
		0,
		setup
	)
	assert_true(session.start().accepted, "configured session should start")
	assert_equal(
		session.current_session.controller.resolution_context.dealer.id,
		&"dealer_iron_abacus",
		"dealer context should reach the round"
	)
	var d1 := session.current_session.controller.state.find_die(&"d1")
	assert_equal(d1.engraving_id, &"engraving_anchor", "profile should copy engraving")
	assert_equal(d1.engraved_face, 4, "profile should copy engraved face")

	var hands: Array = []
	var dice: Array = []
	for round_index in range(ThreeRoundEncounterSession.ROUND_COUNT):
		hands.append(session.current_hand_ids.duplicate())
		var values: Array[int] = []
		for die in session.current_session.controller.state.dice:
			values.append(die.rolled_value)
		dice.append(values)
		var report := session.current_session.commit()
		assert_true(
			session.accept_committed_report(report).accepted,
			"configured report should be accepted"
		)
		if round_index < ThreeRoundEncounterSession.ROUND_COUNT - 1:
			assert_true(session.advance_round().accepted, "configured round should advance")
	return {
		"hands": hands,
		"dice": dice,
		"deck": session.starter_deck_ids.duplicate(),
		"intel": session.intel_tickets,
		"offers": session.shop_offer_ids.duplicate(),
	}

func _profiles_with_anchor() -> Array[DieState]:
	var profiles: Array[DieState] = []
	for index in range(1, 7):
		profiles.append(DieState.new(
			StringName("d%d" % index),
			1,
			&"engraving_anchor" if index == 1 else &"",
			4 if index == 1 else 0
		))
	return profiles

func _commit_three_empty_rounds(session: ThreeRoundEncounterSession) -> void:
	for round_index in range(ThreeRoundEncounterSession.ROUND_COUNT):
		var report := session.current_session.commit()
		assert_true(session.accept_committed_report(report).accepted, "report should be accepted")
		if round_index < ThreeRoundEncounterSession.ROUND_COUNT - 1:
			assert_true(session.advance_round().accepted, "round should advance")
