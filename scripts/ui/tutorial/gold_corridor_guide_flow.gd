class_name GoldCorridorGuideFlow
extends RefCounted

const CHECKPOINT_ORDER: Array[StringName] = [
	&"route",
	&"shop",
	&"dealer",
	&"engraving",
]

const CARD_SPECS := {
	&"route": {
		"id": &"route",
		"progress_label": "区域提示",
		"progress_index": 1,
		"progress_total": 4,
		"title": "先比较，再选择",
		"instruction": (
			"每个房间用三轮共同完成累计目标。目标、情报券奖励、"
			+ "三条规则与当前牌组呼应均已公开；选择更适合当前构筑的路线。"
		),
		"target_ids": [&"route_left", &"route_right"],
	},
	&"shop": {
		"id": &"shop",
		"progress_label": "区域提示",
		"progress_index": 2,
		"progress_total": 4,
		"title": "替换会影响后续整个区域",
		"instruction": (
			"每次花费 1 张情报券，用一张候选牌替换一张旧牌；"
			+ "牌组始终保持十二张。离店后的牌组与余额会带入第二个房间"
			+ "和铁算盘，也可以不购买直接离开。"
		),
		"target_ids": [&"shop_tickets", &"shop_deck", &"shop_offers"],
	},
	&"dealer": {
		"id": &"dealer",
		"progress_label": "区域提示",
		"progress_index": 3,
		"progress_total": 4,
		"title": "完整分配会保住固定奖励",
		"instruction": (
			"铁算盘的三轮累计目标为 150。每轮固定奖励从 12 开始，"
			+ "每颗未分配骰子使奖励减少 2，最低为 0；"
			+ "当前结果会在结算轨迹中实时显示。"
		),
		"target_ids": [&"dealer_panel", &"resolution_panel"],
	},
	&"engraving": {
		"id": &"engraving",
		"progress_label": "区域提示",
		"progress_index": 4,
		"progress_total": 4,
		"title": "这次安装将封存区域",
		"instruction": (
			"依次选择一种刻印、一颗骰子和它的 1–6 面；"
			+ "安装前可以自由修改三项选择。正式区域安装后直接进入"
			+ "完成账目，不再进入刻印验证局。"
		),
		"target_ids": [&"reward_offers", &"reward_dice", &"reward_faces"],
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
