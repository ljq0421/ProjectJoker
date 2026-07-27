class_name RouteChoicePanel
extends Control

signal route_selected(room_id: StringName)

func _ready() -> void:
	%LeftRouteButton.pressed.connect(_on_route_pressed.bind(%LeftRouteButton))
	%RightRouteButton.pressed.connect(_on_route_pressed.bind(%RightRouteButton))
	close()

func bind_routes(
	p_route_ids: Array[StringName],
	room_catalog,
	deck_ids: Array[StringName],
	card_catalog: CardCatalog
) -> bool:
	if room_catalog == null or card_catalog == null:
		return _fail_closed("路线资料目录不可用")
	if p_route_ids.size() != 2 or p_route_ids[0] == p_route_ids[1]:
		return _fail_closed("路线选择必须包含两个不同房间")
	for card_id in deck_ids:
		if card_catalog.find_card(card_id) == null:
			return _fail_closed("当前牌组包含未知手法牌：%s" % card_id)
	var left: RoomDefinition = room_catalog.find_room(p_route_ids[0])
	var right: RoomDefinition = room_catalog.find_room(p_route_ids[1])
	if left == null or right == null:
		return _fail_closed("路线选择包含未知房间")

	_bind_route("Left", left, deck_ids, card_catalog)
	_bind_route("Right", right, deck_ids, card_catalog)
	%LeftRouteButton.set_meta("room_id", left.id)
	%RightRouteButton.set_meta("room_id", right.id)
	%RouteErrorLabel.text = ""
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	return true

func show_error(message: String) -> void:
	%RouteErrorLabel.text = message
	SfxAccess.play(self, &"error")

func close() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _bind_route(
	prefix: String,
	room: RoomDefinition,
	deck_ids: Array[StringName],
	card_catalog: CardCatalog
) -> void:
	get_node("%sRouteName" % ["%" + prefix]).text = room.display_name
	get_node("%sRouteDescription" % ["%" + prefix]).text = room.description
	get_node("%sRouteGoal" % ["%" + prefix]).text = "三轮目标：%d" % room.target_total
	get_node("%sRouteReward" % ["%" + prefix]).text = (
		"成功奖励：%d 张情报券" % room.success_intel_reward
	)
	get_node("%sRouteTags" % ["%" + prefix]).text = (
		"房间特征｜%s" % " · ".join(room.tags)
	)
	var matching_names := _matching_card_names(room, deck_ids, card_catalog)
	get_node("%sRouteSynergy" % ["%" + prefix]).text = (
		"牌组呼应｜%s" % _format_matching_names(matching_names)
	)
	var lane_names := ["LaneOne", "LaneTwo", "LaneThree"]
	for index in range(3):
		var rule := room.encounter.rules[index]
		var condition_hint := ""
		if rule.condition_type == RuleDefinition.ConditionType.EXACT_SUM:
			condition_hint = " · 精确 %d" % rule.target_value
		get_node("%s%s" % ["%" + prefix, lane_names[index]]).text = (
			"%s\n%d 个骰位 · 系数 ×%d%s" % [
				rule.display_name,
				rule.slot_count,
				rule.coefficient,
				condition_hint,
			]
		)

func _matching_card_names(
	room: RoomDefinition,
	deck_ids: Array[StringName],
	card_catalog: CardCatalog
) -> Array[String]:
	var names: Array[String] = []
	for card_id in deck_ids:
		var card := card_catalog.find_card(card_id)
		if card == null:
			continue
		for tag in card.tags:
			if tag in room.synergy_tags:
				names.append(card.display_name)
				break
	names.sort()
	return names

func _format_matching_names(names: Array[String]) -> String:
	if names.is_empty():
		return "当前牌组无直接标签匹配"
	var visible_names := names.slice(0, 4)
	var text := "、".join(visible_names)
	if names.size() > 4:
		text += " 等 %d 张" % names.size()
	return text

func _on_route_pressed(button: Button) -> void:
	var room_id: StringName = button.get_meta("room_id", &"")
	if room_id == &"":
		show_error("这条路线尚未绑定房间")
		return
	route_selected.emit(room_id)

func _fail_closed(message: String) -> bool:
	%RouteErrorLabel.text = message
	close()
	return false
