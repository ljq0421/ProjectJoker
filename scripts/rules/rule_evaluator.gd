class_name RuleEvaluator
extends RefCounted

func evaluate(
	definition: RuleDefinition,
	values: Array,
	coefficient_modifier: int = 0
) -> RuleResult:
	if values.size() != definition.slot_count:
		return RuleResult.new(false, 0, 0, "requires %d dice" % definition.slot_count)

	var typed_values: Array[int] = []
	for value in values:
		var int_value := int(value)
		if int_value < 1 or int_value > 6:
			return RuleResult.new(false, 0, 0, "die values must be between 1 and 6")
		typed_values.append(int_value)

	var valid := _matches(definition, typed_values)
	var base_sum := _sum(typed_values)
	if not valid:
		return RuleResult.new(false, base_sum, 0, "condition not satisfied")

	var effective_coefficient := definition.coefficient + coefficient_modifier
	if effective_coefficient < 0:
		return RuleResult.new(false, base_sum, 0, "effective coefficient cannot be negative")
	return RuleResult.new(
		true,
		base_sum,
		base_sum * effective_coefficient + definition.flat_bonus
	)

func _matches(definition: RuleDefinition, values: Array[int]) -> bool:
	match definition.condition_type:
		RuleDefinition.ConditionType.EXACT_SUM:
			return _sum(values) == definition.target_value
		RuleDefinition.ConditionType.ALL_EVEN:
			return values.all(func(value: int) -> bool: return value % 2 == 0)
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
