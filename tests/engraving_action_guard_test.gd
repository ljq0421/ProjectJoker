extends "res://tests/test_case.gd"

func run() -> void:
	var state := RoundState.new()
	state.dice = [DieState.new(&"d1", 4, &"engraving_anchor", 4)]
	var context := ResolutionContext.new(null, EngravingCatalog.new())

	var calibration := RoundActions.adjust_die(state, &"d1", 1, context)
	assert_false(calibration.accepted, "active anchor should reject calibration")
	assert_true("锚定" in calibration.reason, "calibration reason should name anchor")
	assert_equal(calibration.next_state.calibration_points, 2, "rejection should not spend points")
	assert_equal(calibration.next_state.find_die(&"d1").value, 4, "rejection should not change die")

	var card := CardCatalog.new().find_card(&"starter_nudge_up_1")
	var played := PlayedCard.new(card, &"d1")
	var card_result := CardRules.play_card(state, played, context)
	assert_false(card_result.accepted, "active anchor should reject adjust-die card")
	assert_equal(card_result.next_state.played_cards.size(), 0, "rejection should not play card")

	var controller := RoundController.new(
		state,
		SingleEncounterFixture.make_encounter(),
		context
	)
	assert_false(controller.adjust_die(&"d1", 1).accepted, "controller should preserve anchor guard")
	assert_false(controller.play_card(played).accepted, "controller card path should preserve guard")
	assert_false(controller.undo(), "rejected actions should not enter undo history")

	var session := SingleEncounterSession.new(
		state,
		SingleEncounterFixture.make_encounter(),
		[card],
		context
	)
	assert_false(session.calibrate_die(&"d1", 1), "session calibration should reject anchor")
	assert_true(session.activate_card(0), "adjust card should still be selectable")
	assert_false(session.activate_die(&"d1"), "session target should reject anchor")
	assert_equal(session.controller.state.played_cards.size(), 0, "session rejection should be atomic")

	state.find_die(&"d1").rolled_value = 3
	assert_true(
		RoundActions.adjust_die(state, &"d1", 1, context).accepted,
		"anchor should be inactive when rolled face does not match"
	)
