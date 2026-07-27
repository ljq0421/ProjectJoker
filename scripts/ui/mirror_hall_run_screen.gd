class_name MirrorHallRunScreen
extends AreaRunScreen

const MIRROR_SEED := 20260727

@export var guide_auto_start := true
@export var guide_config_path := "user://onboarding.cfg"

@onready var guide_overlay: IronAbacusGuideOverlay = %MirrorHallGuideOverlay

var guide_store: MirrorHallGuideProgressStore
var guide_flow := MirrorHallGuideFlow.new()
var _guide_load_warning_pending := false
var _selected_card_target: Control

func _ready() -> void:
	_apply_launch_guide_path()
	guide_store = MirrorHallGuideProgressStore.new(guide_config_path)
	_guide_load_warning_pending = guide_store.initial_load_error() != OK
	guide_overlay.acknowledged.connect(_on_guide_acknowledged)
	guide_overlay.dismiss_all_requested.connect(_on_guide_dismiss_all_requested)
	super._ready()
	encounter_screen.view_refreshed.connect(guide_overlay.refresh_targets)

func build_area_definition() -> AreaDefinition:
	return AreaCatalog.new().mirror_hall()

func build_seed() -> int:
	return MIRROR_SEED

func _apply_launch_guide_path() -> void:
	var root_window := get_tree().root
	if not root_window.has_meta("mirror_hall_guide_config_path"):
		return
	guide_config_path = String(
		root_window.get_meta("mirror_hall_guide_config_path")
	)
	root_window.remove_meta("mirror_hall_guide_config_path")

func _after_encounter_bound() -> void:
	if (
		area_session.phase == AreaRunSession.Phase.NORMAL_ROOM
		and area_session.room_index == 0
	):
		call_deferred("_request_guide", &"direction")

func _after_card_selected(
	_card_index: int,
	card: CardDefinition,
	token: Control
) -> void:
	var profile := area_session.encounter_session.setup.encounter.rule_profile
	if (
		card.target_type != CardDefinition.TargetType.GAP
		or card.mirror_effects.is_empty()
		or not profile.mirror_first_table_card
	):
		return
	_selected_card_target = token
	_request_guide(&"mirror")

func _after_dealer_bound() -> void:
	call_deferred("_request_guide", &"dealer")

func _request_context_hint(checkpoint_id: StringName) -> void:
	if checkpoint_id == &"dealer":
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
	if _guide_load_warning_pending:
		encounter_screen.show_transient_warning(
			"无法读取反照提示状态；本次仍可正常游玩。"
		)
		_guide_load_warning_pending = false
		return
	var card_spec := guide_flow.card_spec(checkpoint_id)
	var targets: Array[Control] = []
	for target_id in card_spec.get("target_ids", []):
		var target := _resolve_guide_target(target_id)
		if target == null:
			push_error(
				"Mirror Hall guide target missing: checkpoint=%s target=%s"
				% [checkpoint_id, target_id]
			)
			return
		targets.append(target)
	if not guide_overlay.open_card(card_spec, targets):
		push_error(
			"Mirror Hall guide overlay failed to open: checkpoint=%s"
			% checkpoint_id
		)
		return
	guide_flow.mark_requested(checkpoint_id)

func _resolve_guide_target(target_id: StringName) -> Control:
	match target_id:
		&"encounter_goal":
			return encounter_screen.get_node_or_null("%GoalLabel")
		&"direction_badge":
			return encounter_screen.get_node_or_null("%DirectionBadge")
		&"resolution_panel":
			return encounter_screen.get_node_or_null("%ResolutionPanel")
		&"selected_card":
			return _selected_card_target
		&"left_gap":
			return encounter_screen.get_node_or_null("%LeftGap")
		&"right_gap":
			return encounter_screen.get_node_or_null("%RightGap")
		&"dealer_panel":
			return encounter_screen.get_node_or_null("%DealerPanel")
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
	encounter_screen.show_transient_warning(
		"无法保存反照提示状态；下次启动可能再次显示。"
	)
