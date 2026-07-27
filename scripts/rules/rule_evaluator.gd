class_name RuleEvaluator
extends RefCounted

func evaluate(
	definition: RuleDefinition,
	values: Array,
	coefficient_modifier: int = 0,
	parity_overrides: Array[bool] = [],
	condition_modifiers: Array = [],
	effective_slot_count: int = -1,
	sequence_overrides: Array[bool] = []
) -> RuleResult:
	var required_slots := (
		definition.slot_count
		if effective_slot_count < 0
		else effective_slot_count
	)
	if values.size() != required_slots:
		return RuleResult.new(false, 0, 0, "需要放入 %d 颗骰子" % required_slots)
	if not parity_overrides.is_empty() and parity_overrides.size() != values.size():
		return RuleResult.new(false, 0, 0, "奇偶覆盖数量与骰子数量不一致")
	if not sequence_overrides.is_empty() and sequence_overrides.size() != values.size():
		return RuleResult.new(false, 0, 0, "序列覆盖数量与骰子数量不一致")

	var typed_values: Array[int] = []
	for value in values:
		var int_value := int(value)
		if int_value < 1 or int_value > 6:
			return RuleResult.new(false, 0, 0, "骰子点数必须在 1 到 6 之间")
		typed_values.append(int_value)

	var valid := _matches(
		definition,
		typed_values,
		parity_overrides,
		condition_modifiers,
		sequence_overrides
	)
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
	parity_overrides: Array[bool],
	condition_modifiers: Array,
	sequence_overrides: Array[bool]
) -> bool:
	match definition.condition_type:
		RuleDefinition.ConditionType.EXACT_SUM:
			var distance: int = absi(_sum(values) - definition.target_value)
			return (
				distance == 0
				or (
					distance <= 1
					and (
						EffectSpec.ConditionModifier.EXACT_TOLERANCE
						in condition_modifiers
					)
				)
			)
		RuleDefinition.ConditionType.ALL_EVEN:
			var odd_count := 0
			for index in range(values.size()):
				var prism_treats_as_even := (
					not parity_overrides.is_empty()
					and parity_overrides[index]
				)
				if values[index] % 2 != 0 and not prism_treats_as_even:
					odd_count += 1
			return (
				odd_count == 0
				or (
					odd_count <= 1
					and (
						EffectSpec.ConditionModifier.ALLOW_ONE_ODD
						in condition_modifiers
					)
				)
			)
		RuleDefinition.ConditionType.CONSECUTIVE:
			return _matches_sequence_with_overrides(
				values,
				sequence_overrides,
				(
					EffectSpec.ConditionModifier.ALLOW_ONE_GAP
					in condition_modifiers
				),
				0,
				[]
			)
	return false

func _matches_sequence_with_overrides(
	values: Array[int],
	sequence_overrides: Array[bool],
	allow_one_gap: bool,
	index: int,
	candidate: Array[int]
) -> bool:
	if index >= values.size():
		return _matches_sequence(candidate, allow_one_gap)
	var offsets := [0]
	if not sequence_overrides.is_empty() and sequence_overrides[index]:
		offsets = [-1, 0, 1]
	for offset in offsets:
		var relation_value := values[index] + int(offset)
		if relation_value < 1 or relation_value > 6:
			continue
		var next_candidate := candidate.duplicate()
		next_candidate.append(relation_value)
		if _matches_sequence_with_overrides(
			values,
			sequence_overrides,
			allow_one_gap,
			index + 1,
			next_candidate
		):
			return true
	return false

func _matches_sequence(
	values: Array[int],
	allow_one_gap: bool
) -> bool:
	var sorted_values := values.duplicate()
	sorted_values.sort()
	var gap_count := 0
	for index in range(1, sorted_values.size()):
		var difference: int = (
			sorted_values[index] - sorted_values[index - 1]
		)
		if difference == 2:
			gap_count += 1
		elif difference != 1:
			return false
	return gap_count == 0 or (gap_count == 1 and allow_one_gap)

func _sum(values: Array[int]) -> int:
	var total := 0
	for value in values:
		total += value
	return total
