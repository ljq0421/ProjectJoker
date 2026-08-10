class_name ExpeditionSession
extends RefCounted

const ExpeditionConfigs = preload("res://scripts/run/expedition_config_catalog.gd")
const ModifierCatalog = preload("res://scripts/run/area_run_modifier_catalog.gd")

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
var run_id: StringName = &""
var starting_deck_id: StringName = ExpeditionConfigs.DICE_CONTROL
var challenge_ids: Array[StringName] = []
var current_area_index := 0
var inherited_state: Dictionary = {}
var area_checkpoint: Dictionary = {}
var completed_areas: Array[Dictionary] = []
var failure_reason := ""

func start_new(
	seed: int,
	p_starting_deck_id: StringName = ExpeditionConfigs.DICE_CONTROL,
	p_challenge_ids: Array[StringName] = []
) -> OperationResult:
	if status != Status.NOT_STARTED:
		return OperationResult.new(false, "远征已经开始")
	if seed <= 0:
		return OperationResult.new(false, "远征种子必须为正整数")
	var selection_error := ExpeditionConfigs.new().selection_error(
		p_starting_deck_id,
		p_challenge_ids,
		true
	)
	if not selection_error.is_empty():
		return OperationResult.new(false, selection_error)
	status = Status.ACTIVE
	seed_value = seed
	run_id = StringName("%d-%d" % [seed, Time.get_ticks_usec()])
	starting_deck_id = p_starting_deck_id
	challenge_ids.assign(p_challenge_ids)
	current_area_index = 0
	inherited_state = _initial_entry_state()
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
		"lucky_faces": completion.get("lucky_faces", {}).duplicate(true),
		"challenge_ids": challenge_ids.duplicate(),
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
		"run_id": run_id,
		"starting_deck_id": starting_deck_id,
		"challenge_ids": challenge_ids.duplicate(),
		"current_area_index": current_area_index,
		"inherited_state": inherited_state.duplicate(true),
		"area_checkpoint": area_checkpoint.duplicate(true),
		"completed_areas": completed_areas.duplicate(true),
		"failure_reason": failure_reason,
		"balance_telemetry": balance_telemetry_snapshot(),
	}

func balance_telemetry_snapshot() -> Dictionary:
	var aggregate := {
		"consolation_rounds": 0,
		"resonance_rounds": 0,
		"storm_rounds": 0,
		"emergency_rerolls": 0,
		"emergency_calibrations": 0,
		"emergency_retries": 0,
		"emergency_spend_total": 0,
		"deck_size_total": 0,
		"intel_balance_total": 0,
		"sample_count": 0,
	}
	var sources: Array[Dictionary] = []
	for completion in completed_areas:
		if completion is Dictionary:
			var completed_telemetry = completion.get("balance_telemetry", {})
			if completed_telemetry is Dictionary:
				sources.append(completed_telemetry)
	if not area_checkpoint.is_empty():
		var active_telemetry = area_checkpoint.get("balance_telemetry", {})
		if active_telemetry is Dictionary:
			sources.append(active_telemetry)
	for source in sources:
		for key in aggregate:
			var value = source.get(key, 0)
			if value is int and value >= 0:
				aggregate[key] += value
	var sample_count := int(aggregate["sample_count"])
	aggregate["average_deck_size"] = (
		float(aggregate["deck_size_total"]) / float(sample_count)
		if sample_count > 0
		else 0.0
	)
	aggregate["average_intel_balance"] = (
		float(aggregate["intel_balance_total"]) / float(sample_count)
		if sample_count > 0
		else 0.0
	)
	return aggregate

func restore_snapshot(snapshot: Dictionary) -> OperationResult:
	var error := snapshot_error(snapshot)
	if not error.is_empty():
		return OperationResult.new(false, error)
	status = snapshot["status"]
	seed_value = snapshot["seed_value"]
	run_id = snapshot["run_id"]
	starting_deck_id = snapshot["starting_deck_id"]
	challenge_ids.assign(snapshot["challenge_ids"])
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
		"run_id",
		"starting_deck_id",
		"challenge_ids",
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
	if not snapshot["run_id"] is String and not snapshot["run_id"] is StringName:
		return "远征局次 ID 格式无效"
	if String(snapshot["run_id"]).strip_edges().is_empty():
		return "远征局次 ID 无效"
	if (
		not snapshot["starting_deck_id"] is String
		and not snapshot["starting_deck_id"] is StringName
	):
		return "起始构筑标识格式无效"
	if not snapshot["challenge_ids"] is Array:
		return "挑战列表格式无效"
	var config_error := ExpeditionConfigs.new().selection_error(
		snapshot["starting_deck_id"],
		snapshot["challenge_ids"],
		true
	)
	if not config_error.is_empty():
		return config_error
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

func _initial_entry_state() -> Dictionary:
	var deck := ExpeditionConfigs.new().find_deck(starting_deck_id)
	var profiles: Array[Dictionary] = []
	for die_index in range(1, 7):
		profiles.append({
			"id": StringName("d%d" % die_index),
			"rolled_value": 1,
			"engraving_id": &"",
			"engraved_face": 0,
		})
	return {
		"deck_ids": deck.get("card_ids", []).duplicate(),
		"intel_tickets": AreaCatalog.new().gold_corridor().starting_intel_tickets,
		"die_profiles": profiles,
		"rng_state": RunRng.new(seed_value).snapshot_state(),
		"lucky_faces": {},
		"challenge_ids": challenge_ids.duplicate(),
	}

static func _completion_error(completion: Dictionary, expected_id: StringName) -> String:
	for key in ["area_id", "rng_state", "deck_ids", "intel_tickets", "die_profiles"]:
		if not completion.has(key):
			return "区域完成记录缺少字段：%s" % key
	if completion["area_id"] != expected_id:
		return "区域完成顺序无效"
	if not completion["rng_state"] is int:
		return "区域随机状态无效"
	if (
		not completion["deck_ids"] is Array
		or completion["deck_ids"].size() < CardDeck.MIN_DECK_SIZE
		or completion["deck_ids"].size() > CardDeck.MAX_DECK_SIZE
	):
		return "跨区牌组必须包含十二至十五张牌"
	var seen_cards: Dictionary = {}
	for card_id in completion["deck_ids"]:
		if card_id == &"" or seen_cards.has(card_id):
			return "跨区牌组包含空或重复 ID"
		seen_cards[card_id] = true
	if not completion["intel_tickets"] is int or completion["intel_tickets"] < 0:
		return "跨区情报券无效"
	if not completion["die_profiles"] is Array or completion["die_profiles"].size() != 6:
		return "跨区骰子配置必须包含六颗骰子"
	if completion.has("lucky_faces") and not completion["lucky_faces"].is_empty():
		var lucky_faces = completion["lucky_faces"]
		if not lucky_faces is Dictionary or lucky_faces.size() != 6:
			return "跨区幸运面必须包含六颗骰子"
		for die_index in range(1, 7):
			var die_id := StringName("d%d" % die_index)
			if (
				not lucky_faces.has(die_id)
				or not lucky_faces[die_id] is int
				or lucky_faces[die_id] < 1
				or lucky_faces[die_id] > 6
			):
				return "跨区幸运面包含非法点数"
	if (
		completion.has("area_modifier_id")
		and completion["area_modifier_id"] != &""
		and not ModifierCatalog.new().is_valid_for_area(
			completion["area_modifier_id"],
			expected_id
		)
	):
		return "区域完成记录包含错误的地区异变"
	return ""
