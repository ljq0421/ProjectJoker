class_name FacelessHubRunScreen
extends AreaRunScreen

const FACELESS_SEED := 20260727

@export var guide_auto_start := true
@export var guide_config_path := "user://onboarding.cfg"

@onready var round_schedule_strip: RoundScheduleStrip = %RoundScheduleStrip
@onready var final_restriction_panel: FinalRestrictionPanel = %FinalRestrictionPanel
@onready var guide_overlay: IronAbacusGuideOverlay = %FacelessHubGuideOverlay

var guide_store: FacelessHubGuideProgressStore
var guide_flow := FacelessHubGuideFlow.new()
var _guide_load_warning_pending := false

func _ready() -> void:
	_apply_launch_guide_path()
	guide_store = FacelessHubGuideProgressStore.new(guide_config_path)
	_guide_load_warning_pending = guide_store.initial_load_error() != OK
	final_restriction_panel.restriction_confirmed.connect(
		_on_restriction_confirmed
	)
	guide_overlay.acknowledged.connect(_on_guide_acknowledged)
	guide_overlay.dismiss_all_requested.connect(
		_on_guide_dismiss_all_requested
	)
	super._ready()
	var host: CenterContainer = encounter_screen.get_node("%RunStatusSlot")
	round_schedule_strip.reparent(host)
	round_schedule_strip.visible = false
	host.visible = false
	encounter_screen.view_refreshed.connect(guide_overlay.refresh_targets)

func build_area_definition() -> AreaDefinition:
	return AreaCatalog.new().faceless_hub()

func build_seed() -> int:
	return FACELESS_SEED

func _apply_launch_guide_path() -> void:
	var root_window := get_tree().root
	if not root_window.has_meta("faceless_hub_guide_config_path"):
		return
	guide_config_path = String(
		root_window.get_meta("faceless_hub_guide_config_path")
	)
	root_window.remove_meta("faceless_hub_guide_config_path")

func _show_route_choice() -> void:
	_hide_schedule()
	final_restriction_panel.close()
	super._show_route_choice()

func _after_encounter_bound() -> void:
	if area_session.phase != AreaRunSession.Phase.DEALER:
		_hide_schedule()
		if (
			area_session.phase == AreaRunSession.Phase.NORMAL_ROOM
			and area_session.room_index == 0
		):
			call_deferred("_request_guide_after_layout", &"composite")
		return
	_bind_schedule()

func _after_dealer_bound() -> void:
	_bind_schedule()

func _request_context_hint(checkpoint_id: StringName) -> void:
	if checkpoint_id == &"dealer":
		call_deferred("_request_guide_after_layout", &"schedule")

func _after_round_report_accepted() -> void:
	if area_session.phase == AreaRunSession.Phase.DEALER:
		_bind_schedule()

func _show_restriction_choice_if_needed() -> bool:
	if (
		area_session.phase != AreaRunSession.Phase.DEALER
		or area_session.encounter_session.status
		!= ThreeRoundEncounterSession.Status.AWAITING_RESTRICTION
	):
		return false
	summary_panel.close()
	var opened := final_restriction_panel.open_options(
		area_session.encounter_session.public_restriction_options()
	)
	if not opened:
		encounter_screen.show_external_error("最终限制候选无法显示")
	else:
		call_deferred("_request_guide_after_layout", &"restriction")
	return opened

func _after_restriction_confirmed() -> void:
	final_restriction_panel.close()
	_bind_schedule()

func _on_restriction_confirmed(restriction_id: StringName) -> void:
	if not confirm_dealer_restriction(restriction_id):
		final_restriction_panel.show_error(area_session.last_error)

func _request_guide_after_layout(checkpoint_id: StringName) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_request_guide(checkpoint_id)

func _request_guide(checkpoint_id: StringName) -> void:
	if (
		not guide_auto_start
		or guide_store == null
		or not guide_flow.should_present(checkpoint_id, guide_store.snapshot())
	):
		return
	if _guide_load_warning_pending:
		encounter_screen.show_transient_warning(
			"无法读取无面提示状态；本次仍可正常游玩。"
		)
		_guide_load_warning_pending = false
		return
	var card_spec := guide_flow.card_spec(checkpoint_id)
	var targets: Array[Control] = []
	for target_id in card_spec.get("target_ids", []):
		var target := _resolve_guide_target(target_id)
		if target == null:
			push_error(
				"Faceless guide target missing: checkpoint=%s target=%s"
				% [checkpoint_id, target_id]
			)
			return
		targets.append(target)
	if not guide_overlay.open_card(card_spec, targets):
		push_error(
			"Faceless guide overlay failed to open: checkpoint=%s"
			% checkpoint_id
		)
		return
	guide_flow.mark_requested(checkpoint_id)

func _resolve_guide_target(target_id: StringName) -> Control:
	match target_id:
		&"left_lane":
			return encounter_screen.get_node_or_null("%LeftLane")
		&"middle_lane":
			return encounter_screen.get_node_or_null("%MiddleLane")
		&"right_lane":
			return encounter_screen.get_node_or_null("%RightLane")
		&"round_schedule":
			return round_schedule_strip
		&"operation_restriction":
			return final_restriction_panel.get_node_or_null(
				"%OperationRestrictionButton"
			)
		&"distribution_restriction":
			return final_restriction_panel.get_node_or_null(
				"%DistributionRestrictionButton"
			)
	return null

func _close_context_hint() -> void:
	if is_instance_valid(guide_overlay):
		guide_overlay.close_card()

func _on_guide_acknowledged(checkpoint_id: StringName) -> void:
	var result := guide_store.mark_seen(checkpoint_id)
	guide_overlay.close_card()
	if result != OK:
		_show_guide_persistence_warning()
	else:
		SfxAccess.play(self, &"ui_confirm")

func _on_guide_dismiss_all_requested(_checkpoint_id: StringName) -> void:
	var result := guide_store.dismiss_all()
	guide_overlay.close_card()
	if result != OK:
		_show_guide_persistence_warning()
	else:
		SfxAccess.play(self, &"ui_back")

func _show_guide_persistence_warning() -> void:
	encounter_screen.show_transient_warning(
		"无法保存无面提示状态；下次启动可能再次显示。"
	)

func _bind_schedule() -> void:
	if (
		area_session == null
		or area_session.encounter_session == null
		or area_session.area_definition.dealer_round_schedule == null
	):
		_hide_schedule()
		return
	var host: Control = encounter_screen.get_node("%RunStatusSlot")
	host.visible = round_schedule_strip.bind_schedule(
		area_session.area_definition.dealer_round_schedule,
		area_session.encounter_session
	)

func _hide_schedule() -> void:
	if is_instance_valid(round_schedule_strip):
		round_schedule_strip.visible = false
	if is_instance_valid(encounter_screen):
		var host := encounter_screen.get_node_or_null("%RunStatusSlot")
		if host != null:
			host.visible = false
