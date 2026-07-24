extends "res://tests/test_case.gd"

const RuleDefinitionScript = preload("res://scripts/rules/rule_definition.gd")
const RuleEvaluatorScript = preload("res://scripts/rules/rule_evaluator.gd")

func run() -> void:
	var evaluator := RuleEvaluatorScript.new()

	var exact := RuleDefinitionScript.new()
	exact.id = &"exact_7"
	exact.condition_type = RuleDefinitionScript.ConditionType.EXACT_SUM
	exact.slot_count = 2
	exact.target_value = 7
	exact.coefficient = 2
	var exact_result = evaluator.evaluate(exact, [1, 6])
	assert_true(exact_result.valid, "1 + 6 should satisfy exact sum 7")
	assert_equal(exact_result.total, 14, "exact sum should use sum times coefficient")
	assert_equal(
		evaluator.evaluate(exact, [1]).reason,
		"需要放入 2 颗骰子",
		"incomplete rules should provide player-facing Chinese feedback"
	)

	var even := RuleDefinitionScript.new()
	even.id = &"all_even"
	even.condition_type = RuleDefinitionScript.ConditionType.ALL_EVEN
	even.slot_count = 2
	even.coefficient = 3
	assert_false(evaluator.evaluate(even, [2, 5]).valid, "odd values should fail all-even")

	var consecutive := RuleDefinitionScript.new()
	consecutive.id = &"three_consecutive"
	consecutive.condition_type = RuleDefinitionScript.ConditionType.CONSECUTIVE
	consecutive.slot_count = 3
	consecutive.coefficient = 2
	var consecutive_result = evaluator.evaluate(consecutive, [4, 2, 3])
	assert_true(consecutive_result.valid, "unordered 2,3,4 should be consecutive")
	assert_equal(consecutive_result.total, 18, "2 + 3 + 4 at coefficient 2 should score 18")

	var modified_result = evaluator.evaluate(exact, [1, 6], 1)
	assert_equal(modified_result.total, 21, "coefficient modifiers should be additive")
