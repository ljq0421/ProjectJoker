class_name RuleEvaluator
extends RefCounted

func evaluate(
	definition: RuleDefinition,
	values: Array,
	coefficient_modifier: int = 0,
	parity_overrides: Array[bool] = []
) -> RuleResult:
	if values.size() != definition.slot_count:
		return RuleResult.new(false, 0, 0, "需要放入 %d 颗骰子" % definition.slot_count)
	if not parity_overrides.is_empty() and parity_overrides.size() != values.size():
		return RuleResult.new(false, 0, 0, "奇偶覆盖数量与骰子数量不一致")

	var typed_values: Array[int] = []
	for value in values:
		var int_value := int(value)
		if int_value < 1 or int_value > 6:
			return RuleResult.new(false, 0, 0, "骰子点数必须在 1 到 6 之间")
		typed_values.append(int_value)

	var valid := _matches(definition, typed_values, parity_overrides)
	var base_sum := _sum(typed_values)
	if not valid:
		return RuleResult.new(false, base_sum, 0, "未满足规则条件")

	var effective_coefficient := definition.coefficient + coefficient_modifier
	if effective_coefficient < 0:
		return RuleResult.new(false, base_sum, 0, "最终系数不能为负数")
	return RuleResult.new(
		true,
		base_sum,
		base_sum * effective_coefficient + definition.flat_bonus
	)

func _matches(
	definition: RuleDefinition,
	values: Array[int],
	parity_overrides: Array[bool]
) -> bool:
	match definition.condition_type:
		RuleDefinition.ConditionType.EXACT_SUM:
			return _sum(values) == definition.target_value
		RuleDefinition.ConditionType.ALL_EVEN:
			for index in range(values.size()):
				var prism_treats_as_even := (
					not parity_overrides.is_empty()
					and parity_overrides[index]
				)
				if values[index] % 2 != 0 and not prism_treats_as_even:
					return false
			return true
		RuleDefinition.ConditionType.CONSECUTIVE:
			var sorted_values := values.duplicate()
			sorted_values.sort()
			for index in range(1, sorted_values.size()):
				if sorted_values[index] != sorted_values[index - 1] + 1:
					return false
			return true
	return false

func _sum(values: Array[int]) -> int:
	var total := 0
	for value in values:
		total += value
	return total
