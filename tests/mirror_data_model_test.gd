extends "res://tests/test_case.gd"

func run() -> void:
	_test_encounter_profile_is_retained()
	_test_played_card_clone_retains_source_metadata()
	_test_runtime_effects_are_defensive_copies()
	_test_resolution_defaults_remain_compatible()

func _test_encounter_profile_is_retained() -> void:
	var profile := EncounterRuleProfile.new()
	profile.resolution_direction = (
		EncounterRuleProfile.ResolutionDirection.RIGHT_TO_LEFT
	)
	profile.mirror_first_table_card = true
	profile.mirror_limit_per_round = 1

	var encounter := EncounterDefinition.new()
	encounter.rule_profile = profile
	assert_equal(
		encounter.rule_profile.resolution_direction,
		EncounterRuleProfile.ResolutionDirection.RIGHT_TO_LEFT,
		"encounter should retain public direction"
	)
	assert_true(
		encounter.rule_profile.mirror_first_table_card,
		"encounter should retain the mirror toggle"
	)
	assert_equal(
		encounter.rule_profile.mirror_limit_per_round,
		1,
		"encounter should retain the mirror limit"
	)

func _test_played_card_clone_retains_source_metadata() -> void:
	var card := CardDefinition.new()
	card.id = &"mirror_fixture"
	card.display_name = "镜像样例"
	var original := PlayedCard.new(card, &"left", &"middle")
	original.play_id = &"play_1"
	original.is_mirror_copy = true
	original.source_card_id = card.id
	original.source_play_id = &"source_play"
	original.source_slot_id = &"left_gap"

	var copy := original.clone()
	assert_equal(copy.play_id, &"play_1", "clone should retain play ID")
	assert_true(copy.is_mirror_copy, "clone should retain mirror marker")
	assert_equal(
		copy.source_card_id,
		&"mirror_fixture",
		"clone should retain source card"
	)
	assert_equal(
		copy.source_play_id,
		&"source_play",
		"clone should retain source play"
	)
	assert_equal(
		copy.source_slot_id,
		&"left_gap",
		"clone should retain source slot"
	)

func _test_runtime_effects_are_defensive_copies() -> void:
	var card := CardDefinition.new()
	card.id = &"mirror_runtime_fixture"
	var definition_effect := EffectSpec.new()
	definition_effect.operation = EffectSpec.Operation.MODIFY_COEFFICIENT
	definition_effect.amount = 2
	card.effects = [definition_effect]

	var runtime_effect := EffectSpec.new()
	runtime_effect.operation = EffectSpec.Operation.MODIFY_COEFFICIENT
	runtime_effect.amount = 1
	var played := PlayedCard.new(card, &"right", &"middle")
	played.runtime_effects = [runtime_effect]

	var copy := played.clone()
	assert_equal(
		copy.effective_effects()[0].amount,
		1,
		"runtime effect should override definition effects"
	)
	assert_false(
		copy.runtime_effects[0] == played.runtime_effects[0],
		"clone should deep-copy runtime effects"
	)
	copy.runtime_effects[0].amount = 9
	assert_equal(
		played.runtime_effects[0].amount,
		1,
		"mutating clone should not change source runtime effects"
	)

func _test_resolution_defaults_remain_compatible() -> void:
	var report := ResolutionReport.new()
	assert_equal(
		report.resolution_direction,
		EncounterRuleProfile.ResolutionDirection.LEFT_TO_RIGHT,
		"legacy report direction should default left-to-right"
	)
	assert_equal(
		report.ordered_rule_ids,
		[],
		"legacy report should start without an ordered-rule snapshot"
	)
	var event := ResolutionEvent.new(&"fixture", "样例", 0, 0)
	assert_false(event.is_mirror_copy, "legacy events should not be mirrors")
