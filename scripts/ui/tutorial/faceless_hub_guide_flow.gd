class_name FacelessHubGuideFlow
extends RefCounted

const CHECKPOINT_ORDER: Array[StringName] = [
	&"composite",
	&"schedule",
	&"restriction",
]

const CARD_SPECS := {
	&"composite": {
		"id": &"composite",
		"progress_label": "无面提示",
		"progress_index": 1,
		"progress_total": 3,
		"title": "复合规则要逐台拆解",
		"instruction": "无面中枢会把精确值、奇偶与连续条件同时摆在三张规则台上。先查看每台需要的骰位和条件，再决定骰子去向；手法牌负责修正方案，不是碰运气翻结果。",
		"target_ids": [&"left_lane", &"middle_lane", &"right_lane"],
	},
	&"schedule": {
		"id": &"schedule",
		"progress_label": "无面提示",
		"progress_index": 2,
		"progress_total": 3,
		"title": "三轮议程从开场就公开",
		"instruction": "无面主人依次展示正面、反面与无面：结算方向和镜像状态都会变化。第三轮的限制尚未选定，但两种候选都已公开，可以提前保留适合的牌与骰子安排。",
		"target_ids": [&"round_schedule"],
	},
	&"restriction": {
		"id": &"restriction",
		"progress_label": "无面提示",
		"progress_index": 3,
		"progress_total": 3,
		"title": "选择解题约束，不是押注",
		"instruction": "独手裁决限制真实手法牌数量；三席到场要求三台都有骰子。两项只影响第三轮。关闭提示后仍停留在选择面板，不会替你做决定。",
		"target_ids": [&"operation_restriction", &"distribution_restriction"],
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
