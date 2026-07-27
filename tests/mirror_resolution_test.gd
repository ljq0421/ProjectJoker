extends "res://tests/test_case.gd"

func run() -> void:
	_test_right_to_left_orders_report()
	_test_reverse_card_toggles_profile_direction()
	_test_gap_single_table_effects_use_secondary_target()
	_test_mirror_event_exposes_source_metadata()
	_test_content_validator_accepts_gap_table_effects()
	_test_content_validator_rejects_forbidden_mirror_effects()

func _test_right_to_left_orders_report() -> void:
	var encounter := _three_rule_encounter(
		EncounterRuleProfile.ResolutionDirection.RIGHT_TO_LEFT
	)
	var report := RoundResolver.new().resolve(RoundState.new(), encounter)
	assert_true(report.valid, "empty assignment report should remain structurally valid")
	assert_equal(
		report.ordered_rule_ids,
		[&"right", &"middle", &"left"],
		"right-to-left profile should order report"
	)
	assert_equal(
		report.resolution_direction,
		EncounterRuleProfile.ResolutionDirection.RIGHT_TO_LEFT,
		"report should expose effective direction"
	)

func _test_reverse_card_toggles_profile_direction() -> void:
	var reverse := CardDefinition.new()
	reverse.id = &"reverse_fixture"
	reverse.display_name = "倒序样例"
	reverse.target_type = CardDefinition.TargetType.GLOBAL
	var effect := EffectSpec.new()
	effect.operation = EffectSpec.Operation.REVERSE_RESOLUTION
	reverse.effects = [effect]
	var state := RoundState.new()
	state.played_cards.append(PlayedCard.new(reverse))

	var report := RoundResolver.new().resolve(
		state,
		_three_rule_encounter(
			EncounterRuleProfile.ResolutionDirection.RIGHT_TO_LEFT
		)
	)
	assert_equal(
		report.ordered_rule_ids,
		[&"left", &"middle", &"right"],
		"reverse card should toggle the profile direction"
	)
	assert_equal(
		report.resolution_direction,
		EncounterRuleProfile.ResolutionDirection.LEFT_TO_RIGHT,
		"effective direction should reflect the toggle"
	)

func _test_gap_single_table_effects_use_secondary_target() -> void:
	var encounter := EncounterDefinition.new()
	encounter.id = &"gap_target_fixture"
	encounter.rules = [
		_exact_rule(&"left", 6),
		_exact_rule(&"middle", 1),
		_exact_rule(&"right", 6),
	]
	var state := RoundState.new()
	state.dice = [DieState.new(&"d1", 1)]
	state.assignments = {&"middle": [&"d1"]}

	var card := _valid_gap_card(&"gap_boost_fixture")
	var coefficient := EffectSpec.new()
	coefficient.operation = EffectSpec.Operation.MODIFY_COEFFICIENT
	coefficient.amount = 2
	var repeat := EffectSpec.new()
	repeat.operation = EffectSpec.Operation.REPEAT_TABLE
	repeat.amount = 1
	card.effects = [coefficient, repeat]
	state.played_cards.append(PlayedCard.new(card, &"left", &"middle"))

	var report := RoundResolver.new().resolve(state, encounter)
	assert_true(report.valid, "gap table effects should resolve")
	assert_equal(
		report.total,
		6,
		"coefficient +2 and one repeat should affect the secondary table"
	)

func _test_mirror_event_exposes_source_metadata() -> void:
	var card := _valid_gap_card(&"mirror_event_fixture")
	card.display_name = "折光样例"
	var original := PlayedCard.new(card, &"left", &"middle")
	original.play_id = &"play_1"
	var copy := PlayedCard.new(card, &"right", &"middle")
	copy.play_id = &"play_1_mirror"
	copy.is_mirror_copy = true
	copy.source_card_id = card.id
	copy.source_play_id = original.play_id
	copy.source_slot_id = &"left_gap"
	var runtime_effect := EffectSpec.new()
	runtime_effect.operation = EffectSpec.Operation.MODIFY_COEFFICIENT
	runtime_effect.amount = 1
	copy.runtime_effects = [runtime_effect]
	var state := RoundState.new()
	state.played_cards = [original, copy]

	var report := RoundResolver.new().resolve(
		state,
		_three_rule_encounter(
			EncounterRuleProfile.ResolutionDirection.LEFT_TO_RIGHT
		)
	)
	assert_true(report.valid, "mirror event fixture should resolve")
	assert_equal(report.events.size() >= 2, true, "card events should exist")
	var event := report.events[1]
	assert_true(event.is_mirror_copy, "derived event should be marked")
	assert_true(
		event.label.begins_with("镜像副本：折光样例"),
		"derived event should have an explicit label"
	)
	assert_true(
		event.label.contains("right → middle"),
		"derived event should expose mirrored endpoints"
	)
	assert_true(
		event.label.contains("系数 +1"),
		"derived event should expose weakened effects"
	)
	assert_equal(
		event.source_card_id,
		&"mirror_event_fixture",
		"derived event should expose source card"
	)
	assert_equal(event.source_slot_id, &"left_gap", "event should expose source gap")
	assert_equal(event.mirror_slot_id, &"right_gap", "event should expose mirror gap")

func _test_content_validator_accepts_gap_table_effects() -> void:
	var card := _valid_gap_card(&"valid_gap_effects")
	var coefficient := EffectSpec.new()
	coefficient.operation = EffectSpec.Operation.MODIFY_COEFFICIENT
	coefficient.amount = 1
	var repeat := EffectSpec.new()
	repeat.operation = EffectSpec.Operation.REPEAT_TABLE
	repeat.amount = 1
	card.effects = [coefficient, repeat]
	card.mirror_effects = [coefficient]
	assert_equal(
		ContentValidator.new().validate([], [card]),
		[],
		"gap cards should accept coefficient and repeat effects"
	)

func _test_content_validator_rejects_forbidden_mirror_effects() -> void:
	var card := _valid_gap_card(&"forbidden_mirror_effect")
	var adjust := EffectSpec.new()
	adjust.operation = EffectSpec.Operation.ADJUST_DIE
	adjust.amount = 1
	card.mirror_effects = [adjust]
	var errors := ContentValidator.new().validate([], [card])
	assert_true(
		errors.any(func(message: String) -> bool: return message.contains(
			"forbidden mirror operation"
		)),
		"adjust-die should be forbidden in mirror effects"
	)

	var table_card := _valid_gap_card(&"wrong_mirror_target")
	table_card.target_type = CardDefinition.TargetType.TABLE
	var coefficient := EffectSpec.new()
	coefficient.operation = EffectSpec.Operation.MODIFY_COEFFICIENT
	coefficient.amount = 1
	table_card.effects = [coefficient]
	table_card.mirror_effects = [coefficient]
	var target_errors := ContentValidator.new().validate([], [table_card])
	assert_true(
		target_errors.any(func(message: String) -> bool: return message.contains(
			"mirror effects require a gap target"
		)),
		"non-gap cards should not declare mirror effects"
	)

func _three_rule_encounter(
	direction: EncounterRuleProfile.ResolutionDirection
) -> EncounterDefinition:
	var encounter := EncounterDefinition.new()
	encounter.id = &"direction_fixture"
	encounter.rule_profile.resolution_direction = direction
	encounter.rules = [
		_exact_rule(&"left", 6),
		_exact_rule(&"middle", 6),
		_exact_rule(&"right", 6),
	]
	return encounter

func _exact_rule(rule_id: StringName, target: int) -> RuleDefinition:
	var rule := RuleDefinition.new()
	rule.id = rule_id
	rule.display_name = String(rule_id)
	rule.slot_count = 1
	rule.target_value = target
	rule.coefficient = 1
	return rule

func _valid_gap_card(card_id: StringName) -> CardDefinition:
	var card := CardDefinition.new()
	card.id = card_id
	card.display_name = String(card_id)
	card.rule_text = "作用于箭头所指规则台。"
	card.tags = PackedStringArray(["桌间", "镜像"])
	card.target_type = CardDefinition.TargetType.GAP
	card.suit = CardDefinition.Suit.HEARTS
	card.rank_label = "1"
	card.rarity = CardDefinition.Rarity.COMMON
	var link := EffectSpec.new()
	link.operation = EffectSpec.Operation.LINK_NEIGHBORS
	link.amount = 1
	card.effects = [link]
	return card
