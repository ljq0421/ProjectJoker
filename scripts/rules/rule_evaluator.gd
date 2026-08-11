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
	var result := _evaluate_without_diagnostics(
		definition,
		values,
		coefficient_modifier,
		parity_overrides,
		condition_modifiers,
		effective_slot_count,
		sequence_overrides
	)
	result.diagnostics = _build_diagnostics(
		definition,
		values,
		result.valid,
		effective_slot_count
	)
	return result

func _evaluate_without_diagnostics(
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

func _build_diagnostics(
	definition: RuleDefinition,
	values: Array,
	valid: bool,
	effective_slot_count: int
) -> Dictionary:
	var required_slots := definition.slot_count if effective_slot_count < 0 else effective_slot_count
	var typed_values: Array[int] = []
	for value in values:
		var int_value := int(value)
		if int_value >= 1 and int_value <= 6:
			typed_values.append(int_value)
	if typed_values.size() != required_slots:
		return {
			"kind": &"slot_count",
			"actual": typed_values.size(),
			"target": required_slots,
			"delta": typed_values.size() - required_slots,
			"valid": false,
			"failure_reason": "还差 %d 个槽位" % maxi(required_slots - typed_values.size(), 0),
			"slots": [],
		}

	var kind := (
		definition.template.condition_kind
		if definition.template != null
		else _legacy_diagnostic_kind(definition.condition_type)
	)
	var actual: Variant = _sum(typed_values)
	var target: Variant = definition.target_value
	var delta := 0
	var slots: Array[Dictionary] = []
	for index in range(typed_values.size()):
		slots.append({
			"index": index,
			"value": typed_values[index],
			"target": null,
			"state": &"pass" if valid else &"fail",
			"relation": &"",
		})

	match kind:
		RuleTableTemplate.ConditionKind.EXACT_SUM:
			delta = int(actual) - int(target)
		RuleTableTemplate.ConditionKind.MINIMUM_SUM:
			delta = int(actual) - int(target)
		RuleTableTemplate.ConditionKind.MAXIMUM_SUM:
			delta = int(target) - int(actual)
		RuleTableTemplate.ConditionKind.SUM_RANGE:
			target = [definition.minimum_value, definition.maximum_value]
			if int(actual) < definition.minimum_value:
				delta = int(actual) - definition.minimum_value
			elif int(actual) > definition.maximum_value:
				delta = definition.maximum_value - int(actual)
		RuleTableTemplate.ConditionKind.ALL_EVEN:
			actual = typed_values.duplicate()
			target = "偶数"
			for index in range(typed_values.size()):
				slots[index]["state"] = &"pass" if typed_values[index] % 2 == 0 else &"fail"
		RuleTableTemplate.ConditionKind.ALL_ODD:
			actual = typed_values.duplicate()
			target = "奇数"
			for index in range(typed_values.size()):
				slots[index]["state"] = &"pass" if typed_values[index] % 2 != 0 else &"fail"
		RuleTableTemplate.ConditionKind.ALL_EQUAL:
			actual = typed_values.duplicate()
			target = typed_values[0]
			for index in range(typed_values.size()):
				slots[index]["state"] = &"pass" if typed_values[index] == target else &"fail"
		RuleTableTemplate.ConditionKind.ALL_DISTINCT:
			actual = typed_values.duplicate()
			target = "互不相同"
			for index in range(typed_values.size()):
				slots[index]["state"] = &"pass" if typed_values.count(typed_values[index]) == 1 else &"fail"
		RuleTableTemplate.ConditionKind.STRICT_ASCENDING:
			actual = typed_values.duplicate()
			target = "严格递增"
			for index in range(typed_values.size()):
				slots[index]["relation"] = &"up" if index > 0 else &"start"
				slots[index]["state"] = &"pass" if index == 0 or typed_values[index] > typed_values[index - 1] else &"fail"
		RuleTableTemplate.ConditionKind.STRICT_DESCENDING:
			actual = typed_values.duplicate()
			target = "严格递减"
			for index in range(typed_values.size()):
				slots[index]["relation"] = &"down" if index > 0 else &"start"
				slots[index]["state"] = &"pass" if index == 0 or typed_values[index] < typed_values[index - 1] else &"fail"
		RuleTableTemplate.ConditionKind.MIRRORED:
			actual = typed_values.duplicate()
			target = "镜像对称"
			for index in range(typed_values.size()):
				var mirror_index := typed_values.size() - 1 - index
				slots[index]["target"] = typed_values[mirror_index]
				slots[index]["relation"] = &"mirror"
				slots[index]["state"] = &"pass" if typed_values[index] == typed_values[mirror_index] else &"fail"
		RuleTableTemplate.ConditionKind.SLOT_TARGETS:
			actual = typed_values.duplicate()
			target = Array(definition.slot_targets)
			for index in range(typed_values.size()):
				var slot_target := (
					int(definition.slot_targets[index])
					if index < definition.slot_targets.size()
					else 0
				)
				slots[index]["target"] = slot_target
				slots[index]["relation"] = &"exact"
				slots[index]["state"] = &"pass" if typed_values[index] == slot_target else &"fail"
		_:
			actual = typed_values.duplicate()
			target = _diagnostic_target_copy(kind, definition)

	return {
		"kind": kind,
		"actual": actual,
		"target": target,
		"delta": delta,
		"valid": valid,
		"failure_reason": "" if valid else _diagnostic_failure_reason(kind, actual, target, delta, slots),
		"slots": slots,
	}

func _legacy_diagnostic_kind(
	condition_type: RuleDefinition.ConditionType
) -> RuleTableTemplate.ConditionKind:
	match condition_type:
		RuleDefinition.ConditionType.ALL_EVEN:
			return RuleTableTemplate.ConditionKind.ALL_EVEN
		RuleDefinition.ConditionType.CONSECUTIVE:
			return RuleTableTemplate.ConditionKind.CONSECUTIVE
	return RuleTableTemplate.ConditionKind.EXACT_SUM

func _diagnostic_target_copy(kind: int, definition: RuleDefinition) -> Variant:
	match kind:
		RuleTableTemplate.ConditionKind.CONSECUTIVE:
			return "连续"
		RuleTableTemplate.ConditionKind.FIXED_DIFFERENCE:
			return "固定差 %d" % definition.difference
		RuleTableTemplate.ConditionKind.SAME_PARITY:
			return "同奇偶"
	return definition.target_value

func _diagnostic_failure_reason(
	kind: int,
	actual: Variant,
	target: Variant,
	delta: int,
	slots: Array[Dictionary]
) -> String:
	match kind:
		RuleTableTemplate.ConditionKind.EXACT_SUM:
			return "当前总和 %s，距离目标 %s 还差 %+d" % [actual, target, -delta]
		RuleTableTemplate.ConditionKind.MINIMUM_SUM:
			return "当前总和 %s，距离下限 %s 还差 %d" % [actual, target, maxi(-delta, 0)]
		RuleTableTemplate.ConditionKind.MAXIMUM_SUM:
			return "当前总和 %s，超过上限 %s 共 %d" % [actual, target, maxi(-delta, 0)]
		RuleTableTemplate.ConditionKind.SUM_RANGE:
			return "当前总和 %s，不在目标区间 %s 内" % [actual, target]
		RuleTableTemplate.ConditionKind.STRICT_ASCENDING:
			return "骰面未按槽位严格递增"
		RuleTableTemplate.ConditionKind.STRICT_DESCENDING:
			return "骰面未按槽位严格递减"
		RuleTableTemplate.ConditionKind.MIRRORED:
			return "镜轴两侧骰面不对称"
		RuleTableTemplate.ConditionKind.SLOT_TARGETS:
			return "有 %d 个槽位未达到指定骰面" % _failed_diagnostic_slot_count(slots)
	return "实际值 %s 未满足目标 %s" % [actual, target]

func _failed_diagnostic_slot_count(slots: Array[Dictionary]) -> int:
	var count := 0
	for slot in slots:
		if slot.get("state", &"fail") == &"fail":
			count += 1
	return count
