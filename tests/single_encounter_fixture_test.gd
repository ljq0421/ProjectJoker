extends "res://tests/test_case.gd"

const FixtureScript = preload("res://scripts/demo/single_encounter_fixture.gd")

func run() -> void:
	var state = FixtureScript.make_state()
	var encounter = FixtureScript.make_encounter()
	var hand = FixtureScript.make_hand()
	assert_equal(state.dice.size(), 6, "fixture should provide six dice")
	assert_equal(state.calibration_points, 2, "fixture should provide two calibration points")
	assert_equal(encounter.rules.size(), 3, "fixture should provide three lanes")
	assert_equal(hand.size(), 4, "fixture should provide four cards")
	assert_equal(
		ContentValidator.new().validate(encounter.rules, hand),
		[],
		"fixture content should pass validation"
	)
