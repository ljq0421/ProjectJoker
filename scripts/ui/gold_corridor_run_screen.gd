class_name GoldCorridorRunScreen
extends AreaRunScreen

@export var guide_auto_start := true
@export var guide_config_path := "user://onboarding.cfg"

@onready var guide_overlay: IronAbacusGuideOverlay = %GoldCorridorGuideOverlay

var guide_store: GoldCorridorGuideProgressStore
var guide_flow := GoldCorridorGuideFlow.new()
var _guide_load_warning_pending := false

func _ready() -> void:
	_apply_launch_guide_path()
	guide_store = GoldCorridorGuideProgressStore.new(guide_config_path)
	_guide_load_warning_pending = guide_store.initial_load_error() != OK
	guide_overlay.acknowledged.connect(_on_guide_acknowledged)
	guide_overlay.dismiss_all_requested.connect(_on_guide_dismiss_all_requested)
	guide_overlay.visibility_changed.connect(_sync_guide_chrome_visibility)
	super._ready()
	_sync_guide_chrome_visibility()
	encounter_screen.view_refreshed.connect(guide_overlay.refresh_targets)

func _sync_guide_chrome_visibility() -> void:
	if is_instance_valid(navigation_bar):
		navigation_bar.visible = not guide_overlay.is_open()

func build_area_definition() -> AreaDefinition:
	return AreaCatalog.new().gold_corridor()

func _apply_launch_guide_path() -> void:
	var root_window := get_tree().root
	if not root_window.has_meta("gold_corridor_guide_config_path"):
		return
	guide_config_path = String(
		root_window.get_meta("gold_corridor_guide_config_path")
	)
	root_window.remove_meta("gold_corridor_guide_config_path")

func _request_context_hint(checkpoint_id: StringName) -> void:
	if _guide_load_warning_pending and checkpoint_id == &"route":
		route_panel.show_error("无法读取区域提示状态；本次仍可正常游玩。")
		_guide_load_warning_pending = false
	_request_guide(checkpoint_id)

func _close_context_hint() -> void:
	if is_instance_valid(guide_overlay):
		guide_overlay.close_card()

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
			return route_panel.get_node_or_null(
				"SafeArea/RouteLedger/LedgerColumn/RoutePages/LeftRoutePage"
			)
		&"route_right":
			return route_panel.get_node_or_null(
				"SafeArea/RouteLedger/LedgerColumn/RoutePages/RightRoutePage"
			)
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
		&"reward_modes":
			return reward_panel.get_node_or_null("%RewardModeRow")
	return null

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
	var message := "无法保存区域提示状态；下次启动可能再次显示。"
	if route_panel.visible:
		route_panel.show_error(message)
	elif shop_screen.visible:
		shop_screen.get_node("%ShopErrorLabel").text = message
		SfxAccess.play(self, &"error")
	elif reward_panel.visible:
		reward_panel.show_error(message)
	else:
		encounter_screen.show_transient_warning(message)
