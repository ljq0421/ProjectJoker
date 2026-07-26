class_name IronAbacusGuideFlow
extends RefCounted

const CHECKPOINT_ORDER: Array[StringName] = [
	&"normal",
	&"shop",
	&"dealer",
	&"reward",
	&"verification",
]

const CARD_SPECS := {
	&"normal": {
		"id": &"normal",
		"progress_index": 1,
		"progress_total": 5,
		"title": "三轮共同追逐累计目标",
		"instruction": (
			"三轮共同追逐累计 100 分，本轮正式结算会进入下一轮。"
			+ "成功后获得 2 张情报券。"
		),
		"target_ids": [&"encounter_goal"],
	},
	&"shop": {
		"id": &"shop",
		"progress_index": 2,
		"progress_total": 5,
		"title": "替换会被后续挑战继承",
		"instruction": (
			"每张情报券可替换一张牌，牌组始终保持 12 张。"
			+ "离店后的牌组和剩余情报券会带入铁算盘。"
		),
		"target_ids": [&"shop_tickets", &"shop_deck", &"shop_offers"],
	},
	&"dealer": {
		"id": &"dealer",
		"progress_index": 3,
		"progress_total": 5,
		"title": "分配完整度影响固定奖励",
		"instruction": (
			"铁算盘的三轮累计目标为 150。固定奖励从 12 开始，"
			+ "每颗未分配骰子使奖励减少 2，最低为 0；当前收益会实时显示。"
		),
		"target_ids": [&"dealer_panel", &"resolution_panel"],
	},
	&"reward": {
		"id": &"reward",
		"progress_index": 4,
		"progress_total": 5,
		"title": "用三段选择确定一个刻印",
		"instruction": (
			"先从三个候选中选择刻印，再选择一颗实际骰子和它的 1–6 面。"
			+ "安装前可以自由更改三项选择。"
		),
		"target_ids": [&"reward_offers", &"reward_dice", &"reward_faces"],
	},
	&"verification": {
		"id": &"verification",
		"progress_index": 5,
		"progress_total": 5,
		"title": "亲眼确认刻印触发",
		"instruction": (
			"所选骰子会强制显示刻印面，其余五颗骰子继续正常取值。"
			+ "刻印实际触发一次即可完成；受限操作会显示明确原因。"
		),
		"target_ids": [&"installed_die", &"encounter_goal", &"resolution_panel"],
	},
}

var _requested: Dictionary = {}

func checkpoint_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	result.assign(CHECKPOINT_ORDER)
	return result

func card_spec(checkpoint_id: StringName) -> Dictionary:
	if not CARD_SPECS.has(checkpoint_id):
		return {}
	var spec: Dictionary = CARD_SPECS[checkpoint_id]
	return spec.duplicate(true)

func should_present(checkpoint_id: StringName, progress_snapshot: Dictionary) -> bool:
	if not CARD_SPECS.has(checkpoint_id):
		return false
	if bool(progress_snapshot.get("dismissed", false)):
		return false
	var seen_key := "seen_%s" % String(checkpoint_id)
	if bool(progress_snapshot.get(seen_key, false)):
		return false
	return not _requested.has(checkpoint_id)

func mark_requested(checkpoint_id: StringName) -> bool:
	if not CARD_SPECS.has(checkpoint_id):
		return false
	_requested[checkpoint_id] = true
	return true

func reset_run_requests() -> void:
	_requested.clear()
