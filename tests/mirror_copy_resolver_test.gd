extends "res://tests/test_case.gd"

func run() -> void:
	_test_left_gap_reflects_to_right_gap()
	_test_right_gap_reflects_to_left_gap()
	_test_runtime_effects_are_deep_copied()
	_test_noneligible_card_does_not_generate()
	_test_existing_copy_reaches_round_limit()
	_test_copy_never_recurses()
	_test_invalid_gap_is_rejected()
	_test_card_rules_add_original_and_copy_atomically()
	_test_real_card_limit_ignores_derived_copy()
	_test_undo_removes_original_and_copy_together()

func _test_left_gap_reflects_to_right_gap() -> void:
	var original := PlayedCard.new(_mirror_card(), &"left", &"middle")
	original.play_id = &"play_1"
	var result := MirrorCopyResolver.new().resolve(
		original,
		RoundState.new(),
		_mirror_encounter()
	)
	assert_true(result.accepted, "valid mirror card should resolve")
	assert_true(result.generated, "eligible card should generate copy")
	assert_equal(
		result.copy.primary_target,
		&"right",
		"reflected source should be right"
	)
	assert_equal(
		result.copy.secondary_target,
		&"middle",
		"reflected target should be middle"
	)
	assert_equal(
		result.copy.source_slot_id,
		&"left_gap",
		"copy should retain original gap"
	)
	assert_equal(
		result.copy.source_play_id,
		&"play_1",
		"copy should retain original play ID"
	)

func _test_right_gap_reflects_to_left_gap() -> void:
	var original := PlayedCard.new(_mirror_card(), &"middle", &"right")
	original.play_id = &"play_2"
	var result := MirrorCopyResolver.new().resolve(
		original,
		RoundState.new(),
		_mirror_encounter()
	)
	assert_true(result.accepted, "right-gap card should resolve")
	assert_true(result.generated, "right-gap card should mirror")
	assert_equal(
		[result.copy.primary_target, result.copy.secondary_target],
		[&"middle", &"left"],
		"right gap should reflect to middle-to-left"
	)
	assert_equal(
		result.copy.source_slot_id,
		&"right_gap",
		"copy should retain the right source gap"
	)

func _test_runtime_effects_are_deep_copied() -> void:
	var card := _mirror_card()
	var original := PlayedCard.new(card, &"left", &"middle")
	var result := MirrorCopyResolver.new().resolve(
		original,
		RoundState.new(),
		_mirror_encounter()
	)
	assert_false(
		result.copy.runtime_effects[0] == card.mirror_effects[0],
		"mirror effects must be deep copied"
	)
	result.copy.runtime_effects[0].amount = 9
	assert_equal(
		card.mirror_effects[0].amount,
		1,
		"copy mutation should not alter card resource"
	)

func _test_noneligible_card_does_not_generate() -> void:
	var card := CardDefinition.new()
	card.id = &"plain_gap"
	card.display_name = "普通桌间牌"
	card.target_type = CardDefinition.TargetType.GAP
	var result := MirrorCopyResolver.new().resolve(
		PlayedCard.new(card, &"left", &"middle"),
		RoundState.new(),
		_mirror_encounter()
	)
	assert_true(result.accepted, "plain gap card remains legal")
	assert_false(result.generated, "plain gap card should not mirror")

func _test_existing_copy_reaches_round_limit() -> void:
	var state := RoundState.new()
	var existing := PlayedCard.new(_mirror_card(), &"right", &"middle")
	existing.is_mirror_copy = true
	state.played_cards.append(existing)
	var result := MirrorCopyResolver.new().resolve(
		PlayedCard.new(_mirror_card(), &"left", &"middle"),
		state,
		_mirror_encounter()
	)
	assert_true(result.accepted, "a second eligible original remains legal")
	assert_false(result.generated, "mirror limit should suppress second copy")

func _test_copy_never_recurses() -> void:
	var copy := PlayedCard.new(_mirror_card(), &"right", &"middle")
	copy.is_mirror_copy = true
	var result := MirrorCopyResolver.new().resolve(
		copy,
		RoundState.new(),
		_mirror_encounter()
	)
	assert_true(result.accepted, "derived copy should be safely ignored")
	assert_false(result.generated, "derived copy must not recurse")

func _test_invalid_gap_is_rejected() -> void:
	var result := MirrorCopyResolver.new().resolve(
		PlayedCard.new(_mirror_card(), &"left", &"right"),
		RoundState.new(),
		_mirror_encounter()
	)
	assert_false(result.accepted, "non-adjacent gap should reject")
	assert_false(result.generated, "invalid gap should not generate")

func _test_card_rules_add_original_and_copy_atomically() -> void:
	var result := CardRules.play_card(
		RoundState.new(),
		PlayedCard.new(_mirror_card(), &"left", &"middle"),
		ResolutionContext.empty(),
		_mirror_encounter()
	)
	assert_true(result.accepted, "eligible original and copy should be accepted")
	assert_equal(
		result.next_state.played_cards.size(),
		2,
		"one action should append original and copy"
	)
	assert_false(
		result.next_state.played_cards[0].is_mirror_copy,
		"first runtime card should be original"
	)
	assert_true(
		result.next_state.played_cards[1].is_mirror_copy,
		"second runtime card should be derived copy"
	)

func _test_real_card_limit_ignores_derived_copy() -> void:
	var encounter := _mirror_encounter()
	var first := CardRules.play_card(
		RoundState.new(),
		PlayedCard.new(_mirror_card(), &"left", &"middle"),
		ResolutionContext.empty(),
		encounter
	)
	var second_card := _plain_table_card(&"second_real")
	var second := CardRules.play_card(
		first.next_state,
		PlayedCard.new(second_card, &"middle"),
		ResolutionContext.empty(),
		encounter
	)
	var third := CardRules.play_card(
		second.next_state,
		PlayedCard.new(_plain_table_card(&"third_real"), &"right"),
		ResolutionContext.empty(),
		encounter
	)
	assert_true(second.accepted, "copy should not consume second real-card action")
	assert_false(third.accepted, "third real card should exceed limit")

func _test_undo_removes_original_and_copy_together() -> void:
	var controller := RoundController.new(RoundState.new(), _mirror_encounter())
	var result := controller.play_card(
		PlayedCard.new(_mirror_card(), &"left", &"middle")
	)
	assert_true(result.accepted, "controller should accept mirror action")
	assert_equal(controller.state.played_cards.size(), 2, "action should create pair")
	assert_true(controller.undo(), "one undo should restore prior snapshot")
	assert_equal(
		controller.state.played_cards.size(),
		0,
		"one undo should remove original and copy"
	)

func _mirror_card() -> CardDefinition:
	var card := CardDefinition.new()
	card.id = &"mirror_fixture"
	card.display_name = "镜像样例"
	card.target_type = CardDefinition.TargetType.GAP
	var original_effect := EffectSpec.new()
	original_effect.operation = EffectSpec.Operation.LINK_NEIGHBORS
	original_effect.amount = 1
	card.effects = [original_effect]
	var mirror_effect := EffectSpec.new()
	mirror_effect.operation = EffectSpec.Operation.MODIFY_COEFFICIENT
	mirror_effect.amount = 1
	card.mirror_effects = [mirror_effect]
	return card

func _plain_table_card(card_id: StringName) -> CardDefinition:
	var card := CardDefinition.new()
	card.id = card_id
	card.display_name = String(card_id)
	card.target_type = CardDefinition.TargetType.TABLE
	var effect := EffectSpec.new()
	effect.operation = EffectSpec.Operation.MODIFY_COEFFICIENT
	effect.amount = 1
	card.effects = [effect]
	return card

func _mirror_encounter() -> EncounterDefinition:
	var encounter := EncounterDefinition.new()
	encounter.id = &"mirror_encounter_fixture"
	encounter.rules = [
		_rule(&"left"),
		_rule(&"middle"),
		_rule(&"right"),
	]
	encounter.rule_profile.mirror_first_table_card = true
	encounter.rule_profile.mirror_limit_per_round = 1
	return encounter

func _rule(rule_id: StringName) -> RuleDefinition:
	var rule := RuleDefinition.new()
	rule.id = rule_id
	rule.display_name = String(rule_id)
	rule.slot_count = 2
	rule.target_value = 7
	return rule
