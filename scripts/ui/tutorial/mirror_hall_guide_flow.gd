class_name MirrorHallGuideFlow
extends RefCounted

const CHECKPOINT_ORDER: Array[StringName] = [
	&"direction",
	&"mirror",
	&"dealer",
]

const CARD_SPECS := {
	&"direction": {
		"id": &"direction",
		"progress_label": "反照提示",
		"progress_index": 1,
		"progress_total": 3,
		"title": "先看方向，再看路线",
		"instruction": "反照牌厅的每场遭遇都会公开标记结算方向。路线卡会说明从左向右或从右向左；右侧结算轨迹按真实顺序预演，不要仅按桌面位置判断先后。",
		"target_ids": [&"encounter_goal", &"direction_badge", &"resolution_panel"],
	},
	&"mirror": {
		"id": &"mirror",
		"progress_label": "反照提示",
		"progress_index": 2,
		"progress_total": 3,
		"title": "原牌与镜像一起预演",
		"instruction": "本场启用镜像规则。每轮第一张桌间槽手法牌会在另一侧生成弱化副本；副本不占出牌次数，也不会继续复制。放入槽位后，结算轨迹会同时显示原牌与镜像结果。",
		"target_ids": [&"selected_card", &"left_gap", &"right_gap", &"resolution_panel"],
	},
	&"dealer": {
		"id": &"dealer",
		"progress_label": "反照提示",
		"progress_index": 3,
		"progress_total": 3,
		"title": "镜面夫人",
		"instruction": "本场固定从右向左结算。每轮第一张桌间槽牌都会生成资源中声明的弱化镜像版本；撤销原牌会同时撤销副本，确认前仍可调整完整方案。",
		"target_ids": [&"dealer_panel", &"direction_badge", &"left_gap", &"right_gap", &"resolution_panel"],
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
	return CARD_SPECS[checkpoint_id].duplicate(true)

func should_present(
	checkpoint_id: StringName,
	progress_snapshot: Dictionary
) -> bool:
	if not CARD_SPECS.has(checkpoint_id):
		return false
	if bool(progress_snapshot.get("dismissed", false)):
		return false
	if bool(progress_snapshot.get("seen_%s" % checkpoint_id, false)):
		return false
	return not _requested.has(checkpoint_id)

func mark_requested(checkpoint_id: StringName) -> bool:
	if not CARD_SPECS.has(checkpoint_id):
		return false
	_requested[checkpoint_id] = true
	return true
