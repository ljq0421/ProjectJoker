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
	get_node("%sRouteDescription" % ["%" + prefix]).text = "%s\n%s" % [
		room.description,
		RouteBriefFormatter.activity_text(room, card_catalog),
	]
	get_node("%sRouteGoal" % ["%" + prefix]).text = RouteBriefFormatter.goal_text(room)
	get_node("%sRouteReward" % ["%" + prefix]).text = (
		"成功奖励：%d 张情报券" % room.success_intel_reward
	)
	get_node("%sRouteTags" % ["%" + prefix]).text = (
		"%s　房间特征｜%s" % [
			RouteBriefFormatter.identity_text(room, deck_ids, card_catalog),
			" · ".join(room.tags),
		]
	)
	var matching_names := RouteBriefFormatter.matching_card_names(
		room,
		deck_ids,
		card_catalog
	)
	get_node("%sRouteSynergy" % ["%" + prefix]).text = (
		"牌组呼应｜%s" % RouteBriefFormatter.synergy_text(matching_names)
	)
	var lane_names := ["LaneOne", "LaneTwo", "LaneThree"]
	for index in range(3):
		var rule := room.encounter.rules[index]
		get_node("%s%s" % ["%" + prefix, lane_names[index]]).text = (
			RouteBriefFormatter.rule_text(rule)
		)

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
