class_name GoldCorridorRunScreen
extends Control

@export var run_seed: int = AreaRunSession.DEFAULT_SEED
@export var guide_auto_start := true
@export var guide_config_path := "user://onboarding.cfg"

@onready var encounter_screen: SingleEncounterScreen = %EncounterScreen
@onready var shop_screen: ShopScreen = %ShopScreen
@onready var summary_panel: RoundSummaryPanel = %RoundSummaryPanel
@onready var route_panel: RouteChoicePanel = %RouteChoicePanel
@onready var reward_panel: EngravingRewardPanel = %EngravingRewardPanel
@onready var complete_panel: AreaCompletePanel = %AreaCompletePanel
@onready var guide_overlay: IronAbacusGuideOverlay = %GoldCorridorGuideOverlay

var area_session: AreaRunSession
var guide_store: GoldCorridorGuideProgressStore
var guide_flow := GoldCorridorGuideFlow.new()
var _guide_load_warning_pending := false

func _ready() -> void:
	_apply_launch_guide_path()
	guide_store = GoldCorridorGuideProgressStore.new(guide_config_path)
	_guide_load_warning_pending = guide_store.initial_load_error() != OK
	encounter_screen.round_committed.connect(_on_round_committed)
	encounter_screen.view_refreshed.connect(guide_overlay.refresh_targets)
	summary_panel.next_round_requested.connect(_on_next_round_requested)
	summary_panel.shop_requested.connect(_on_shop_requested)
	summary_panel.retry_requested.connect(_on_restart_requested)
	summary_panel.return_requested.connect(_on_return_requested)
	shop_screen.leave_requested.connect(_on_shop_leave_requested)
	route_panel.route_selected.connect(_on_route_selected)
	reward_panel.engraving_selected.connect(_on_engraving_selected)
	reward_panel.install_requested.connect(_on_install_requested)
	complete_panel.restart_requested.connect(_on_restart_requested)
	complete_panel.return_requested.connect(_on_return_requested)
	guide_overlay.acknowledged.connect(_on_guide_acknowledged)
	guide_overlay.dismiss_all_requested.connect(_on_guide_dismiss_all_requested)
	summary_panel.get_node("%ReturnTeachingButton").text = "返回入口"
	reward_panel.get_node("%InstallEngravingButton").text = "安装刻印并封存区域"
	start_run()

func _apply_launch_guide_path() -> void:
	var root_window := get_tree().root
	if not root_window.has_meta("gold_corridor_guide_config_path"):
		return
	guide_config_path = String(
		root_window.get_meta("gold_corridor_guide_config_path")
	)
	root_window.remove_meta("gold_corridor_guide_config_path")

func start_run() -> void:
	area_session = AreaRunSession.new(run_seed)
	var result := area_session.start()
	if not result.accepted:
		_show_start_error(result.reason)
		return
	_show_route_choice()

func _show_route_choice() -> void:
	shop_screen.visible = false
	reward_panel.close()
	complete_panel.close()
	summary_panel.close()
	var bound := route_panel.bind_routes(
		area_session.current_route_ids(),
		area_session.room_catalog,
		area_session.deck_ids,
		area_session.card_catalog
	)
	if not bound:
		encounter_screen.visible = true
		encounter_screen.show_external_error("路线资料无法显示")
		return
	if _guide_load_warning_pending:
		route_panel.show_error("无法读取区域提示状态；本次仍可正常游玩。")
		_guide_load_warning_pending = false
	call_deferred("_request_guide", &"route")

func _on_route_selected(room_id: StringName) -> void:
	_close_guide()
	var result := area_session.select_route(room_id)
	if not result.accepted:
		route_panel.show_error(result.reason)
		return
	route_panel.close()
	bind_current_encounter()

func bind_current_encounter() -> void:
	if (
		area_session.encounter_session == null
		or (
			area_session.phase != AreaRunSession.Phase.NORMAL_ROOM
			and area_session.phase != AreaRunSession.Phase.DEALER
		)
	):
		encounter_screen.show_external_error("当前阶段没有可绑定的遭遇")
		return
	route_panel.close()
	shop_screen.visible = false
	reward_panel.close()
	complete_panel.close()
	summary_panel.close()
	encounter_screen.visible = true
	if area_session.phase == AreaRunSession.Phase.DEALER:
		encounter_screen.bind_dealer(area_session.dealer_catalog.iron_abacus())
	else:
		encounter_screen.bind_dealer(null)
	encounter_screen.bind_external_session(
		area_session.encounter_session.current_session,
		_area_copy(),
		_encounter_goal_copy()
	)
	if area_session.phase == AreaRunSession.Phase.DEALER:
		call_deferred("_request_guide", &"dealer")

func _area_copy() -> String:
	if area_session.phase == AreaRunSession.Phase.DEALER:
		return "金线回廊 · 铁算盘"
	var room := area_session.room_catalog.find_room(area_session.selected_room_ids[-1])
	return "金线回廊 · %s" % room.display_name

func _encounter_goal_copy() -> String:
	return "累计：%d / %d　轮次 %d / 3　情报券：%d" % [
		area_session.encounter_session.cumulative_total,
		area_session.encounter_session.target_total,
		area_session.encounter_session.current_round,
		area_session.intel_tickets,
	]

func _on_round_committed(report: ResolutionReport) -> void:
	_close_guide()
	var result := area_session.accept_encounter_report(report)
	if not result.accepted:
		encounter_screen.show_external_error(result.reason)
		return
	if area_session.phase == AreaRunSession.Phase.FAILED:
		summary_panel.show_area_failure(
			area_session.encounter_session,
			area_session.failure_origin == AreaRunSession.Phase.DEALER
		)
		return
	if area_session.phase == AreaRunSession.Phase.ENGRAVING_REWARD:
		summary_panel.close()
		reward_panel.bind_reward(
			area_session.engraving_offer_ids,
			area_session.die_profiles,
			area_session.engraving_catalog
		)
		call_deferred("_request_guide", &"engraving")
		return
	encounter_screen.set_run_status(_area_copy(), _encounter_goal_copy())
	summary_panel.show_run_state(area_session.encounter_session)

func _on_next_round_requested() -> void:
	_close_guide()
	var result := area_session.advance_encounter_round()
	if not result.accepted:
		encounter_screen.show_external_error(result.reason)
		return
	bind_current_encounter()

func _on_shop_requested() -> void:
	_close_guide()
	var result := area_session.open_shop()
	if not result.accepted:
		encounter_screen.show_external_error(result.reason)
		return
	summary_panel.close()
	encounter_screen.visible = false
	shop_screen.bind_session(area_session.shop_session, area_session.card_catalog)
	call_deferred("_request_guide", &"shop")

func _on_shop_leave_requested() -> void:
	_close_guide()
	var result := area_session.leave_shop()
	if not result.accepted:
		shop_screen.get_node("%ShopErrorLabel").text = result.reason
		return
	shop_screen.visible = false
	if area_session.phase == AreaRunSession.Phase.ROUTE_CHOICE:
		_show_route_choice()
	elif area_session.phase == AreaRunSession.Phase.DEALER:
		bind_current_encounter()
	else:
		encounter_screen.show_external_error("商店结算后的区域阶段无效")

func _on_engraving_selected(engraving_id: StringName) -> void:
	var result := area_session.select_engraving(engraving_id)
	if not result.accepted:
		reward_panel.show_error(result.reason)

func _on_install_requested(
	engraving_id: StringName,
	die_id: StringName,
	face: int
) -> void:
	_close_guide()
	if engraving_id != area_session.selected_engraving_id:
		reward_panel.show_error("界面选择与待安装刻印不一致，请重新选择")
		return
	var result := area_session.install_selected_engraving(die_id, face)
	if not result.accepted:
		reward_panel.show_error(result.reason)
		return
	reward_panel.close()
	var bound := complete_panel.bind_summary(
		area_session.completion_snapshot(),
		area_session.room_catalog,
		area_session.card_catalog,
		area_session.engraving_catalog
	)
	if not bound:
		encounter_screen.show_external_error("区域完成摘要无法显示")

func _on_restart_requested() -> void:
	_close_guide()
	var result := area_session.restart()
	if not result.accepted:
		summary_panel.get_node("%SummaryDetail").text = result.reason
		return
	_show_route_choice()

func _on_return_requested() -> void:
	_close_guide()
	get_tree().change_scene_to_file("res://scenes/run/single_encounter_screen.tscn")

func _show_start_error(message: String) -> void:
	_close_guide()
	route_panel.close()
	shop_screen.visible = false
	reward_panel.close()
	complete_panel.close()
	summary_panel.close()
	encounter_screen.visible = true
	encounter_screen.show_external_error(message)

func _request_guide(checkpoint_id: StringName) -> void:
	if (
		not guide_auto_start
		or guide_store == null
		or not guide_flow.should_present(checkpoint_id, guide_store.snapshot())
	):
		return
	guide_flow.mark_requested(checkpoint_id)
	var card_spec := guide_flow.card_spec(checkpoint_id)
	var targets: Array[Control] = []
	for target_id in card_spec.get("target_ids", []):
		var target := _resolve_guide_target(target_id)
		if target == null:
			push_error(
				"Gold Corridor guide target missing: checkpoint=%s target=%s"
				% [checkpoint_id, target_id]
			)
			return
		targets.append(target)
	if not guide_overlay.open_card(card_spec, targets):
		push_error(
			"Gold Corridor guide overlay failed to open: checkpoint=%s"
			% checkpoint_id
		)

func _resolve_guide_target(target_id: StringName) -> Control:
	match target_id:
		&"route_left":
			return route_panel.get_node_or_null("%LeftRouteButton")
		&"route_right":
			return route_panel.get_node_or_null("%RightRouteButton")
		&"shop_tickets":
			return shop_screen.get_node_or_null("%TicketLabel")
		&"shop_deck":
			return shop_screen.get_node_or_null("%DeckGrid")
		&"shop_offers":
			return shop_screen.get_node_or_null("%OfferColumn")
		&"dealer_panel":
			return encounter_screen.get_node_or_null("%DealerPanel")
		&"resolution_panel":
			return encounter_screen.get_node_or_null("%ResolutionPanel")
		&"reward_offers":
			return reward_panel.get_node_or_null("%OfferRow")
		&"reward_dice":
			return reward_panel.get_node_or_null("%DieRow")
		&"reward_faces":
			return reward_panel.get_node_or_null("%FaceGrid")
	return null

func _on_guide_acknowledged(checkpoint_id: StringName) -> void:
	var result := guide_store.mark_seen(checkpoint_id)
	guide_overlay.close_card()
	if result != OK:
		_show_guide_persistence_warning()

func _on_guide_dismiss_all_requested(_checkpoint_id: StringName) -> void:
	var result := guide_store.dismiss_all()
	guide_overlay.close_card()
	if result != OK:
		_show_guide_persistence_warning()

func _show_guide_persistence_warning() -> void:
	var message := "无法保存区域提示状态；下次启动可能再次显示。"
	if route_panel.visible:
		route_panel.show_error(message)
	elif shop_screen.visible:
		shop_screen.get_node("%ShopErrorLabel").text = message
	elif reward_panel.visible:
		reward_panel.show_error(message)
	else:
		encounter_screen.show_external_error(message)

func _close_guide() -> void:
	if is_instance_valid(guide_overlay):
		guide_overlay.close_card()
