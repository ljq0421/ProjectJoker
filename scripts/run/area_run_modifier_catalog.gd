class_name AreaRunModifierCatalog
extends RefCounted

const GOLD_STRAIGHT_GIFT := &"gold_straight_gift"
const GOLD_SAME_RADIANCE := &"gold_same_radiance"
const GOLD_EXTREME_GIFT := &"gold_extreme_gift"
const MIRROR_TWIN_ECHO := &"mirror_twin_echo"
const MIRROR_REVERSED_FLOW := &"mirror_reversed_flow"
const MIRROR_OVERFLOW_TRANSFER := &"mirror_overflow_transfer"
const FACELESS_RULE_VEIL := &"faceless_rule_veil"
const FACELESS_OPEN_HAND := &"faceless_open_hand"

const DEFINITIONS := {
	GOLD_STRAIGHT_GIFT: {
		"area_id": &"gold_corridor",
		"display_name": "顺赐",
		"description": "已通过规则台中的骰子形成至少三连顺子时，本轮额外 +12 分。",
	},
	GOLD_SAME_RADIANCE: {
		"area_id": &"gold_corridor",
		"display_name": "同辉",
		"description": "已通过规则台中每组成一对同点骰，本轮额外 +4 分。",
	},
	GOLD_EXTREME_GIFT: {
		"area_id": &"gold_corridor",
		"display_name": "极值馈赠",
		"description": "已通过规则台中的最大点数骰额外结算两次。",
	},
	MIRROR_TWIN_ECHO: {
		"area_id": &"mirror_hall",
		"display_name": "双生回响",
		"description": "镜像副本使用原牌完整效果，不再采用弱化镜像效果。",
	},
	MIRROR_REVERSED_FLOW: {
		"area_id": &"mirror_hall",
		"display_name": "错位联动",
		"description": "每轮初始结算方向翻转；牌与规则台仍可继续改变方向。",
	},
	MIRROR_OVERFLOW_TRANSFER: {
		"area_id": &"mirror_hall",
		"display_name": "缝隙溢分",
		"description": "三张规则台全部通过时，最低的一台基础结算分再传递一次。",
	},
	FACELESS_RULE_VEIL: {
		"area_id": &"faceless_hub",
		"display_name": "规则虚化",
		"description": "“三台均有骰”限制放宽为至少两台有骰。",
	},
	FACELESS_OPEN_HAND: {
		"area_id": &"faceless_hub",
		"display_name": "无名通融",
		"description": "每轮真实手法牌数量上限 +1。",
	},
}

func ids_for_area(area_id: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	for modifier_id in DEFINITIONS:
		if DEFINITIONS[modifier_id]["area_id"] == area_id:
			result.append(modifier_id)
	return result

func find(modifier_id: StringName) -> Dictionary:
	return DEFINITIONS.get(modifier_id, {}).duplicate(true)

func is_valid_for_area(modifier_id: StringName, area_id: StringName) -> bool:
	var definition := find(modifier_id)
	return not definition.is_empty() and definition["area_id"] == area_id

func choose_for_area(area_id: StringName, rng: RunRng) -> StringName:
	if rng == null:
		return &""
	var ids := ids_for_area(area_id)
	if ids.is_empty():
		return &""
	return rng.shuffle(ids)[0]
