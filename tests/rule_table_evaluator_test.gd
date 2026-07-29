extends "res://tests/test_case.gd"

var catalog := RuleTableCatalog.new()
var evaluator := RuleEvaluator.new()

func run() -> void:
	_assert_rule(&"rule_exact_sum", 2, [1, 6], [1, 5], {"target_value": 7})
	_assert_rule(&"rule_minimum_sum", 2, [3, 4], [1, 5], {"target_value": 7})
	_assert_rule(&"rule_maximum_sum", 2, [3, 4], [4, 4], {"target_value": 7})
	_assert_rule(
		&"rule_sum_range",
		2,
		[3, 4],
		[1, 4],
		{"minimum_value": 6, "maximum_value": 8}
	)
	_assert_rule(&"rule_all_equal", 2, [3, 3], [3, 4])
	_assert_rule(&"rule_all_distinct", 3, [1, 2, 3], [1, 2, 1])
	_assert_rule(&"rule_all_even", 2, [2, 6], [2, 5])
	_assert_rule(&"rule_all_odd", 2, [1, 5], [1, 4])
	_assert_rule(&"rule_same_parity", 3, [1, 3, 5], [1, 2, 5])
	_assert_rule(&"rule_consecutive", 3, [4, 2, 3], [1, 3, 6])
	_assert_rule(
		&"rule_fixed_difference",
		3,
		[5, 1, 3],
		[1, 3, 6],
		{"difference": 2}
	)
	_assert_rule(&"rule_strict_ascending", 3, [1, 3, 6], [3, 1, 6])
	_assert_rule(&"rule_strict_descending", 3, [6, 3, 1], [6, 1, 3])
	_assert_rule(&"rule_mirrored", 3, [2, 5, 2], [2, 5, 3])
	_assert_rule(
		&"rule_slot_targets",
		3,
		[2, 4, 6],
		[2, 6, 4],
		{"slot_targets": PackedInt32Array([2, 4, 6])}
	)
	_assert_rule(&"rule_echo_table", 2, [1, 6], [1])
	_assert_rule(&"rule_reverse_table", 2, [1, 6], [1])
	_assert_rule(&"rule_bridge_table", 2, [1, 6], [1])

	var exact := _rule(&"rule_exact_sum", 2, {"target_value": 7})
	var tolerant := evaluator.evaluate(
		exact,
		[1, 5],
		0,
		[],
		[EffectSpec.ConditionModifier.EXACT_TOLERANCE]
	)
	assert_true(tolerant.valid, "exact tolerance should work on the exact template")

	var all_even := _rule(&"rule_all_even", 2)
	var allow_odd := evaluator.evaluate(
		all_even,
		[2, 5],
		0,
		[],
		[EffectSpec.ConditionModifier.ALLOW_ONE_ODD]
	)
	assert_true(allow_odd.valid, "allow-one-odd should work on all-even")

	var consecutive := _rule(&"rule_consecutive", 3)
	var allow_gap := evaluator.evaluate(
		consecutive,
		[1, 3, 4],
		0,
		[],
		[EffectSpec.ConditionModifier.ALLOW_ONE_GAP]
	)
	assert_true(allow_gap.valid, "allow-one-gap should work on consecutive")

func _assert_rule(
	template_id: StringName,
	slot_count: int,
	valid_values: Array,
	invalid_values: Array,
	parameters: Dictionary = {}
) -> void:
	var rule := _rule(template_id, slot_count, parameters)
	var valid_result := evaluator.evaluate(rule, valid_values)
	assert_true(valid_result.valid, "%s should accept its positive sample" % template_id)
	assert_equal(
		valid_result.total,
		_sum(valid_values) * rule.coefficient,
		"%s should use the shared score formula" % template_id
	)
	var invalid_result := evaluator.evaluate(rule, invalid_values)
	assert_false(
		invalid_result.valid,
		"%s should reject its negative sample" % template_id
	)

func _rule(
	template_id: StringName,
	slot_count: int,
	parameters: Dictionary = {}
) -> RuleDefinition:
	var rule := RuleDefinition.new()
	rule.id = &"test"
	rule.display_name = "测试规则"
	rule.template = catalog.find_template(template_id)
	rule.slot_count = slot_count
	rule.coefficient = 2
	for property_name in parameters:
		rule.set(property_name, parameters[property_name])
	return rule

func _sum(values: Array) -> int:
	var total := 0
	for value in values:
		total += int(value)
	return total
