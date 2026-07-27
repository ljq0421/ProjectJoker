class_name EngravingResolver
extends RefCounted

func active_definition(
	die: DieState,
	context: ResolutionContext
) -> EngravingDefinition:
	if (
		die == null
		or die.engraving_id == &""
		or die.engraved_face < 1
		or die.engraved_face > 6
		or die.rolled_value != die.engraved_face
		or context == null
		or context.engraving_catalog == null
	):
		return null
	return context.engraving_catalog.find_engraving(die.engraving_id)

func modification_block_reason(
	state: RoundState,
	die_id: StringName,
	context: ResolutionContext
) -> String:
	if die_id in state.locked_die_ids():
		return "定格手法已生效，这颗骰子本轮不能再修改点数"
	var definition := active_definition(state.find_die(die_id), context)
	if (
		definition != null
		and definition.operation in [
			EngravingDefinition.Operation.ANCHOR_DIE,
			EngravingDefinition.Operation.ANCHOR_LAST_TABLE,
		]
	):
		return "锚定刻印已激活，这颗骰子本轮不能修改点数"
	return ""

func parity_overrides(
	state: RoundState,
	assigned_ids: Array,
	rule_id: StringName,
	context: ResolutionContext
) -> Array[bool]:
	var flags: Array[bool] = []
	for die_id in assigned_ids:
		var definition := active_definition(state.find_die(die_id), context)
		flags.append(
			definition != null
			and (
				definition.operation == EngravingDefinition.Operation.PRISM_PARITY
				or (
					definition.operation
						== EngravingDefinition.Operation.MIRROR_PRISM
					and _has_adjacent_mirror_copy(state, rule_id)
				)
			)
		)
	return flags

func sequence_overrides(
	state: RoundState,
	assigned_ids: Array,
	context: ResolutionContext
) -> Array[bool]:
	var flags: Array[bool] = []
	for die_id in assigned_ids:
		var definition := active_definition(state.find_die(die_id), context)
		flags.append(
			definition != null
			and (
				definition.operation
				== EngravingDefinition.Operation.PRISM_SEQUENCE
			)
		)
	return flags

func table_outcomes(
	state: RoundState,
	assigned_ids: Array,
	source_valid: bool,
	ordered_rule_ids: Array[StringName],
	rule_index: int,
	die_values: Dictionary,
	context: ResolutionContext
) -> Array[EngravingOutcome]:
	var outcomes: Array[EngravingOutcome] = []
	for slot_index in range(assigned_ids.size()):
		var die_id: StringName = assigned_ids[slot_index]
		var die := state.find_die(die_id)
		var definition := active_definition(die, context)
		if definition == null:
			continue
		if not source_valid:
			outcomes.append(EngravingOutcome.new(
				definition.id,
				"%s：来源规则台未通过" % definition.display_name,
				0,
				&"",
				false
			))
			continue

		match definition.operation:
			EngravingDefinition.Operation.ECHO_ADJACENT:
				var neighbor_values: Array[int] = []
				if slot_index > 0:
					neighbor_values.append(
						int(die_values.get(assigned_ids[slot_index - 1], 0))
					)
				if slot_index + 1 < assigned_ids.size():
					neighbor_values.append(
						int(die_values.get(assigned_ids[slot_index + 1], 0))
					)
				if neighbor_values.is_empty():
					outcomes.append(EngravingOutcome.new(
						definition.id,
						"%s：没有相邻骰" % definition.display_name,
						0,
						&"",
						false
					))
				else:
					var higher_neighbor: int = int(neighbor_values.max())
					outcomes.append(EngravingOutcome.new(
						definition.id,
						"%s：相邻骰 %d ÷ %d" % [
							definition.display_name,
							higher_neighbor,
							definition.amount,
						],
						floori(float(higher_neighbor) / float(definition.amount))
					))
			EngravingDefinition.Operation.ECHO_LOWER_ADJACENT:
				var neighbor_values: Array[int] = []
				if slot_index > 0:
					neighbor_values.append(
						int(die_values.get(assigned_ids[slot_index - 1], 0))
					)
				if slot_index + 1 < assigned_ids.size():
					neighbor_values.append(
						int(die_values.get(assigned_ids[slot_index + 1], 0))
					)
				if neighbor_values.is_empty():
					outcomes.append(EngravingOutcome.new(
						definition.id,
						"%s：没有相邻骰" % definition.display_name,
						0,
						&"",
						false
					))
				else:
					var lower_neighbor: int = int(neighbor_values.min())
					outcomes.append(EngravingOutcome.new(
						definition.id,
						"%s：复制较低相邻骰 %d" % [
							definition.display_name,
							lower_neighbor,
						],
						lower_neighbor
					))
			EngravingDefinition.Operation.ANCHOR_DIE:
				outcomes.append(EngravingOutcome.new(
					definition.id,
					"%s：固定奖励 +%d" % [definition.display_name, definition.amount],
					definition.amount
				))
			EngravingDefinition.Operation.ANCHOR_LAST_TABLE:
				var is_last := rule_index == ordered_rule_ids.size() - 1
				outcomes.append(EngravingOutcome.new(
					definition.id,
					(
						"%s：最后结算规则台固定奖励 +%d"
						% [definition.display_name, definition.amount]
						if is_last
						else "%s：当前不是最后结算规则台"
							% definition.display_name
					),
					definition.amount if is_last else 0,
					&"",
					is_last
				))
			EngravingDefinition.Operation.BRIDGE_FORWARD:
				if rule_index + 1 >= ordered_rule_ids.size():
					outcomes.append(EngravingOutcome.new(
						definition.id,
						"%s：当前方向没有下一张规则台" % definition.display_name,
						0,
						&"",
						false
					))
				else:
					var target_table_id: StringName = ordered_rule_ids[rule_index + 1]
					outcomes.append(EngravingOutcome.new(
						definition.id,
						"%s：%s → %s" % [
							definition.display_name,
							ordered_rule_ids[rule_index],
							target_table_id,
						],
						int(die_values.get(die_id, die.value)),
						target_table_id
					))
			EngravingDefinition.Operation.BRIDGE_BACKWARD:
				if rule_index <= 0:
					outcomes.append(EngravingOutcome.new(
						definition.id,
						"%s：当前方向没有上一张规则台" % definition.display_name,
						0,
						&"",
						false
					))
				else:
					var target_table_id: StringName = ordered_rule_ids[rule_index - 1]
					outcomes.append(EngravingOutcome.new(
						definition.id,
						"%s：%s → %s" % [
							definition.display_name,
							ordered_rule_ids[rule_index],
							target_table_id,
						],
						int(die_values.get(die_id, die.value)),
						target_table_id
					))
			EngravingDefinition.Operation.BRIDGE_BIDIRECTIONAL:
				var transfer_value := floori(
					float(die_values.get(die_id, die.value))
					/ float(definition.amount)
				)
				var neighbor_indexes := [rule_index - 1, rule_index + 1]
				for neighbor_index in neighbor_indexes:
					if (
						neighbor_index < 0
						or neighbor_index >= ordered_rule_ids.size()
					):
						continue
					var target_table_id: StringName = (
						ordered_rule_ids[neighbor_index]
					)
					outcomes.append(EngravingOutcome.new(
						definition.id,
						"%s：%s → %s" % [
							definition.display_name,
							ordered_rule_ids[rule_index],
							target_table_id,
						],
						transfer_value,
						target_table_id
					))
			EngravingDefinition.Operation.PRISM_PARITY:
				outcomes.append(EngravingOutcome.new(
					definition.id,
					"%s：同时视为奇数与偶数" % definition.display_name,
					0
				))
			EngravingDefinition.Operation.MIRROR_PRISM:
				var current_rule_id: StringName = ordered_rule_ids[rule_index]
				var is_adjacent := _has_adjacent_mirror_copy(
					state,
					current_rule_id
				)
				outcomes.append(EngravingOutcome.new(
					definition.id,
					(
						"%s：邻接镜像副本，同时视为奇数与偶数"
						if is_adjacent
						else "%s：没有邻接镜像副本"
					) % definition.display_name,
					0,
					&"",
					is_adjacent
				))
			EngravingDefinition.Operation.PRISM_SEQUENCE:
				outcomes.append(EngravingOutcome.new(
					definition.id,
					"%s：关系值可视为高一或低一" % definition.display_name,
					0
				))
	return outcomes

func _has_adjacent_mirror_copy(
	state: RoundState,
	rule_id: StringName
) -> bool:
	for played_card in state.played_cards:
		if (
			played_card.is_mirror_copy
			and (
				played_card.primary_target == rule_id
				or played_card.secondary_target == rule_id
			)
		):
			return true
	return false
