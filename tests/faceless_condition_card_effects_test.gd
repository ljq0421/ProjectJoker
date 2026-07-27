extends "res://tests/test_case.gd"

func run() -> void:
	_test_condition_modifier_semantics()
	_test_modifier_is_scoped_to_target_and_round()
	_test_mismatched_condition_target_is_rejected()
	_test_slot_increase_uses_effective_capacity()

func _test_condition_modifier_semantics() -> void:
	var evaluator := RuleEvaluator.new()
	var exact := _rule(&"exact", RuleDefinition.ConditionType.EXACT_SUM, 2, 7)
	assert_true(
		evaluator.evaluate(
			exact, [1, 5], 0, [],
			[EffectSpec.ConditionModifier.EXACT_TOLERANCE]
		).valid,
		"exact tolerance accepts target minus one"
	)
	assert_false(
		evaluator.evaluate(
			exact, [1, 4], 0, [],
			[EffectSpec.ConditionModifier.EXACT_TOLERANCE]
		).valid,
		"exact tolerance rejects target minus two"
	)

	var even := _rule(&"even", RuleDefinition.ConditionType.ALL_EVEN, 2)
	assert_true(
		evaluator.evaluate(
			even, [2, 3], 0, [],
			[EffectSpec.ConditionModifier.ALLOW_ONE_ODD]
		).valid,
		"even tolerance allows one odd die"
	)
	assert_false(
		evaluator.evaluate(
			even, [1, 3], 0, [],
			[EffectSpec.ConditionModifier.ALLOW_ONE_ODD]
		).valid,
		"even tolerance rejects two odd dice"
	)

	var sequence := _rule(
		&"sequence",
		RuleDefinition.ConditionType.CONSECUTIVE,
		3
	)
	assert_true(
		evaluator.evaluate(
			sequence, [1, 2, 4], 0, [],
			[EffectSpec.ConditionModifier.ALLOW_ONE_GAP]
		).valid,
		"sequence tolerance allows one difference-two gap"
	)
	assert_false(
		evaluator.evaluate(
			sequence, [1, 3, 5], 0, [],
			[EffectSpec.ConditionModifier.ALLOW_ONE_GAP]
		).valid,
		"sequence tolerance rejects two gaps"
	)

	var widened := _rule(
		&"widened",
		RuleDefinition.ConditionType.EXACT_SUM,
		2,
		6
	)
	assert_true(
		evaluator.evaluate(
			widened,
			[1, 2, 3],
			0,
			[],
			[EffectSpec.ConditionModifier.INCREASE_SLOT_COUNT],
			3
		).valid,
		"slot increase evaluates with one additional required die"
	)

func _test_modifier_is_scoped_to_target_and_round() -> void:
	var encounter := EncounterDefinition.new()
	encounter.rules = [
		_rule(&"left", RuleDefinition.ConditionType.EXACT_SUM, 2, 7),
		_rule(&"middle", RuleDefinition.ConditionType.ALL_EVEN, 2),
	]
	var state := _state()
	state.assignments = {
		&"left": [&"d1", &"d5"],
		&"middle": [&"d2", &"d3"],
	}
	var controller := RoundController.new(state, encounter)
	var tolerance := _condition_card(
		&"exact_tolerance",
		EffectSpec.ConditionModifier.EXACT_TOLERANCE
	)
	assert_true(
		controller.play_card(PlayedCard.new(tolerance, &"left")).accepted,
		"matching modifier should play"
	)
	var report := controller.preview()
	assert_equal(report.total, 6, "only the exact target receives tolerance")

	var fresh := RoundController.new(state, encounter)
	assert_equal(fresh.preview().total, 0, "modifier does not leak into a fresh round")

func _test_mismatched_condition_target_is_rejected() -> void:
	var encounter := EncounterDefinition.new()
	encounter.rules = [
		_rule(&"even", RuleDefinition.ConditionType.ALL_EVEN, 2),
	]
	var controller := RoundController.new(_state(), encounter)
	var tolerance := _condition_card(
		&"wrong_tolerance",
		EffectSpec.ConditionModifier.EXACT_TOLERANCE
	)
	assert_false(
		controller.play_card(PlayedCard.new(tolerance, &"even")).accepted,
		"exact tolerance should reject an all-even table"
	)

func _test_slot_increase_uses_effective_capacity() -> void:
	var encounter := EncounterDefinition.new()
	encounter.rules = [
		_rule(&"left", RuleDefinition.ConditionType.EXACT_SUM, 1, 3),
		_rule(&"middle", RuleDefinition.ConditionType.ALL_EVEN, 2),
		_rule(&"right", RuleDefinition.ConditionType.CONSECUTIVE, 2),
	]
	var controller := RoundController.new(_state(), encounter)
	var strict := _condition_card(
		&"strict",
		EffectSpec.ConditionModifier.INCREASE_SLOT_COUNT,
		1
	)
	assert_true(
		controller.play_card(PlayedCard.new(strict, &"left")).accepted,
		"slot increase should fit when total required dice becomes six"
	)
	assert_equal(
		controller.effective_slot_count(&"left"),
		2,
		"controller exposes the increased assignment capacity"
	)
	var second := _condition_card(
		&"strict_again",
		EffectSpec.ConditionModifier.INCREASE_SLOT_COUNT,
		1
	)
	assert_false(
		controller.play_card(PlayedCard.new(second, &"middle")).accepted,
		"slot increase should reject when total required dice exceeds six"
	)

func _state() -> RoundState:
	var state := RoundState.new()
	for value in range(1, 7):
		state.dice.append(DieState.new(StringName("d%d" % value), value))
	return state

func _rule(
	rule_id: StringName,
	condition: RuleDefinition.ConditionType,
	slots: int,
	target: int = 0
) -> RuleDefinition:
	var rule := RuleDefinition.new()
	rule.id = rule_id
	rule.display_name = String(rule_id)
	rule.condition_type = condition
	rule.slot_count = slots
	rule.target_value = target
	rule.coefficient = 1
	return rule

func _condition_card(
	card_id: StringName,
	modifier: EffectSpec.ConditionModifier,
	amount: int = 1
) -> CardDefinition:
	var effect := EffectSpec.new()
	effect.operation = EffectSpec.Operation.MODIFY_CONDITION
	effect.condition_modifier = modifier
	effect.amount = amount
	var card := CardDefinition.new()
	card.id = card_id
	card.display_name = String(card_id)
	card.rule_text = "修改指定规则台的公开条件。"
	card.tags = PackedStringArray(["条件"])
	card.target_type = CardDefinition.TargetType.TABLE
	card.suit = CardDefinition.Suit.HEARTS
	card.rank_label = "测试"
	card.rarity = CardDefinition.Rarity.COMMON
	card.effects = [effect]
	return card
