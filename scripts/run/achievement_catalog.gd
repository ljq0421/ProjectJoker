class_name AchievementCatalog
extends RefCounted

const FIRST_CLEAR := &"first_clear"
const ZERO_CALIBRATION := &"zero_calibration"
const FULL_ALLOCATION_EVERY_ROUND := &"full_allocation_every_round"
const CLEAR_DICE_CONTROL := &"clear_dice_control"
const CLEAR_TABLE_CHAIN := &"clear_table_chain"
const CLEAR_INTEL_ECONOMY := &"clear_intel_economy"
const DOUBLE_CHALLENGE := &"double_challenge"
const ZERO_EMERGENCY := &"zero_emergency"
const THREE_STORMS := &"three_storms"
const FIFTEEN_CARD_CLEAR := &"fifteen_card_clear"
const ENGRAVING_SET_CLEAR := &"engraving_set_clear"
const FIRST_DAILY_CLEAR := &"first_daily_clear"

const DEFINITIONS := [
	{"id": FIRST_CLEAR, "title": "公开契据", "description": "首次完成标准三区远征。"},
	{"id": ZERO_CALIBRATION, "title": "原点证明", "description": "不使用校准完成标准远征。"},
	{"id": FULL_ALLOCATION_EVERY_ROUND, "title": "六席齐备", "description": "标准远征每轮分配全部六骰。"},
	{"id": CLEAR_DICE_CONTROL, "title": "骰值校准师", "description": "以骰值控制牌组完成标准远征。"},
	{"id": CLEAR_TABLE_CHAIN, "title": "链式公证人", "description": "以规则台连锁牌组完成标准远征。"},
	{"id": CLEAR_INTEL_ECONOMY, "title": "情报庄家", "description": "以情报经济牌组完成标准远征。"},
	{"id": DOUBLE_CHALLENGE, "title": "双重条款", "description": "启用两项挑战完成标准远征。"},
	{"id": ZERO_EMERGENCY, "title": "无应急记录", "description": "不消费应急情报完成标准远征。"},
	{"id": THREE_STORMS, "title": "风暴签署人", "description": "单局触发至少三次风暴并通关。"},
	{"id": FIFTEEN_CARD_CLEAR, "title": "满编牌页", "description": "以十五张牌组完成标准远征。"},
	{"id": ENGRAVING_SET_CLEAR, "title": "成套刻印", "description": "激活刻印套装并完成标准远征。"},
	{"id": FIRST_DAILY_CLEAR, "title": "今日见证", "description": "首次完成本地每日挑战。"},
]

func all() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for definition in DEFINITIONS:
		result.append(definition.duplicate(true))
	return result

func ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for definition in DEFINITIONS:
		result.append(definition["id"])
	return result

func find(achievement_id: StringName) -> Dictionary:
	for definition in DEFINITIONS:
		if definition["id"] == achievement_id:
			return definition.duplicate(true)
	return {}
