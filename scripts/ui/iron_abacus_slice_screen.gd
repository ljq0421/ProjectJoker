class_name IronAbacusSliceScreen
extends Control

@export var run_seed: int = 20260726
@export var normal_target: int = 100
@export var dealer_target: int = 150
@export var guide_auto_start: bool = true
@export var guide_config_path: String = "user://onboarding.cfg"

@onready var encounter_screen: SingleEncounterScreen = %EncounterScreen
@onready var shop_screen: ShopScreen = %ShopScreen
@onready var summary_panel: RoundSummaryPanel = %RoundSummaryPanel
@onready var reward_panel: EngravingRewardPanel = %EngravingRewardPanel
@onready var guide_overlay: IronAbacusGuideOverlay = %IronAbacusGuideOverlay

var slice_session: IronAbacusSliceSession
var guide_store: IronAbacusGuideProgressStore
var guide_flow := IronAbacusGuideFlow.new()

func _ready() -> void:
	_apply_launch_guide_path()
	guide_store = IronAbacusGuideProgressStore.new(guide_config_path)
	encounter_screen.round_committed.connect(_on_round_committed)
	encounter_screen.view_refreshed.connect(guide_overlay.refresh_targets)
	summary_panel.next_round_requested.connect(_on_next_round_requested)
	summary_panel.shop_requested.connect(_on_shop_requested)
	summary_panel.retry_requested.connect(_on_restart_requested)
	summary_panel.return_requested.connect(_on_return_requested)
	summary_panel.dealer_requested.connect(_on_dealer_requested)
	summary_panel.dealer_retry_requested.connect(_on_dealer_retry_requested)
	summary_panel.verification_retry_requested.connect(_on_verification_retry_requested)
	shop_screen.leave_requested.connect(_on_shop_leave_requested)
	reward_panel.engraving_selected.connect(_on_engraving_selected)
	reward_panel.install_requested.connect(_on_install_requested)
	guide_overlay.acknowledged.connect(_on_guide_acknowledged)
	guide_overlay.dismiss_all_requested.connect(_on_guide_dismiss_all_requested)
	start_slice()

func start_slice() -> void:
	slice_session = IronAbacusSliceSession.new(run_seed, normal_target, dealer_target)
	var result := slice_session.start()
	if not result.accepted:
		encounter_screen.show_external_error(result.reason)
		return
	bind_current_encounter()

func bind_current_encounter() -> void:
	_close_guide()
	var session: SingleEncounterSession
	var area_copy: String
	var goal_copy: String
	var checkpoint_id: StringName
	match slice_session.phase:
		IronAbacusSliceSession.Phase.NORMAL_ROOM:
			session = slice_session.encounter_session.current_session
			area_copy = "金线回廊 · 普通试局"
			goal_copy = _encounter_goal_copy()
			encounter_screen.bind_dealer(null)
			checkpoint_id = &"normal"
		IronAbacusSliceSession.Phase.DEALER:
			session = slice_session.encounter_session.current_session
			area_copy = "金线回廊 · 铁算盘"
			goal_copy = _encounter_goal_copy()
			encounter_screen.bind_dealer(slice_session.dealer_catalog.iron_abacus())
			checkpoint_id = &"dealer"
		IronAbacusSliceSession.Phase.VERIFICATION:
			session = slice_session.verification_session
			area_copy = "刻印验证 · 强制显示刻印面"
			var engraving := slice_session.engraving_catalog.find_engraving(
				slice_session.selected_engraving_id
			)
			goal_copy = "%s · %s 的 %d 面 · 触发一次即可完成" % [
				engraving.display_name,
				String(slice_session.installed_die_id).to_upper(),
				slice_session.installed_face,
			]
			encounter_screen.bind_verification(engraving)
			checkpoint_id = &"verification"
		_:
			encounter_screen.show_external_error("当前阶段没有可绑定的遭遇")
			return
	encounter_screen.visible = true
	shop_screen.visible = false
	reward_panel.close()
	summary_panel.close()
	encounter_screen.bind_external_session(session, area_copy, goal_copy)
	call_deferred("_request_guide", checkpoint_id)

func _encounter_goal_copy() -> String:
	var displayed_tickets := slice_session.intel_tickets
	if slice_session.phase == IronAbacusSliceSession.Phase.NORMAL_ROOM:
		displayed_tickets = slice_session.encounter_session.intel_tickets
	return "累计：%d / %d　轮次 %d / 3　情报券：%d" % [
		slice_session.encounter_session.cumulative_total,
		slice_session.encounter_session.target_total,
		slice_session.encounter_session.current_round,
		displayed_tickets,
	]

func _on_round_committed(report: ResolutionReport) -> void:
	_close_guide()
	if slice_session.phase == IronAbacusSliceSession.Phase.VERIFICATION:
		var verification_result := slice_session.accept_verification_report(report)
		if not verification_result.accepted:
			encounter_screen.show_external_error(verification_result.reason)
			return
		if slice_session.phase == IronAbacusSliceSession.Phase.COMPLETE:
			var engraving := slice_session.engraving_catalog.find_engraving(
				slice_session.selected_engraving_id
			)
			summary_panel.show_verification_result(
				true,
				"%s 已在 %s 的 %d 面触发。\n最终牌组：%d 张；剩余情报券：%d。" % [
					engraving.display_name,
					String(slice_session.installed_die_id).to_upper(),
					slice_session.installed_face,
					slice_session.deck_ids.size(),
					slice_session.intel_tickets,
				]
			)
		else:
			summary_panel.show_verification_result(false, slice_session.last_error)
		return

	var result := slice_session.accept_encounter_report(report)
	if not result.accepted:
		encounter_screen.show_external_error(result.reason)
		return
	if slice_session.phase == IronAbacusSliceSession.Phase.FAILED:
		if slice_session.failure_origin == IronAbacusSliceSession.Phase.DEALER:
			summary_panel.show_dealer_failure(slice_session.encounter_session)
		else:
			summary_panel.show_run_state(slice_session.encounter_session)
		return
	if slice_session.phase == IronAbacusSliceSession.Phase.ENGRAVING_REWARD:
		summary_panel.close()
		reward_panel.bind_reward(
			slice_session.engraving_offer_ids,
			slice_session.die_profiles,
			slice_session.engraving_catalog
		)
		call_deferred("_request_guide", &"reward")
		return
	encounter_screen.set_run_status(
		"金线回廊 · 普通试局"
		if slice_session.phase == IronAbacusSliceSession.Phase.NORMAL_ROOM
		else "金线回廊 · 铁算盘",
		_encounter_goal_copy()
	)
	summary_panel.show_run_state(slice_session.encounter_session)

func _on_next_round_requested() -> void:
	_close_guide()
	var result := slice_session.advance_encounter_round()
	if not result.accepted:
		encounter_screen.show_external_error(result.reason)
		return
	bind_current_encounter()

func _on_shop_requested() -> void:
	_close_guide()
	var result := slice_session.open_shop()
	if not result.accepted:
		encounter_screen.show_external_error(result.reason)
		return
	summary_panel.close()
	encounter_screen.visible = false
	shop_screen.bind_session(slice_session.shop_session, slice_session.card_catalog)
	call_deferred("_request_guide", &"shop")

func _on_shop_leave_requested() -> void:
	_close_guide()
	var result := slice_session.leave_shop()
	if not result.accepted:
		shop_screen.get_node("%ShopErrorLabel").text = result.reason
		return
	shop_screen.visible = false
	summary_panel.show_dealer_ready(slice_session.deck_ids, slice_session.intel_tickets)

func _on_dealer_requested() -> void:
	_close_guide()
	var result := slice_session.start_dealer()
	if not result.accepted:
		encounter_screen.show_external_error(result.reason)
		return
	bind_current_encounter()

func _on_dealer_retry_requested() -> void:
	_close_guide()
	var result := slice_session.retry_dealer()
	if not result.accepted:
		summary_panel.get_node("%SummaryDetail").text = result.reason
		return
	bind_current_encounter()

func _on_verification_retry_requested() -> void:
	_close_guide()
	var result := slice_session.retry_verification()
	if not result.accepted:
		summary_panel.get_node("%SummaryDetail").text = result.reason
		return
	bind_current_encounter()

func _on_restart_requested() -> void:
	_close_guide()
	var result := slice_session.restart_slice()
	if not result.accepted:
		summary_panel.get_node("%SummaryDetail").text = result.reason
		return
	bind_current_encounter()

func _on_return_requested() -> void:
	_close_guide()
	get_tree().change_scene_to_file("res://scenes/run/single_encounter_screen.tscn")

func _on_engraving_selected(engraving_id: StringName) -> void:
	var result := slice_session.select_engraving(engraving_id)
	if not result.accepted:
		reward_panel.show_error(result.reason)

func _on_install_requested(
	engraving_id: StringName,
	die_id: StringName,
	face: int
) -> void:
	_close_guide()
	if engraving_id != slice_session.selected_engraving_id:
		reward_panel.show_error("界面选择与待安装刻印不一致，请重新选择")
		return
	var result := slice_session.install_selected_engraving(die_id, face)
	if not result.accepted:
		reward_panel.show_error(result.reason)
		return
	reward_panel.close()
	bind_current_encounter()

func _apply_launch_guide_path() -> void:
	var root_window := get_tree().root
	if not root_window.has_meta("iron_abacus_guide_config_path"):
		return
	guide_config_path = String(root_window.get_meta("iron_abacus_guide_config_path"))
	root_window.remove_meta("iron_abacus_guide_config_path")

func _request_guide(checkpoint_id: StringName) -> void:
	if (
		not guide_auto_start
		or guide_store == null
		or not guide_flow.should_present(checkpoint_id, guide_store.snapshot())
	):
		return
	for _layout_frame in range(2):
		await get_tree().process_frame
	if (
		not guide_auto_start
		or guide_store == null
		or not guide_flow.should_present(checkpoint_id, guide_store.snapshot())
	):
		return
	guide_flow.mark_requested(checkpoint_id)
	var card_spec := guide_flow.card_spec(checkpoint_id)
	var targets := _resolve_guide_targets(card_spec.get("target_ids", []))
	if targets.is_empty():
		push_error("Advanced guide targets missing for checkpoint: %s" % checkpoint_id)
		return
	if not guide_overlay.open_card(card_spec, targets):
		push_error("Advanced guide failed to open checkpoint: %s" % checkpoint_id)

func _resolve_guide_targets(target_ids: Array) -> Array[Control]:
	var result: Array[Control] = []
	for target_id in target_ids:
		var target := _resolve_guide_target(target_id)
		if target == null:
			return []
		result.append(target)
	return result

func _resolve_guide_target(target_id: StringName) -> Control:
	match target_id:
		&"encounter_goal":
			return encounter_screen.get_node_or_null("%GoalLabel")
		&"dealer_panel":
			return encounter_screen.get_node_or_null("%DealerPanel")
		&"resolution_panel":
			return encounter_screen.get_node_or_null("%ResolutionPanel")
		&"shop_tickets":
			return shop_screen.get_node_or_null("%TicketLabel")
		&"shop_deck":
			return shop_screen.get_node_or_null("%DeckGrid")
		&"shop_offers":
			return shop_screen.get_node_or_null("%OfferColumn")
		&"reward_offers":
			return reward_panel.get_node_or_null("%OfferRow")
		&"reward_dice":
			return reward_panel.get_node_or_null("%DieRow")
		&"reward_faces":
			return reward_panel.get_node_or_null("%FaceGrid")
		&"installed_die":
			return encounter_screen.find_tutorial_target({
				"kind": &"die",
				"id": slice_session.installed_die_id,
			})
	return null

func _on_guide_acknowledged(checkpoint_id: StringName) -> void:
	var save_result := guide_store.mark_seen(checkpoint_id)
	guide_overlay.close_card()
	if save_result != OK:
		_show_guide_persistence_warning()

func _on_guide_dismiss_all_requested(_checkpoint_id: StringName) -> void:
	var save_result := guide_store.dismiss_all()
	guide_overlay.close_card()
	if save_result != OK:
		_show_guide_persistence_warning()

func _show_guide_persistence_warning() -> void:
	var message := "无法保存进阶引导状态；下次启动可能再次显示。"
	if shop_screen.visible:
		shop_screen.get_node("%ShopErrorLabel").text = message
	elif reward_panel.visible:
		reward_panel.show_error(message)
	else:
		encounter_screen.show_external_error(message)

func _close_guide() -> void:
	if is_instance_valid(guide_overlay):
		guide_overlay.close_card()
