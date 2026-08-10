extends "res://tests/test_case.gd"

func run() -> void:
	_test_index_cards_are_valid_shop_cards()
	_test_retained_card_precedes_queued_search()
	_test_search_card_is_blocked_on_final_round()

func _test_index_cards_are_valid_shop_cards() -> void:
	var catalog := CardCatalog.new()
	assert_true(catalog.validate().is_empty(), "catalog should accept eight shop cards")
	var dice_index := catalog.find_card(&"shop_dice_index")
	var chain_index := catalog.find_card(&"shop_chain_index")
	assert_true(dice_index != null, "dice index should load")
	assert_true(chain_index != null, "chain index should load")
	assert_equal(dice_index.suit, CardDefinition.Suit.CLUBS, "dice index should be clubs")
	assert_equal(chain_index.suit, CardDefinition.Suit.SPADES, "chain index should be spades")

func _test_retained_card_precedes_queued_search() -> void:
	var catalog := CardCatalog.new()
	var setup := EncounterRunSetup.new()
	setup.round_count = 2
	setup.deck_ids.assign(catalog.starter_ids())
	var run := ThreeRoundEncounterSession.new(catalog, 3026, 999, setup)
	assert_true(run.start().accepted, "two-round test run should start")
	var dice_index := catalog.find_card(&"shop_dice_index")
	var retained := catalog.find_card(&"starter_reverse")
	run.current_session.hand.assign([dice_index, retained])
	run.current_hand_ids.assign([dice_index.id, retained.id])
	run._deck.restore_draw_pile([
		&"starter_link",
		&"starter_nudge_up_2",
		&"starter_map_1",
		&"starter_repeat_1",
	])
	assert_true(run.current_session.activate_card(0), "index card should play before final round")
	var report := run.current_session.commit()
	assert_true(run.accept_committed_report(report).accepted, "round should settle")
	assert_true(run.retain_card(retained.id).accepted, "unused card should be retained")
	assert_true(run.advance_round().accepted, "next round should start")
	assert_equal(run.current_hand_ids[0], retained.id, "retained card should be first")
	assert_equal(
		run.current_hand_ids[1],
		&"starter_nudge_up_2",
		"queued dice search should precede normal draw"
	)

func _test_search_card_is_blocked_on_final_round() -> void:
	var catalog := CardCatalog.new()
	var state := RoundState.new()
	var hand: Array[CardDefinition] = [catalog.find_card(&"shop_chain_index")]
	var session := SingleEncounterSession.new(
		state,
		SingleEncounterFixture.make_encounter(),
		hand,
		ResolutionContext.empty(),
		null,
		[],
		true,
		RoundController.UndoMode.SPLIT,
		true
	)
	assert_false(session.activate_card(0), "final round should reject queued search")
	assert_true("最后一轮" in session.last_error, "rejection should explain final-round reason")
