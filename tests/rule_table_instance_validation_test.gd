extends "res://tests/test_case.gd"

var catalog := RuleTableCatalog.new()
var validator := ContentValidator.new()

func run() -> void:
	var exact := _rule(&"rule_exact_sum", 2)
	exact.target_value = 7
	assert_equal(
		validator.validate([exact], []),
		[],
		"a reachable exact-sum instance should validate"
	)
	exact.target_value = 13
	assert_true(
		not validator.validate([exact], []).is_empty(),
		"an unreachable exact-sum target should fail"
	)

	var range_rule := _rule(&"rule_sum_range", 2)
	range_rule.minimum_value = 8
	range_rule.maximum_value = 6
	assert_true(
		not validator.validate([range_rule], []).is_empty(),
		"an inverted range should fail"
	)

	var difference := _rule(&"rule_fixed_difference", 3)
	difference.difference = 3
	assert_true(
		not validator.validate([difference], []).is_empty(),
		"an unreachable three-die fixed difference should fail"
	)

	var slots := _rule(&"rule_slot_targets", 3)
	slots.slot_targets = PackedInt32Array([2, 4])
	assert_true(
		not validator.validate([slots], []).is_empty(),
		"slot targets should match the instance slot count"
	)

	slots.slot_targets = PackedInt32Array([2, 4, 6])
	assert_equal(
		validator.validate([slots], []),
		[],
		"a complete slot-target instance should validate"
	)
	_assert_slot_targets_reject_slot_increase(slots)

func _assert_slot_targets_reject_slot_increase(rule: RuleDefinition) -> void:
	var encounter := EncounterDefinition.new()
	encounter.id = &"test_encounter"
	encounter.rules = [rule]

	var effect := EffectSpec.new()
	effect.operation = EffectSpec.Operation.MODIFY_CONDITION
	effect.condition_modifier = EffectSpec.ConditionModifier.INCREASE_SLOT_COUNT
	effect.amount = 1
	var card := CardDefinition.new()
	card.id = &"test_increase_slots"
	card.display_name = "增加槽位"
	card.target_type = CardDefinition.TargetType.TABLE
	card.effects = [effect]

	var result := CardRules.play_card(
		RoundState.new(),
		PlayedCard.new(card, rule.id),
		ResolutionContext.empty(),
		encounter
	)
	assert_false(result.accepted, "slot-target rules should reject slot increases")
	assert_equal(
		result.reason,
		"这张条件手法牌与目标规则台不匹配",
		"incompatible templates should provide a concrete card-play reason"
	)

func _rule(template_id: StringName, slot_count: int) -> RuleDefinition:
	var rule := RuleDefinition.new()
	rule.id = &"test"
	rule.display_name = "测试规则"
	rule.template = catalog.find_template(template_id)
	rule.slot_count = slot_count
	rule.coefficient = 2
	return rule
