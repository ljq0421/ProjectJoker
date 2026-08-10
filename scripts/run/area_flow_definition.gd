class_name AreaFlowDefinition
extends RefCounted

enum StepType {
	ROUTE,
	NORMAL_ROOM,
	RANDOM_EVENT,
	ELITE_ROOM,
	CHOICE_ROOM,
	ENGRAVING_ROOM,
	SHOP,
	DEALER,
}

var area_id: StringName
var steps: Array[Dictionary] = []

func _init(p_area_id: StringName = &"gold_corridor") -> void:
	area_id = p_area_id
	steps = _build_steps(p_area_id)

func step(cursor: int) -> Dictionary:
	if cursor < 0 or cursor >= steps.size():
		return {}
	return steps[cursor].duplicate(true)

func type_at(cursor: int) -> StepType:
	return int(step(cursor).get("type", StepType.ROUTE))

func set_selected_room(cursor: int, room_id: StringName) -> void:
	if cursor < 0 or cursor >= steps.size():
		return
	if int(steps[cursor].get("type", -1)) == StepType.NORMAL_ROOM:
		steps[cursor]["room_id"] = room_id

func to_snapshot() -> Array[Dictionary]:
	return steps.duplicate(true)

func restore_snapshot(snapshot: Array) -> OperationResult:
	if snapshot.size() != 9:
		return OperationResult.new(false, "区域步骤序列必须包含九个步骤")
	var restored: Array[Dictionary] = []
	for index in snapshot.size():
		var entry = snapshot[index]
		if not entry is Dictionary or not entry.has("type"):
			return OperationResult.new(false, "区域步骤条目格式无效")
		var type := int(entry["type"])
		if type < StepType.ROUTE or type > StepType.DEALER:
			return OperationResult.new(false, "区域步骤类型无效")
		restored.append(entry.duplicate(true))
	steps = restored
	return OperationResult.new(true)

func _build_steps(p_area_id: StringName) -> Array[Dictionary]:
	var first_special := StepType.RANDOM_EVENT
	var second_special := StepType.RANDOM_EVENT
	if p_area_id == &"mirror_hall":
		second_special = StepType.ELITE_ROOM
	elif p_area_id == &"faceless_hub":
		first_special = StepType.CHOICE_ROOM
		second_special = StepType.ENGRAVING_ROOM
	return [
		{"type": StepType.ROUTE, "route_index": 0},
		{"type": StepType.NORMAL_ROOM, "room_id": &""},
		{"type": first_special},
		{"type": StepType.SHOP, "shop_index": 0},
		{"type": StepType.ROUTE, "route_index": 1},
		{"type": StepType.NORMAL_ROOM, "room_id": &""},
		{"type": second_special},
		{"type": StepType.SHOP, "shop_index": 1},
		{"type": StepType.DEALER},
	]
