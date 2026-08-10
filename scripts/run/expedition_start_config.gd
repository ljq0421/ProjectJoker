class_name ExpeditionStartConfig
extends RefCounted

const ExpeditionConfigs = preload("res://scripts/run/expedition_config_catalog.gd")
const ModifierCatalog = preload("res://scripts/run/area_run_modifier_catalog.gd")

const STANDARD := &"standard"
const DAILY := &"daily"
const CUSTOM := &"custom"
const STANDARD_AREAS: Array[StringName] = [
	&"gold_corridor", &"mirror_hall", &"faceless_hub",
]
const TARGET_MULTIPLIERS: Array[float] = [0.75, 1.0, 1.25]

var mode: StringName = STANDARD
var seed_value := 1
var starting_deck_id: StringName = ExpeditionConfigs.DICE_CONTROL
var challenge_ids: Array[StringName] = []
var area_sequence: Array[StringName] = STANDARD_AREAS.duplicate()
var area_modifier_ids: Dictionary = {}
var target_multiplier := 1.0
var daily_date_key := ""
var decoration_id: StringName = &""

func to_snapshot() -> Dictionary:
	return {
		"mode": mode,
		"seed_value": seed_value,
		"starting_deck_id": starting_deck_id,
		"challenge_ids": challenge_ids.duplicate(),
		"area_sequence": area_sequence.duplicate(),
		"area_modifier_ids": area_modifier_ids.duplicate(true),
		"target_multiplier": target_multiplier,
		"daily_date_key": daily_date_key,
		"decoration_id": decoration_id,
	}

func restore_snapshot(snapshot: Dictionary) -> OperationResult:
	var error := validation_error(snapshot)
	if not error.is_empty():
		return OperationResult.new(false, error)
	mode = snapshot["mode"]
	seed_value = snapshot["seed_value"]
	starting_deck_id = snapshot["starting_deck_id"]
	challenge_ids.assign(snapshot["challenge_ids"])
	area_sequence.assign(snapshot["area_sequence"])
	area_modifier_ids = snapshot["area_modifier_ids"].duplicate(true)
	target_multiplier = float(snapshot["target_multiplier"])
	daily_date_key = snapshot["daily_date_key"]
	decoration_id = snapshot.get("decoration_id", &"")
	return OperationResult.new(true)

func configure_standard(
	seed: int,
	deck_id: StringName,
	challenges: Array
) -> OperationResult:
	return restore_snapshot({
		"mode": STANDARD,
		"seed_value": seed,
		"starting_deck_id": deck_id,
		"challenge_ids": challenges.duplicate(),
		"area_sequence": STANDARD_AREAS.duplicate(),
		"area_modifier_ids": {},
		"target_multiplier": 1.0,
		"daily_date_key": "",
	})

func validation_error(snapshot: Dictionary = to_snapshot()) -> String:
	for key in [
		"mode", "seed_value", "starting_deck_id", "challenge_ids",
		"area_sequence", "area_modifier_ids", "target_multiplier", "daily_date_key",
	]:
		if not snapshot.has(key):
			return "远征启动配置缺少字段：%s" % key
	var next_mode: StringName = snapshot["mode"]
	if next_mode not in [STANDARD, DAILY, CUSTOM]:
		return "远征模式无效"
	if not snapshot["seed_value"] is int or snapshot["seed_value"] <= 0:
		return "远征种子必须为正整数"
	if not snapshot["challenge_ids"] is Array:
		return "挑战列表格式无效"
	var max_challenges := 6 if next_mode == CUSTOM else 2
	var config_error := ExpeditionConfigs.new().selection_error(
		snapshot["starting_deck_id"], snapshot["challenge_ids"], true, max_challenges
	)
	if not config_error.is_empty():
		return config_error
	if not snapshot["area_sequence"] is Array:
		return "区域序列格式无效"
	var areas: Array = snapshot["area_sequence"]
	if areas.size() < 1 or areas.size() > 3:
		return "远征必须连续进行一至三个区域"
	for index in areas.size():
		if areas[index] != STANDARD_AREAS[index]:
			return "区域必须按金线、反照、无面的固定顺序连续选择"
	if next_mode != CUSTOM and areas != STANDARD_AREAS:
		return "标准与每日远征必须包含完整三区"
	if not snapshot["area_modifier_ids"] is Dictionary:
		return "区域异变配置格式无效"
	var modifiers: Dictionary = snapshot["area_modifier_ids"]
	for area_id in modifiers:
		if area_id not in areas or not modifiers[area_id] is Array:
			return "区域异变引用了未选择的区域"
		var ids: Array = modifiers[area_id]
		if ids.size() > 2:
			return "每区最多选择两项区域异变"
		var seen: Dictionary = {}
		for modifier_id in ids:
			if seen.has(modifier_id):
				return "同一区域的异变不能重复"
			if not ModifierCatalog.new().is_valid_for_area(modifier_id, area_id):
				return "区域异变与地区不匹配：%s" % modifier_id
			seen[modifier_id] = true
	if next_mode != CUSTOM and not modifiers.is_empty():
		return "标准与每日远征使用种子生成的单项区域异变"
	if not snapshot["target_multiplier"] is float and not snapshot["target_multiplier"] is int:
		return "目标倍率格式无效"
	var multiplier := float(snapshot["target_multiplier"])
	if not TARGET_MULTIPLIERS.any(func(value: float) -> bool: return is_equal_approx(value, multiplier)):
		return "目标倍率只能为 75%、100% 或 125%"
	if next_mode != CUSTOM and not is_equal_approx(multiplier, 1.0):
		return "标准与每日远征的目标倍率固定为 100%"
	if not snapshot["daily_date_key"] is String:
		return "每日日期键格式无效"
	if next_mode == DAILY and not _valid_date_key(snapshot["daily_date_key"]):
		return "每日挑战日期键无效"
	if next_mode != DAILY and not snapshot["daily_date_key"].is_empty():
		return "非每日模式不能携带每日日期键"
	if snapshot.has("decoration_id") and (
		not snapshot["decoration_id"] is String
		and not snapshot["decoration_id"] is StringName
	):
		return "自定义装饰标识格式无效"
	return ""

func modifiers_for(area_id: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	result.assign(area_modifier_ids.get(area_id, []))
	return result

func _valid_date_key(value: String) -> bool:
	var parts := value.split("-")
	if parts.size() != 3:
		return false
	return parts[0].length() == 4 and parts[1].length() == 2 and parts[2].length() == 2
