class_name RouteChoicePanel
extends Control

signal route_selected(room_id: StringName)

const AreaPresentation = preload(
	"res://scripts/ui/area_presentation_catalog.gd"
)

var _open_tween: Tween

func _ready() -> void:
	%LeftRouteButton.pressed.connect(_on_route_pressed.bind(%LeftRouteButton))
	%RightRouteButton.pressed.connect(_on_route_pressed.bind(%RightRouteButton))
	close()

func bind_routes(
	p_route_ids: Array[StringName],
	room_catalog,
	deck_ids: Array[StringName],
	card_catalog: CardCatalog,
	challenge_ids: Array[StringName] = [],
	route_index: int = 0
) -> bool:
	if room_catalog == null or card_catalog == null:
		return _fail_closed("路线资料目录不可用")
	if p_route_ids.size() != 2 or p_route_ids[0] == p_route_ids[1]:
		return _fail_closed("路线选择必须包含两个不同房间")
	if route_index not in [0, 1]:
		return _fail_closed("选路段次必须为第一组或第二组")
	for card_id in deck_ids:
		if card_catalog.find_card(card_id) == null:
			return _fail_closed("当前牌组包含未知手法牌：%s" % card_id)
	var left: RoomDefinition = room_catalog.find_room(p_route_ids[0])
	var right: RoomDefinition = room_catalog.find_room(p_route_ids[1])
	if left == null or right == null:
		return _fail_closed("路线选择包含未知房间")

	%RouteTitle.text = "%s · 路线账簿" % room_catalog.display_name
	var presentation := AreaPresentation.new().find(room_catalog.id)
	%LedgerMark.text = "%s / 选路 %d/2" % [
		presentation.get("route_code", "未知区域"),
		route_index + 1,
	]
	%RouteInstruction.text = "%s\n左右仅为本次随机摆位，请比较房间规则、目标、奖励与牌组呼应。" % (
		presentation["route_instruction"]
	)
	_bind_route("Left", left, deck_ids, card_catalog, challenge_ids)
	_bind_route("Right", right, deck_ids, card_catalog, challenge_ids)
	%LeftRouteButton.set_meta("room_id", left.id)
	%RightRouteButton.set_meta("room_id", right.id)
	%RouteErrorLabel.text = ""
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	call_deferred("_play_open_motion")
	return true

func _play_open_motion() -> void:
	var ledger := %RouteLedger as Control
	if not is_instance_valid(ledger):
		return
	if _open_tween != null and _open_tween.is_valid():
		_open_tween.kill()
	ledger.pivot_offset = ledger.size * 0.5
	if not _motion_allowed():
		ledger.modulate = Color.WHITE
		ledger.scale = Vector2.ONE
		return
	ledger.modulate = Color(1.0, 1.0, 1.0, 0.0)
	ledger.scale = Vector2(0.985, 0.985)
	_open_tween = create_tween().set_parallel(true)
	_open_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_open_tween.tween_property(ledger, "modulate", Color.WHITE, 0.2)
	_open_tween.tween_property(ledger, "scale", Vector2.ONE, 0.24)

func _motion_allowed() -> bool:
	var settings := get_tree().root.get_node_or_null("SettingsService")
	if settings == null or not settings.has_method("accessibility_value"):
		return true
	return not bool(settings.call("accessibility_value", &"reduce_flashes"))

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
	card_catalog: CardCatalog,
	challenge_ids: Array[StringName]
) -> void:
	get_node("%sRouteName" % ["%" + prefix]).text = room.display_name
	get_node("%sRouteDescription" % ["%" + prefix]).text = "%s\n%s" % [
		room.description,
		RouteBriefFormatter.activity_text(room, card_catalog),
	]
	var challenge_rules = preload(
		"res://scripts/run/expedition_challenge_rules.gd"
	).new(challenge_ids)
	get_node("%sRouteGoal" % ["%" + prefix]).text = "累计目标：%d（%d 回合）" % [
		challenge_rules.target_total(room.target_total),
		room.round_count,
	]
	get_node("%sRouteReward" % ["%" + prefix]).text = (
		"成功奖励：%d 张情报券" % challenge_rules.intel_reward(
			room.success_intel_reward
		)
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
