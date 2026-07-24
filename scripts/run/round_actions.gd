class_name RoundActions
extends RefCounted

static func adjust_die(state: RoundState, die_id: StringName, delta: int) -> ActionResult:
	if delta != -1 and delta != 1:
		return ActionResult.new(false, "校准只能调整 -1 或 +1", state)
	if state.calibration_points <= 0:
		return ActionResult.new(false, "校准点已经用完", state)
	var current := state.find_die(die_id)
	if current == null:
		return ActionResult.new(false, "骰子不存在", state)
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
	if state.find_die(die_id) == null:
		return ActionResult.new(false, "骰子不存在", state)
	if table_id == &"":
		return ActionResult.new(false, "请选择规则轨", state)

	var occupied: Array = state.assignments.get(table_id, [])
	if die_id not in occupied and occupied.size() >= slot_limit:
		return ActionResult.new(false, "规则轨已经放满", state)

	var next_state := state.clone()
	for assigned_table_id in next_state.assignments:
		next_state.assignments[assigned_table_id].erase(die_id)
	if not next_state.assignments.has(table_id):
		next_state.assignments[table_id] = []
	if die_id not in next_state.assignments[table_id]:
		next_state.assignments[table_id].append(die_id)
	return ActionResult.new(true, "", next_state)

static func unassign_die(state: RoundState, die_id: StringName) -> ActionResult:
	var next_state := state.clone()
	var removed := false
	for table_id in next_state.assignments:
		if die_id in next_state.assignments[table_id]:
			next_state.assignments[table_id].erase(die_id)
			removed = true
	if not removed:
		return ActionResult.new(false, "骰子尚未分配", state)
	return ActionResult.new(true, "", next_state)
