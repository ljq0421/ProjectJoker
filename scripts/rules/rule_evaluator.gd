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
	if definition.template != null:
		for modifier in condition_modifiers:
			if not definition.template.supports_condition_modifier(modifier):
				return RuleResult.new(false, 0, 0, "规则条件不支持当前修改")

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
	if definition.template != null:
		return _matches_template(
			definition,
			values,
			parity_overrides,
			condition_modifiers,
			sequence_overrides
		)
	return _matches_legacy(
		definition,
		values,
		parity_overrides,
		condition_modifiers,
		sequence_overrides
	)

func _matches_template(
	definition: RuleDefinition,
	values: Array[int],
	parity_overrides: Array[bool],
	condition_modifiers: Array,
	sequence_overrides: Array[bool]
) -> bool:
	match definition.template.condition_kind:
		RuleTableTemplate.ConditionKind.ANY_FILLED:
			return true
		RuleTableTemplate.ConditionKind.EXACT_SUM:
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
		RuleTableTemplate.ConditionKind.MINIMUM_SUM:
			return _sum(values) >= definition.target_value
		RuleTableTemplate.ConditionKind.MAXIMUM_SUM:
			return _sum(values) <= definition.target_value
		RuleTableTemplate.ConditionKind.SUM_RANGE:
			var total := _sum(values)
			return total >= definition.minimum_value and total <= definition.maximum_value
		RuleTableTemplate.ConditionKind.ALL_EQUAL:
			return _all_equal(values)
		RuleTableTemplate.ConditionKind.ALL_DISTINCT:
			return _all_distinct(values)
		RuleTableTemplate.ConditionKind.ALL_EVEN:
			var odd_count := 0
			for index in range(values.size()):
				if not _is_effectively_even(values[index], index, parity_overrides):
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
		RuleTableTemplate.ConditionKind.ALL_ODD:
			for index in range(values.size()):
				if _is_effectively_even(values[index], index, parity_overrides):
					return false
			return true
		RuleTableTemplate.ConditionKind.SAME_PARITY:
			var first_even := _is_effectively_even(values[0], 0, parity_overrides)
			for index in range(1, values.size()):
				if (
					_is_effectively_even(values[index], index, parity_overrides)
					!= first_even
				):
					return false
			return true
		RuleTableTemplate.ConditionKind.CONSECUTIVE:
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
		RuleTableTemplate.ConditionKind.FIXED_DIFFERENCE:
			return _matches_fixed_difference(values, definition.difference)
		RuleTableTemplate.ConditionKind.STRICT_ASCENDING:
			return _is_strictly_ordered(values, true)
		RuleTableTemplate.ConditionKind.STRICT_DESCENDING:
			return _is_strictly_ordered(values, false)
		RuleTableTemplate.ConditionKind.MIRRORED:
			return _is_mirrored(values)
		RuleTableTemplate.ConditionKind.SLOT_TARGETS:
			if definition.slot_targets.size() != values.size():
				return false
			for index in range(values.size()):
				if values[index] != definition.slot_targets[index]:
					return false
			return true
	return false

func _matches_legacy(
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

func _all_equal(values: Array[int]) -> bool:
	for index in range(1, values.size()):
		if values[index] != values[0]:
			return false
	return true

func _all_distinct(values: Array[int]) -> bool:
	var seen: Dictionary = {}
	for value in values:
		if seen.has(value):
			return false
		seen[value] = true
	return true

func _is_effectively_even(
	value: int,
	index: int,
	parity_overrides: Array[bool]
) -> bool:
	return (
		value % 2 == 0
		or (
			not parity_overrides.is_empty()
			and parity_overrides[index]
		)
	)

func _matches_fixed_difference(values: Array[int], difference: int) -> bool:
	var sorted_values := values.duplicate()
	sorted_values.sort()
	for index in range(1, sorted_values.size()):
		if sorted_values[index] - sorted_values[index - 1] != difference:
			return false
	return true

func _is_strictly_ordered(values: Array[int], ascending: bool) -> bool:
	for index in range(1, values.size()):
		if ascending and values[index] <= values[index - 1]:
			return false
		if not ascending and values[index] >= values[index - 1]:
			return false
	return true

func _is_mirrored(values: Array[int]) -> bool:
	for index in range(values.size() / 2):
		if values[index] != values[values.size() - 1 - index]:
			return false
	return true

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
