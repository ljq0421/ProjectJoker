class_name RoundActions
extends RefCounted

static func adjust_die(
	state: RoundState,
	die_id: StringName,
	delta: int,
	context: ResolutionContext = null
) -> ActionResult:
	if delta != -1 and delta != 1:
		return ActionResult.new(false, "校准只能调整 -1 或 +1", state)
	if state.calibration_points <= 0:
		return ActionResult.new(false, "校准点已经用完", state)
	var current := state.find_die(die_id)
	if current == null:
		return ActionResult.new(false, "骰子不存在", state)
	var block_reason := EngravingResolver.new().modification_block_reason(
		state, die_id, context
	)
	if not block_reason.is_empty():
		return ActionResult.new(false, block_reason, state)
	var next_value := current.value + delta
	if next_value < 1 or next_value > 6:
		return ActionResult.new(false, "校准后点数必须在 1 到 6 之间", state)

	var next_state := state.clone()
	next_state.find_die(die_id).value = next_value
	next_state.calibration_points -= 1
	return ActionResult.new(true, "", next_state)

static func assign_die(
	state: RoundState,
	die_id: StringName,
	table_id: StringName,
	slot_limit: int
) -> ActionResult:
	var slots := state.slot_values(table_id, slot_limit)
	var target_index := slots.find(RoundState.EMPTY_SLOT)
	var current := state.find_assignment(die_id)
	if (
		target_index < 0
		and not current.is_empty()
		and current.get("table_id") == table_id
	):
		return ActionResult.new(true, "", state.clone())
	if target_index < 0:
		return ActionResult.new(false, "规则轨已经放满", state)
	return assign_die_to_slot(
		state,
		die_id,
		table_id,
		target_index,
		slot_limit
	)

static func assign_die_to_slot(
	state: RoundState,
	die_id: StringName,
	table_id: StringName,
	slot_index: int,
	slot_limit: int
) -> ActionResult:
	if state.find_die(die_id) == null:
		return ActionResult.new(false, "骰子不存在", state)
	if table_id == &"":
		return ActionResult.new(false, "请选择规则轨", state)
	if slot_limit <= 0 or slot_index < 0 or slot_index >= slot_limit:
		return ActionResult.new(false, "骰位不存在", state)

	var next_state := state.clone()
	next_state.assignments[table_id] = next_state.slot_values(
		table_id,
		slot_limit
	)
	var target_slots: Array = next_state.assignments[table_id]
	var target_die_id: StringName = target_slots[slot_index]
	var source := next_state.find_assignment(die_id)
	if source.is_empty():
		if target_die_id != RoundState.EMPTY_SLOT:
			return ActionResult.new(false, "空闲骰子不能覆盖已占用骰位", state)
		target_slots[slot_index] = die_id
		return ActionResult.new(true, "", next_state)

	var source_table_id: StringName = source.get("table_id")
	var source_slot_index: int = source.get("slot_index")
	if source_table_id == table_id and source_slot_index == slot_index:
		return ActionResult.new(true, "", next_state)

	var source_slots: Array = next_state.assignments[source_table_id]
	source_slots[source_slot_index] = target_die_id
	target_slots[slot_index] = die_id
	return ActionResult.new(true, "", next_state)

static func unassign_die(state: RoundState, die_id: StringName) -> ActionResult:
	var next_state := state.clone()
	var source := next_state.find_assignment(die_id)
	if source.is_empty():
		return ActionResult.new(false, "骰子尚未分配", state)
	var source_slots: Array = next_state.assignments[source.get("table_id")]
	source_slots[source.get("slot_index")] = RoundState.EMPTY_SLOT
	return ActionResult.new(true, "", next_state)
