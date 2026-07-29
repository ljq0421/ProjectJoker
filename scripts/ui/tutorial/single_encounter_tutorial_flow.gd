class_name SingleEncounterTutorialFlow
extends RefCounted

const LAST_STEP := 10

var step_index: int = 0
var blocked_feedback: String = ""

func start() -> void:
	step_index = 0
	blocked_feedback = ""

func allows(action: StringName, payload: Dictionary, session: SingleEncounterSession) -> bool:
	var allowed := false
	match step_index:
		1:
			allowed = (
				action == &"drag_assign"
				and payload.get("die_id") == &"d1"
				and payload.get("table_id") == &"left"
			)
		2:
			allowed = (
				action == &"select_die" and payload.get("die_id") == &"d6"
			) or (
				action == &"click_assign"
				and payload.get("die_id") == &"d6"
				and payload.get("table_id") == &"left"
			)
		3:
			allowed = _allows_middle_action(action, payload)
		4:
			allowed = _allows_calibration_action(action, payload, session)
		5, 8:
			allowed = (
				action == &"select_card" and payload.get("card_index") == 1
			) or (
				action == &"card_table"
				and payload.get("card_index") == 1
				and payload.get("table_id") == &"left"
			)
		7:
			allowed = action == &"undo"
		9:
			allowed = action == &"commit"
	blocked_feedback = "" if allowed else _blocked_instruction()
	return allowed

func record_accepted_action(
	action: StringName,
	_payload: Dictionary,
	session: SingleEncounterSession
) -> void:
	blocked_feedback = ""
	match step_index:
		1:
			if action == &"drag_assign" and _contains(&"left", &"d1", session):
				step_index = 2
		2:
			if action == &"click_assign" and _contains(&"left", &"d6", session):
				step_index = 3
		3:
			if _has_exact(&"middle", [&"d2", &"d3", &"d4"], session):
				step_index = 4
		4:
			var d5 := session.controller.state.find_die(&"d5")
			if d5 != null and d5.value == 4 and _contains(&"right", &"d5", session):
				step_index = 5
		5:
			if session.is_card_used(1) and session.preview().total == 51:
				step_index = 6
		7:
			if not session.is_card_used(1) and session.preview().total == 44:
				step_index = 8
		8:
			if session.is_card_used(1) and session.preview().total == 51:
				step_index = 9
		9:
			if session.controller.committed and session.commit().total == 51:
				step_index = 10

func continue_step(session: SingleEncounterSession) -> bool:
	if step_index == 0:
		step_index = 1
		blocked_feedback = ""
		return true
	if step_index == 6 and session.preview().total == 51:
		step_index = 7
		blocked_feedback = ""
		return true
	blocked_feedback = "请先完成当前步骤"
	return false

func can_finish(session: SingleEncounterSession) -> bool:
	return (
		step_index == LAST_STEP
		and session.controller.committed
		and session.commit().total == 51
	)

func instruction(session: SingleEncounterSession) -> String:
	if not blocked_feedback.is_empty():
		return blocked_feedback
	match step_index:
		0:
			return "三条规则轨会按顺序解析；右侧会实时展示每一步得分。"
		1:
			return "按住骰子 1，把它拖到左侧“精确为 7”规则轨。"
		2:
			return "先点击骰子 6，再点击左侧规则轨。"
		3:
			return "把骰子 2、3、4 放入中间规则轨，凑成连续三数。"
		4:
			var d5 := session.controller.state.find_die(&"d5")
			if d5 != null and d5.value == 5:
				return "选择骰子 5，点击“点数 -1”把它校准为 4。"
			return "把校准后的骰子 4 放入右侧“单枚偶数”规则轨。"
		5:
			return "选择“映射”手法牌，再点击左侧规则轨。"
		6:
			return "右侧预测已达到 51。每个增量和累计值都在确认前可见。"
		7:
			return "点击“撤销”，观察手法牌返回且预测回到 44。"
		8:
			return "再次把“映射”用于左侧规则轨，让预测回到 51。"
		9:
			return "点击“确认结算”。正式结果必须与预测完全一致。"
		10:
			return "你已完成三轨教学：分配、校准、用牌、预览和撤销都由你控制。"
	return ""

func target_specs(session: SingleEncounterSession) -> Array[Dictionary]:
	match step_index:
		0:
			return [
				{"kind": &"lane", "id": &"left"},
				{"kind": &"lane", "id": &"middle"},
				{"kind": &"lane", "id": &"right"},
				{"kind": &"control", "id": &"ResolutionPanel"},
			]
		1:
			return [_die(&"d1"), _lane(&"left")]
		2:
			return [_die(&"d6"), _lane(&"left")]
		3:
			var targets: Array[Dictionary] = [_lane(&"middle")]
			for die_id in [&"d2", &"d3", &"d4"]:
				if not _contains(&"middle", die_id, session):
					targets.append(_die(die_id))
			return targets
		4:
			return [_die(&"d5"), _control(&"MinusButton"), _lane(&"right")]
		5, 8:
			return [_card(1), _lane(&"left")]
		6:
			return [_control(&"ResolutionPanel")]
		7:
			return [_control(&"UndoButton")]
		9:
			return [_control(&"ConfirmButton")]
	return []

func _allows_middle_action(action: StringName, payload: Dictionary) -> bool:
	var die_id: StringName = payload.get("die_id", &"")
	return (
		die_id in [&"d2", &"d3", &"d4"]
		and (
			action == &"select_die"
			or (
				action in [&"click_assign", &"drag_assign"]
				and payload.get("table_id") == &"middle"
			)
		)
	)

func _allows_calibration_action(
	action: StringName,
	payload: Dictionary,
	session: SingleEncounterSession
) -> bool:
	if payload.get("die_id") != &"d5":
		return false
	if action == &"select_die":
		return true
	if action == &"calibrate":
		return payload.get("delta") == -1
	if action in [&"click_assign", &"drag_assign"]:
		var d5 := session.controller.state.find_die(&"d5")
		return d5 != null and d5.value == 4 and payload.get("table_id") == &"right"
	return false

func _blocked_instruction() -> String:
	match step_index:
		0:
			return "先阅读三轨与结算轨迹，再点击“继续”。"
		1:
			return "这一步请把骰子 1 拖到左侧规则轨。"
		2:
			return "这一步先选择骰子 6，再点击左侧规则轨。"
		3:
			return "这一步只操作骰子 2、3、4 和中间规则轨。"
		4:
			return "这一步只校准并放置骰子 5。"
		5, 8:
			return "这一步只把“映射”用于左侧规则轨。"
		6:
			return "先查看右侧预测，再点击“继续”。"
		7:
			return "这一步请点击“撤销”。"
		9:
			return "预测为 51 后再点击“确认结算”。"
		10:
			return "点击“完成”关闭引导。"
	return "请按高亮目标操作。"

func _contains(table_id: StringName, die_id: StringName, session: SingleEncounterSession) -> bool:
	return die_id in session.controller.state.assigned_die_ids(table_id)

func _has_exact(table_id: StringName, ids: Array, session: SingleEncounterSession) -> bool:
	var assigned: Array = session.controller.state.assigned_die_ids(table_id)
	return assigned.size() == ids.size() and ids.all(
		func(id: StringName) -> bool: return id in assigned
	)

func _die(id: StringName) -> Dictionary:
	return {"kind": &"die", "id": id}

func _card(index: int) -> Dictionary:
	return {"kind": &"card", "id": index}

func _lane(id: StringName) -> Dictionary:
	return {"kind": &"lane", "id": id}

func _control(id: StringName) -> Dictionary:
	return {"kind": &"control", "id": id}
