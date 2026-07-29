class_name ExpeditionSession
extends RefCounted

enum Status {
	NOT_STARTED,
	ACTIVE,
	COMPLETE,
	FAILED,
}

const AREA_ORDER: Array[StringName] = [
	&"gold_corridor",
	&"mirror_hall",
	&"faceless_hub",
]

var status: Status = Status.NOT_STARTED
var seed_value := 0
var current_area_index := 0
var inherited_state: Dictionary = {}
var area_checkpoint: Dictionary = {}
var completed_areas: Array[Dictionary] = []
var failure_reason := ""

func start_new(seed: int) -> OperationResult:
	if status != Status.NOT_STARTED:
		return OperationResult.new(false, "远征已经开始")
	if seed <= 0:
		return OperationResult.new(false, "远征种子必须为正整数")
	status = Status.ACTIVE
	seed_value = seed
	current_area_index = 0
	inherited_state = {}
	area_checkpoint = {}
	completed_areas = []
	failure_reason = ""
	return OperationResult.new(true)

func current_area_id() -> StringName:
	if status != Status.ACTIVE or current_area_index >= AREA_ORDER.size():
		return &""
	return AREA_ORDER[current_area_index]

func current_entry_state() -> Dictionary:
	return inherited_state.duplicate(true)

func can_continue() -> bool:
	return status == Status.ACTIVE

func set_area_checkpoint(checkpoint: Dictionary) -> OperationResult:
	if status != Status.ACTIVE:
		return OperationResult.new(false, "当前远征不能写入区域检查点")
	if not checkpoint is Dictionary or checkpoint.is_empty():
		return OperationResult.new(false, "区域检查点不能为空")
	var area_id: StringName = checkpoint.get("area_id", &"")
	if area_id != current_area_id():
		return OperationResult.new(false, "区域检查点与当前地区不一致")
	area_checkpoint = checkpoint.duplicate(true)
	return OperationResult.new(true)

func complete_current_area(completion: Dictionary) -> OperationResult:
	if status != Status.ACTIVE:
		return OperationResult.new(false, "当前远征不能完成区域")
	var error := _completion_error(completion, current_area_id())
	if not error.is_empty():
		return OperationResult.new(false, error)
	var next_completed := completed_areas.duplicate(true)
	next_completed.append(completion.duplicate(true))
	var next_inherited := {
		"deck_ids": completion["deck_ids"].duplicate(),
		"intel_tickets": completion["intel_tickets"],
		"die_profiles": completion["die_profiles"].duplicate(true),
		"rng_state": completion["rng_state"],
	}
	completed_areas = next_completed
	inherited_state = next_inherited
	area_checkpoint = {}
	current_area_index += 1
	if current_area_index >= AREA_ORDER.size():
		status = Status.COMPLETE
	return OperationResult.new(true)

func fail_run(reason: String) -> OperationResult:
	if status != Status.ACTIVE:
		return OperationResult.new(false, "当前远征不能失败结算")
	status = Status.FAILED
	failure_reason = reason.strip_edges()
	area_checkpoint = {}
	return OperationResult.new(true)

func to_snapshot() -> Dictionary:
	return {
		"status": status,
		"seed_value": seed_value,
		"current_area_index": current_area_index,
		"inherited_state": inherited_state.duplicate(true),
		"area_checkpoint": area_checkpoint.duplicate(true),
		"completed_areas": completed_areas.duplicate(true),
		"failure_reason": failure_reason,
	}

func restore_snapshot(snapshot: Dictionary) -> OperationResult:
	var error := snapshot_error(snapshot)
	if not error.is_empty():
		return OperationResult.new(false, error)
	status = snapshot["status"]
	seed_value = snapshot["seed_value"]
	current_area_index = snapshot["current_area_index"]
	inherited_state = snapshot["inherited_state"].duplicate(true)
	area_checkpoint = snapshot["area_checkpoint"].duplicate(true)
	completed_areas = snapshot["completed_areas"].duplicate(true)
	failure_reason = snapshot["failure_reason"]
	return OperationResult.new(true)

static func snapshot_error(snapshot: Dictionary) -> String:
	for key in [
		"status",
		"seed_value",
		"current_area_index",
		"inherited_state",
		"area_checkpoint",
		"completed_areas",
		"failure_reason",
	]:
		if not snapshot.has(key):
			return "远征存档缺少字段：%s" % key
	if (
		not snapshot["status"] is int
		or snapshot["status"] < Status.NOT_STARTED
		or snapshot["status"] > Status.FAILED
	):
		return "远征状态无效"
	if not snapshot["seed_value"] is int or snapshot["seed_value"] <= 0:
		return "远征种子无效"
	if not snapshot["current_area_index"] is int:
		return "当前区域序号无效"
	var status_value: int = snapshot["status"]
	var index: int = snapshot["current_area_index"]
	if status_value == Status.ACTIVE and (index < 0 or index >= AREA_ORDER.size()):
		return "进行中远征的区域序号越界"
	if status_value == Status.COMPLETE and index != AREA_ORDER.size():
		return "已完成远征的区域序号无效"
	if not snapshot["inherited_state"] is Dictionary:
		return "跨区状态格式无效"
	if not snapshot["area_checkpoint"] is Dictionary:
		return "区域检查点格式无效"
	if not snapshot["completed_areas"] is Array:
		return "区域完成记录格式无效"
	if snapshot["completed_areas"].size() != mini(index, AREA_ORDER.size()):
		return "区域完成记录数量与进度不一致"
	for completion_index in range(snapshot["completed_areas"].size()):
		var completion = snapshot["completed_areas"][completion_index]
		if not completion is Dictionary:
			return "区域完成记录条目无效"
		var error := _completion_error(completion, AREA_ORDER[completion_index])
		if not error.is_empty():
			return error
	if not snapshot["failure_reason"] is String:
		return "失败原因格式无效"
	if status_value == Status.ACTIVE and not snapshot["area_checkpoint"].is_empty():
		if (
			snapshot["area_checkpoint"].get("area_id", &"")
			!= AREA_ORDER[index]
		):
			return "区域检查点与当前远征区域不一致"
		var area_catalog := AreaCatalog.new()
		var area_definition: AreaDefinition
		match AREA_ORDER[index]:
			&"gold_corridor":
				area_definition = area_catalog.gold_corridor()
			&"mirror_hall":
				area_definition = area_catalog.mirror_hall()
			&"faceless_hub":
				area_definition = area_catalog.faceless_hub()
		if area_definition == null:
			return "区域检查点引用的地区不存在"
		var area_session := AreaRunSession.new(
			snapshot["seed_value"],
			area_definition
		)
		var restored := area_session.restore_checkpoint(
			snapshot["area_checkpoint"]
		)
		if not restored.accepted:
			return restored.reason
	return ""

static func _completion_error(completion: Dictionary, expected_id: StringName) -> String:
	for key in ["area_id", "rng_state", "deck_ids", "intel_tickets", "die_profiles"]:
		if not completion.has(key):
			return "区域完成记录缺少字段：%s" % key
	if completion["area_id"] != expected_id:
		return "区域完成顺序无效"
	if not completion["rng_state"] is int:
		return "区域随机状态无效"
	if not completion["deck_ids"] is Array or completion["deck_ids"].size() != 12:
		return "跨区牌组必须包含十二张牌"
	var seen_cards: Dictionary = {}
	for card_id in completion["deck_ids"]:
		if card_id == &"" or seen_cards.has(card_id):
			return "跨区牌组包含空或重复 ID"
		seen_cards[card_id] = true
	if not completion["intel_tickets"] is int or completion["intel_tickets"] < 0:
		return "跨区情报券无效"
	if not completion["die_profiles"] is Array or completion["die_profiles"].size() != 6:
		return "跨区骰子配置必须包含六颗骰子"
	return ""
