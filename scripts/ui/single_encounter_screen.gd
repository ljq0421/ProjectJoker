class_name SingleEncounterScreen
extends Control

signal view_refreshed
signal ui_action_accepted(action: StringName, payload: Dictionary)
signal round_committed(report: ResolutionReport)
signal card_selected(card_index: int, card: CardDefinition, token: Control)

const DIE_SCENE = preload("res://scenes/components/die_token.tscn")
const CARD_SCENE = preload("res://scenes/components/card_token.tscn")
const CardFormatter = preload("res://scripts/ui/card_display_formatter.gd")
const TARGET_TINT := Color(0.68, 1.0, 0.96, 1.0)
const TUTORIAL_CONFIG_META := "tutorial_config_path"
const TUTORIAL_NEXT_SCENE_META := "tutorial_next_scene"
const AreaPresentation = preload(
	"res://scripts/ui/area_presentation_catalog.gd"
)

@export var tutorial_auto_start: bool = true
@export var tutorial_config_path: String = "user://onboarding.cfg"
@export var content_top_inset := 0.0

@onready var lanes: Array[RuleLane] = [%LeftLane, %MiddleLane, %RightLane]
@onready var dice_tray: DiceTray = %DiceTray
@onready var dice_tray_empty_label: Label = %DiceTrayEmptyLabel
@onready var hand_container: HBoxContainer = %Hand
@onready var card_detail_panel: PanelContainer = %CardDetailPanel
@onready var card_detail_icon: TextureRect = %CardDetailIcon
@onready var card_detail_text: Label = %CardDetailText
@onready var resolution_panel: ResolutionPanel = %ResolutionPanel
@onready var error_label: Label = %ErrorLabel
@onready var calibration_label: Label = %CalibrationLabel
@onready var confirm_button: Button = %ConfirmButton
@onready var selection_hint_label: Label = %SelectionHintLabel
@onready var active_restriction_badge: Label = %ActiveRestrictionBadge
@onready var tutorial: SingleEncounterTutorial = %SingleEncounterTutorial
@onready var area_label: Label = %AreaLabel
@onready var goal_label: Label = %GoalLabel
@onready var replay_tutorial_button: Button = %ReplayTutorialButton
@onready var replay_advanced_guide_button: Button = %ReplayAdvancedGuideButton
@onready var replay_gold_corridor_guide_button: Button = %ReplayGoldCorridorGuideButton
@onready var run_trial_button: Button = %RunTrialButton
@onready var mirror_hall_run_button: Button = %MirrorHallRunButton
@onready var replay_mirror_hall_guide_button: Button = %ReplayMirrorHallGuideButton
@onready var faceless_hub_run_button: Button = %FacelessHubRunButton
@onready var replay_faceless_hub_guide_button: Button = %ReplayFacelessHubGuideButton
@onready var entry_groups: VBoxContainer = %EntryGroups
@onready var safe_area: MarginContainer = $SafeArea
@onready var background: ColorRect = $Background
@onready var area_atmosphere: Control = %AreaAtmosphere
@onready var area_identity_bar: ColorRect = %AreaIdentityBar
@onready var dealer_sigil: Control = %DealerSigil
@onready var interaction_motion_layer = %InteractionMotionLayer

var session: SingleEncounterSession
var dealer_definition: DealerDefinition
var owns_session := true
var _area_id: StringName = &""
var _directive_tween: Tween

func _ready() -> void:
	_apply_tutorial_launch_path()
	safe_area.offset_top += content_top_inset
	session = SingleEncounterSession.new(
		SingleEncounterFixture.make_state(),
		SingleEncounterFixture.make_encounter(),
		SingleEncounterFixture.make_hand()
	)
	for lane in lanes:
		lane.lane_activated.connect(_on_lane_activated)
		lane.slot_activated.connect(_on_slot_activated)
		lane.die_activated.connect(_on_die_activated)
		lane.die_return_requested.connect(_on_die_return_requested)
		lane.die_drop_requested.connect(_on_die_drop_requested)
		lane.die_drop_to_slot_requested.connect(
			_on_die_drop_to_slot_requested
		)
	dice_tray.die_return_requested.connect(_on_die_drop_return_requested)
	%LeftGap.pressed.connect(func() -> void: _on_gap_activated(&"left", &"middle"))
	%RightGap.pressed.connect(func() -> void: _on_gap_activated(&"middle", &"right"))
	%MinusButton.pressed.connect(func() -> void: _on_calibrate_pressed(-1))
	%PlusButton.pressed.connect(func() -> void: _on_calibrate_pressed(1))
	%UndoButton.pressed.connect(_on_undo_pressed)
	confirm_button.pressed.connect(_on_confirm_pressed)
	resolution_panel.playback_finished.connect(
		_on_resolution_playback_finished
	)
	resolution_panel.source_focus_requested.connect(
		_on_resolution_source_focus_requested
	)
	refresh_from_session()
	tutorial.configure(self, TutorialProgressStore.new(tutorial_config_path))
	tutorial.persistence_warning.connect(_on_tutorial_persistence_warning)
	tutorial.closed.connect(_on_tutorial_closed)
	replay_tutorial_button.pressed.connect(start_tutorial_replay)
	replay_advanced_guide_button.pressed.connect(_on_replay_advanced_guide_pressed)
	replay_gold_corridor_guide_button.pressed.connect(_on_replay_gold_corridor_guide_pressed)
	run_trial_button.pressed.connect(_on_run_trial_pressed)
	mirror_hall_run_button.pressed.connect(_on_mirror_hall_run_pressed)
	replay_mirror_hall_guide_button.pressed.connect(
		_on_replay_mirror_hall_guide_pressed
	)
	faceless_hub_run_button.pressed.connect(_on_faceless_hub_run_pressed)
	replay_faceless_hub_guide_button.pressed.connect(
		_on_replay_faceless_hub_guide_pressed
	)
	if tutorial_auto_start:
		tutorial.call_deferred("maybe_start")

func _apply_tutorial_launch_path() -> void:
	var root_window := get_tree().root
	if root_window.has_meta(TUTORIAL_CONFIG_META):
		tutorial_config_path = String(root_window.get_meta(TUTORIAL_CONFIG_META))

func _on_tutorial_closed() -> void:
	var root_window := get_tree().root
	if not root_window.has_meta(TUTORIAL_NEXT_SCENE_META):
		return
	var next_scene := String(root_window.get_meta(TUTORIAL_NEXT_SCENE_META))
	root_window.remove_meta(TUTORIAL_NEXT_SCENE_META)
	call_deferred("_continue_after_tutorial", next_scene)

func _continue_after_tutorial(next_scene: String) -> void:
	SfxAccess.play(self, &"page_transition")
	get_tree().change_scene_to_file(next_scene)

func bind_external_session(
	p_session: SingleEncounterSession,
	area_copy: String,
	goal_copy: String
) -> void:
	if p_session == null:
		return
	tutorial.active = false
	tutorial.visible = false
	entry_groups.visible = false
	session = p_session
	owns_session = false
	set_run_status(area_copy, goal_copy)
	refresh_from_session()

func set_run_status(area_copy: String, goal_copy: String) -> void:
	area_label.text = area_copy
	goal_label.text = goal_copy

func rule_reference_rules() -> Array[RuleDefinition]:
	var rules: Array[RuleDefinition] = []
	if session == null or session.controller == null or session.controller.encounter == null:
		return rules
	rules.assign(session.controller.encounter.rules)
	return rules

func apply_area_presentation(area_id: StringName) -> void:
	var presentation: Dictionary = AreaPresentation.new().find(area_id)
	if presentation.is_empty():
		return
	_area_id = area_id
	background.color = presentation["background"]
	area_identity_bar.color = presentation["primary"]
	area_label.add_theme_color_override("font_color", presentation["secondary"])
	%DealerEyebrow.add_theme_color_override(
		"font_color",
		presentation["primary"]
	)
	area_atmosphere.configure(area_id)
	dealer_sigil.configure(area_id)
	%AreaDirectivePanel.visible = true
	%AreaDirectiveTitle.text = presentation["directive_title"]

func bind_dealer(dealer: DealerDefinition) -> void:
	dealer_definition = dealer
	if dealer == null:
		%DealerEyebrow.text = "普通遭遇 / OPEN RULES"
		%DealerName.text = "规则监理"
		%DealerRule.text = "本场规则\n先读取公开条件和结算方向，再安排骰子与手法牌。"
		%DealerHint.text = "把骰子拖入规则轨，或先选骰子再选规则轨。"
		return
	%DealerEyebrow.text = "庄家挑战 / %s" % String(dealer.id).to_upper()
	%DealerName.text = dealer.display_name
	%DealerRule.text = dealer.rule_text

func bind_area_brief(area_id: StringName) -> void:
	dealer_definition = null
	var presentation: Dictionary = AreaPresentation.new().find(area_id)
	if presentation.is_empty():
		bind_dealer(null)
		return
	%DealerEyebrow.text = presentation["ordinary_eyebrow"]
	%DealerName.text = presentation["ordinary_title"]
	%DealerRule.text = presentation["ordinary_rule"]
	%DealerHint.text = "把骰子拖入规则轨，或先选骰子再选规则轨。"

func bind_verification(engraving: EngravingDefinition) -> void:
	dealer_definition = null
	%DealerEyebrow.text = "刻印校验 / GUARANTEED FACE"
	%DealerName.text = "刻印验证"
	%DealerRule.text = engraving.rule_text
	%DealerHint.text = "所选骰子的刻印面已公开强制朝上；把它分配到有效规则台。"

func bind_archive(definition: RuleArchiveDefinition) -> void:
	dealer_definition = null
	%DealerEyebrow.text = "规则演练 / RULE PRACTICE"
	%DealerName.text = definition.display_name
	%DealerRule.text = definition.explanation
	%DealerHint.text = definition.summary

func show_external_error(message: String) -> void:
	session.last_error = message
	error_label.text = message
	SfxAccess.play(self, &"error")

func show_transient_warning(message: String) -> void:
	error_label.text = message
	SfxAccess.play(self, &"error")

func refresh_from_session() -> void:
	var state := session.controller.state
	var preview := session.preview()
	var selected_target_type := _selected_card_target_type()
	var engraving_catalog := session.controller.resolution_context.engraving_catalog
	var accessibility := _accessibility_settings()
	var motion_reduced := bool(accessibility.get("disable_distortion", false))
	interaction_motion_layer.configure(accessibility)
	for lane_index in range(lanes.size()):
		var rule := session.controller.encounter.rules[lane_index]
		var assigned: Array = []
		var effective_slots := session.controller.effective_slot_count(rule.id)
		for die_id in state.slot_values(rule.id, effective_slots):
			assigned.append(
				null
				if die_id == RoundState.EMPTY_SLOT
				else state.find_die(die_id)
			)
		lanes[lane_index].bind_lane(
			rule,
			assigned,
			DIE_SCENE,
			session.selection.die_id,
			engraving_catalog,
			effective_slots,
			session.controller.condition_summary(rule.id),
			preview.effective_die_values,
			int(preview.effective_table_coefficients.get(
				rule.id,
				rule.coefficient
			)),
			int(preview.table_resolution_counts.get(rule.id, 1))
		)
		var table_target_active := (
			selected_target_type == CardDefinition.TargetType.TABLE
		)
		lanes[lane_index].set_target_state(
			table_target_active,
			session.is_legal_table_card_target(rule.id)
		)
		var die_card_target_active := selected_target_type in [
			CardDefinition.TargetType.DIE,
			CardDefinition.TargetType.DICE_PAIR,
		]
		lanes[lane_index].set_die_card_target_state(
			die_card_target_active,
			session.is_legal_die_card_target
		)

	var tray_tokens: Dictionary = {}
	for child in dice_tray.get_children():
		if child is DieToken and not child.is_queued_for_deletion():
			tray_tokens[child.die_id] = child
	var unassigned_dice_count := 0
	var retained_tray_ids: Dictionary = {}
	for die in state.dice:
		if not _is_assigned(die.id):
			unassigned_dice_count += 1
			retained_tray_ids[die.id] = true
			var token: DieToken = tray_tokens.get(die.id) as DieToken
			if token == null:
				token = DIE_SCENE.instantiate()
				dice_tray.add_child(token)
				token.die_activated.connect(_on_die_activated)
			token.bind_die_with_engravings(
				die,
				session.selection.die_id == die.id,
				engraving_catalog,
				false,
				int(preview.effective_die_values.get(die.id, die.value))
			)
			var die_target_active := selected_target_type in [
				CardDefinition.TargetType.DIE,
				CardDefinition.TargetType.DICE_PAIR,
			]
			token.set_target_state(
				die_target_active,
				session.is_legal_die_card_target(die.id)
			)
			token.set_motion_reduced(motion_reduced)
	for die_id in tray_tokens:
		if not retained_tray_ids.has(die_id):
			var stale_token: DieToken = tray_tokens[die_id]
			dice_tray.remove_child(stale_token)
			stale_token.queue_free()
	dice_tray_empty_label.visible = unassigned_dice_count == 0

	var hand_tokens: Dictionary = {}
	for child in hand_container.get_children():
		if child is CardToken and not child.is_queued_for_deletion():
			hand_tokens[child.card_index] = child
	var card_start_block_reason := session.card_start_block_reason()
	for index in range(session.hand.size()):
		var card_token: CardToken = hand_tokens.get(index) as CardToken
		if card_token == null:
			card_token = CARD_SCENE.instantiate()
			hand_container.add_child(card_token)
			card_token.card_activated.connect(_on_card_activated)
		else:
			hand_container.move_child(card_token, index)
		var card_used := session.is_card_used(index)
		card_token.bind_card(
			index,
			session.hand[index],
			session.selection.card_index == index,
			card_used,
			(
				session.selected_card_target_hint()
					if session.selection.card_index == index
					else ""
			),
			"" if card_used else card_start_block_reason
		)
		card_token.set_motion_reduced(motion_reduced)
	for old_index in hand_tokens:
		if int(old_index) >= session.hand.size():
			var stale_card: CardToken = hand_tokens[old_index]
			hand_container.remove_child(stale_card)
			stale_card.queue_free()
	_configure_assigned_die_motion(motion_reduced)
	_refresh_card_detail()

	var gap_is_target := selected_target_type == CardDefinition.TargetType.GAP
	%LeftGap.self_modulate = (
		TARGET_TINT
		if gap_is_target and session.is_legal_gap_card_target(&"left", &"middle")
		else (Color(0.48, 0.48, 0.58, 0.58) if gap_is_target else Color.WHITE)
	)
	%RightGap.self_modulate = (
		TARGET_TINT
		if gap_is_target and session.is_legal_gap_card_target(&"middle", &"right")
		else (Color(0.48, 0.48, 0.58, 0.58) if gap_is_target else Color.WHITE)
	)
	_refresh_direction(preview)
	_refresh_mirror_layers(state)
	resolution_panel.bind_report(preview)
	if dealer_definition != null:
		%DealerHint.text = "已分配：%d / 6\n当前固定奖励：%d / %d" % [
			preview.assigned_dice,
			preview.dealer_reward,
			dealer_definition.fixed_reward,
		]
	error_label.text = session.last_error
	selection_hint_label.text = session.selected_card_target_hint()
	_refresh_active_restriction(state)
	_refresh_area_directive(state, preview)
	calibration_label.text = "校准点：%d" % state.calibration_points
	confirm_button.disabled = session.controller.committed
	%UndoButton.disabled = session.controller.committed or not session.undo_allowed
	%UndoButton.tooltip_text = (
		"落子无悔：本次远征禁止撤销"
		if not session.undo_allowed
		else "撤销上一步操作"
	)
	%MinusButton.disabled = session.controller.committed or state.calibration_points <= 0
	%PlusButton.disabled = session.controller.committed or state.calibration_points <= 0
	view_refreshed.emit()

func _refresh_card_detail() -> void:
	if (
		session.selection.kind != InteractionState.Kind.CARD
		or session.selection.card_index < 0
		or session.selection.card_index >= session.hand.size()
	):
		card_detail_panel.visible = true
		card_detail_icon.visible = false
		card_detail_icon.texture = null
		card_detail_text.text = (
			"手法牌说明\n"
			+ "选择一张手法牌，查看完整规则、作用目标与下一步操作。"
		)
		return
	var card: CardDefinition = session.hand[session.selection.card_index]
	var formatter := CardFormatter.new()
	card_detail_panel.visible = true
	card_detail_icon.visible = true
	card_detail_icon.texture = load(formatter.effect_icon_path(card))
	card_detail_text.text = formatter.detail_copy(
		card,
		session.selected_card_target_hint()
	)

func _refresh_active_restriction(state: RoundState) -> void:
	var restrictions := session.controller.active_restrictions
	active_restriction_badge.visible = not restrictions.is_empty()
	if restrictions.is_empty():
		active_restriction_badge.text = ""
		active_restriction_badge.tooltip_text = ""
		return
	var names: Array[String] = []
	var tooltips: Array[String] = []
	var progress_copy := ""
	for restriction in restrictions:
		names.append(restriction.display_name)
		tooltips.append(restriction.rule_text)
		if (
			restriction.operation
			== FinalRestrictionDefinition.Operation.REQUIRE_ALL_TABLES_OCCUPIED
		):
			progress_copy = " · %s" % RoundRestrictionEvaluator.new().coverage_copy(
				state,
				session.controller.encounter
			)
	active_restriction_badge.text = "公开限制 · %s%s" % [
		" / ".join(names),
		progress_copy,
	]
	active_restriction_badge.tooltip_text = "\n".join(tooltips)

func _refresh_direction(report: ResolutionReport) -> void:
	%DirectionBadge.text = (
		"← 从右向左结算"
		if report.resolution_direction
			== EncounterRuleProfile.ResolutionDirection.RIGHT_TO_LEFT
		else "→ 从左向右结算"
	)

func _refresh_area_directive(
	state: RoundState,
	report: ResolutionReport
) -> void:
	if _area_id == &"" or not is_instance_valid(%AreaDirectiveStatus):
		return
	var rule_count := session.controller.encounter.rules.size()
	var satisfied_count := maxi(0, rule_count - report.rule_failures.size())
	var next_status := ""
	match _area_id:
		&"gold_corridor":
			next_status = (
				"单轮定案 · 条件满足 %d/%d · 校准 %d"
				% [satisfied_count, rule_count, state.calibration_points]
			)
		&"mirror_hall":
			var mirror_count := 0
			for played_card in state.played_cards:
				if played_card.is_mirror_copy:
					mirror_count += 1
			var direction := (
				"右 → 左"
				if report.resolution_direction
					== EncounterRuleProfile.ResolutionDirection.RIGHT_TO_LEFT
				else "左 → 右"
			)
			next_status = "镜像额度 %d/1 · 结算 %s" % [
				mirror_count,
				direction,
			]
		&"faceless_hub":
			var restriction_names: Array[String] = []
			for restriction in session.controller.active_restrictions:
				restriction_names.append(restriction.display_name)
			var protocol := (
				"三轮议程"
				if restriction_names.is_empty()
				else " / ".join(restriction_names)
			)
			next_status = "%s · 条件满足 %d/%d" % [
				protocol,
				satisfied_count,
				rule_count,
			]
	if next_status != %AreaDirectiveStatus.text:
		%AreaDirectiveStatus.text = next_status
		_animate_directive_update()

func _animate_directive_update() -> void:
	if not _motion_allowed():
		%AreaDirectiveAccent.modulate = Color.WHITE
		return
	if _directive_tween != null and _directive_tween.is_valid():
		_directive_tween.kill()
	%AreaDirectiveAccent.modulate = Color(1.0, 1.0, 1.0, 0.35)
	_directive_tween = create_tween()
	_directive_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_directive_tween.tween_property(
		%AreaDirectiveAccent,
		"modulate",
		Color.WHITE,
		0.22
	)

func _motion_allowed() -> bool:
	var settings := get_tree().root.get_node_or_null("SettingsService")
	if settings == null or not settings.has_method("accessibility_value"):
		return true
	return not bool(settings.call("accessibility_value", &"reduce_flashes"))

func _refresh_mirror_layers(state: RoundState) -> void:
	%LeftMirrorLayer.visible = false
	%RightMirrorLayer.visible = false
	for played_card in state.played_cards:
		if not played_card.is_mirror_copy:
			continue
		var targets := {
			played_card.primary_target: true,
			played_card.secondary_target: true,
		}
		var layer: Label
		if targets.has(&"left") and targets.has(&"middle"):
			layer = %LeftMirrorLayer
		elif targets.has(&"middle") and targets.has(&"right"):
			layer = %RightMirrorLayer
		if layer != null:
			layer.text = "┄ 镜像 ┄\n%s" % played_card.definition.display_name
			layer.visible = true

func reset_teaching_encounter() -> void:
	session = SingleEncounterSession.new(
		SingleEncounterFixture.make_state(),
		SingleEncounterFixture.make_encounter(),
		SingleEncounterFixture.make_hand()
	)
	owns_session = true
	refresh_from_session()

func start_tutorial_replay() -> void:
	tutorial.start(true)

func find_tutorial_target(spec: Dictionary) -> Control:
	match spec.get("kind"):
		&"die":
			for node in find_children("*", "Button", true, false):
				if (
					node is DieToken
					and not node.is_queued_for_deletion()
					and node.die_id == spec.get("id")
				):
					return node
		&"card":
			for node in find_children("*", "Button", true, false):
				if (
					node is CardToken
					and not node.is_queued_for_deletion()
					and node.card_index == spec.get("id")
				):
					return node
		&"lane":
			var lane_by_id := {
				&"left": %LeftLane,
				&"middle": %MiddleLane,
				&"right": %RightLane,
			}
			return lane_by_id.get(spec.get("id"))
		&"control":
			return get_node_or_null(NodePath("%" + String(spec.get("id"))))
	return null

func _tutorial_allows(action: StringName, payload: Dictionary) -> bool:
	return tutorial == null or tutorial.allows(action, payload)

func _record_tutorial_action(action: StringName, payload: Dictionary) -> void:
	ui_action_accepted.emit(action, payload)

func _on_tutorial_persistence_warning(message: String) -> void:
	show_transient_warning(message)

func _selected_card_target_type() -> int:
	if session.selection.kind != InteractionState.Kind.CARD:
		return -1
	return session.hand[session.selection.card_index].target_type

func _is_assigned(die_id: StringName) -> bool:
	return session.controller.state.is_assigned(die_id)

func _on_die_activated(die_id: StringName) -> void:
	var action := &"select_die"
	var payload := {"die_id": die_id}
	var card_motion: Dictionary = {}
	if session.selection.kind == InteractionState.Kind.CARD:
		action = &"card_die"
		payload["card_index"] = session.selection.card_index
		card_motion = _capture_card_motion(session.selection.card_index)
	if not _tutorial_allows(action, payload):
		return
	var accepted := session.activate_die(die_id)
	if accepted:
		_record_tutorial_action(action, payload)
		SfxAccess.play(self, &"card_play" if action == &"card_die" else &"die_select")
	elif not session.last_error.is_empty():
		SfxAccess.play(self, &"error")
	refresh_from_session()
	if accepted and action == &"card_die":
		var affected_die := _find_die_token(die_id)
		_play_card_transition(card_motion, affected_die)
		var assignment := session.controller.state.find_assignment(die_id)
		_play_card_rule_response(
			int(payload["card_index"]),
			affected_die,
			assignment.get("table_id", &"")
		)
	elif not accepted:
		_reject_feedback(_find_die_token(die_id))

func _on_card_activated(card_index: int) -> void:
	var card := session.hand[card_index]
	var card_motion := _capture_card_motion(card_index)
	if (
		session.selection.kind == InteractionState.Kind.CARD
		and session.selection.card_index == card_index
	):
		session.cancel_selection()
		SfxAccess.play(self, &"ui_back")
		refresh_from_session()
		return
	var report_selection := false
	var action := (
		&"card_global"
		if card.target_type == CardDefinition.TargetType.GLOBAL
		else &"select_card"
	)
	var payload := {"card_index": card_index}
	if not _tutorial_allows(action, payload):
		return
	var accepted := session.activate_card(card_index)
	if accepted:
		_record_tutorial_action(action, payload)
		if action == &"select_card":
			report_selection = true
		SfxAccess.play(
			self,
			&"card_play" if action == &"card_global" else &"card_select"
		)
	elif not session.last_error.is_empty():
		SfxAccess.play(self, &"error")
	refresh_from_session()
	if accepted and action == &"card_global":
		_play_card_transition(card_motion, %MiddleLane)
		_play_card_rule_response(
			int(payload["card_index"]),
			%MiddleLane.get_node_or_null("%Formula") as Control,
			&"middle"
		)
	elif not accepted:
		_reject_feedback(_find_hand_card_token(card_index))
	if report_selection:
		var token := _find_hand_card_token(card_index)
		if token != null:
			card_selected.emit(card_index, card, token)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	var key_event := event as InputEventKey
	if key_event == null or key_event.keycode != KEY_ESCAPE:
		return
	if session.cancel_selection():
		SfxAccess.play(self, &"ui_back")
		refresh_from_session()
		get_viewport().set_input_as_handled()

func _find_hand_card_token(card_index: int) -> CardToken:
	for child in hand_container.get_children():
		if (
			child is CardToken
			and not child.is_queued_for_deletion()
			and child.card_index == card_index
		):
			return child
	return null

func _find_die_token(die_id: StringName) -> DieToken:
	return _find_die_token_under(self, die_id)

func _find_die_token_under(root: Node, die_id: StringName) -> DieToken:
	for child in root.get_children():
		if (
			child is DieToken
			and not child.is_queued_for_deletion()
			and child.die_id == die_id
		):
			return child
		var nested := _find_die_token_under(child, die_id)
		if nested != null:
			return nested
	return null

func _configure_assigned_die_motion(reduced: bool) -> void:
	for lane in lanes:
		_configure_die_motion_under(lane, reduced)

func _configure_die_motion_under(root: Node, reduced: bool) -> void:
	for child in root.get_children():
		if child is DieToken:
			child.set_motion_reduced(reduced)
		else:
			_configure_die_motion_under(child, reduced)

func _capture_die_motion(die_id: StringName) -> Dictionary:
	var token := _find_die_token(die_id)
	if token == null:
		return {}
	var face_icon := token.get_node_or_null("%FaceIcon") as TextureRect
	return {
		"die_id": die_id,
		"rect": token.get_global_rect(),
		"texture": face_icon.texture if face_icon != null else null,
	}

func _capture_card_motion(card_index: int) -> Dictionary:
	var token := _find_hand_card_token(card_index)
	if token == null or card_index < 0 or card_index >= session.hand.size():
		return {}
	return {
		"card_index": card_index,
		"definition": session.hand[card_index],
		"rect": token.get_global_rect(),
	}

func _play_die_transition(
	capture: Dictionary,
	die_id: StringName,
	returning := false
) -> void:
	if capture.is_empty():
		return
	call_deferred("_complete_die_transition", capture, die_id, returning)

func _complete_die_transition(
	capture: Dictionary,
	die_id: StringName,
	returning: bool
) -> void:
	if not is_inside_tree():
		return
	var target := _find_die_token(die_id)
	if target == null:
		return
	var hidden_modulate := target.modulate
	hidden_modulate.a = 0.0
	target.modulate = hidden_modulate
	target.set_meta("awaiting_motion_arrival", true)
	var reveal_target := Callable(self, "_finish_die_transition").bind(
		target.get_instance_id(),
		returning
	)
	interaction_motion_layer.fly_die(
		capture.get("texture") as Texture2D,
		capture.get("rect") as Rect2,
		target.get_global_rect(),
		returning,
		reveal_target
	)

func _finish_die_transition(target_instance_id: int, _returning: bool) -> void:
	if not is_instance_id_valid(target_instance_id):
		return
	var target := instance_from_id(target_instance_id) as DieToken
	if target == null or not target.is_inside_tree():
		return
	var visible_modulate := target.modulate
	visible_modulate.a = 1.0
	target.modulate = visible_modulate
	target.set_meta("awaiting_motion_arrival", false)
	target.scale = Vector2.ONE
	target.rotation = 0.0

func _play_card_transition(capture: Dictionary, target: Control) -> void:
	if capture.is_empty() or target == null:
		return
	var source_token := _find_hand_card_token(int(capture.get("card_index", -1)))
	if source_token != null:
		source_token.play_commit_feedback()
	interaction_motion_layer.fly_card(
		capture.get("definition") as CardDefinition,
		capture.get("rect") as Rect2,
		target.get_global_rect()
	)


func _play_die_rule_response(
	die_id: StringName,
	table_id: StringName,
	initial_delay := 0.12,
	include_rule_lane := false
) -> void:
	var source_token := _find_die_token(die_id)
	var source: Control = source_token
	if source_token != null:
		var face_icon := source_token.get_node_or_null("%FaceIcon") as Control
		if face_icon != null:
			source = face_icon
	var affected: Control = null
	if source_token != null and source_token.get_parent() is RuleSlot:
		affected = source_token.get_parent() as Control
	_play_rule_response(
		source,
		affected,
		table_id,
		initial_delay,
		include_rule_lane
	)


func _play_card_rule_response(
	card_index: int,
	affected: Control,
	table_id: StringName,
	initial_delay := 0.0
) -> void:
	_play_rule_response(
		_find_hand_card_token(card_index),
		affected,
		table_id,
		initial_delay
	)


func _play_rule_response(
	source: Control,
	affected: Control,
	table_id: StringName,
	initial_delay := 0.0,
	include_rule_lane := true
) -> void:
	var lane := _lane_for_id(table_id)
	if affected == null and lane != null:
		affected = lane.get_node_or_null("%Formula") as Control
	var prediction := resolution_panel.get_node_or_null("%Total") as Control
	interaction_motion_layer.play_response_sequence([
		{"role": &"source", "target": source},
		{"role": &"affected", "target": affected},
		{
			"role": &"rule",
			"target": lane if include_rule_lane else null,
		},
		{"role": &"prediction", "target": prediction},
	], initial_delay)


func _table_slots_full(table_id: StringName) -> bool:
	if table_id == &"":
		return false
	var slot_count := session.controller.effective_slot_count(table_id)
	if slot_count <= 0:
		return false
	var slots := session.controller.state.slot_values(table_id, slot_count)
	return slots.size() == slot_count and not slots.has(RoundState.EMPTY_SLOT)

func _lane_for_id(table_id: StringName) -> RuleLane:
	var lane_by_id := {
		&"left": %LeftLane,
		&"middle": %MiddleLane,
		&"right": %RightLane,
	}
	return lane_by_id.get(table_id) as RuleLane

func _reject_feedback(target: Control = null) -> void:
	interaction_motion_layer.reject_target(
		target if target != null else error_label
	)

func _on_lane_activated(table_id: StringName) -> void:
	var action := &"click_assign"
	var payload: Dictionary
	var die_motion: Dictionary = {}
	var card_motion: Dictionary = {}
	if session.selection.kind == InteractionState.Kind.DIE:
		payload = {"die_id": session.selection.die_id, "table_id": table_id}
		die_motion = _capture_die_motion(session.selection.die_id)
	elif session.selection.kind == InteractionState.Kind.CARD:
		action = &"card_table"
		payload = {"card_index": session.selection.card_index, "table_id": table_id}
		card_motion = _capture_card_motion(session.selection.card_index)
	else:
		payload = {"table_id": table_id}
	if not _tutorial_allows(action, payload):
		return
	var table_was_full := _table_slots_full(table_id)
	var accepted := session.activate_table(table_id)
	if accepted:
		_record_tutorial_action(action, payload)
		SfxAccess.play(self, &"card_play" if action == &"card_table" else &"die_place")
	elif not session.last_error.is_empty():
		SfxAccess.play(self, &"error")
	refresh_from_session()
	if accepted and action == &"card_table":
		_play_card_transition(card_motion, _lane_for_id(table_id))
		_play_card_rule_response(
			int(payload["card_index"]),
			_lane_for_id(table_id).get_node_or_null("%Formula") as Control,
			table_id
		)
	elif accepted and payload.has("die_id"):
		_play_die_transition(die_motion, payload["die_id"])
		_play_die_rule_response(
			payload["die_id"],
			table_id,
			0.32,
			not table_was_full and _table_slots_full(table_id)
		)
	elif not accepted:
		_reject_feedback(_lane_for_id(table_id))

func _on_slot_activated(table_id: StringName, slot_index: int) -> void:
	var action := &"click_assign"
	var die_motion: Dictionary = {}
	var card_motion: Dictionary = {}
	var payload := {
		"table_id": table_id,
		"slot_index": slot_index,
	}
	if session.selection.kind == InteractionState.Kind.DIE:
		payload["die_id"] = session.selection.die_id
		die_motion = _capture_die_motion(session.selection.die_id)
	elif session.selection.kind == InteractionState.Kind.CARD:
		action = &"card_table"
		payload["card_index"] = session.selection.card_index
		card_motion = _capture_card_motion(session.selection.card_index)
	if not _tutorial_allows(action, payload):
		return
	var table_was_full := _table_slots_full(table_id)
	var accepted := session.activate_slot(table_id, slot_index)
	if accepted:
		_record_tutorial_action(action, payload)
		SfxAccess.play(
			self,
			&"card_play" if action == &"card_table" else &"die_place"
		)
	elif not session.last_error.is_empty():
		SfxAccess.play(self, &"error")
	refresh_from_session()
	if accepted and action == &"card_table":
		_play_card_transition(card_motion, _lane_for_id(table_id))
		_play_card_rule_response(
			int(payload["card_index"]),
			_lane_for_id(table_id).get_node_or_null("%Formula") as Control,
			table_id
		)
	elif accepted and payload.has("die_id"):
		_play_die_transition(die_motion, payload["die_id"])
		_play_die_rule_response(
			payload["die_id"],
			table_id,
			0.32,
			not table_was_full and _table_slots_full(table_id)
		)
	elif not accepted:
		_reject_feedback(_lane_for_id(table_id))

func _on_die_drop_requested(die_id: StringName, table_id: StringName) -> void:
	var payload := {"die_id": die_id, "table_id": table_id}
	if not _tutorial_allows(&"drag_assign", payload):
		return
	var table_was_full := _table_slots_full(table_id)
	var accepted := session.assign_dropped_die(die_id, table_id)
	if accepted:
		_record_tutorial_action(&"drag_assign", payload)
		SfxAccess.play(self, &"die_place")
	elif not session.last_error.is_empty():
		SfxAccess.play(self, &"error")
	refresh_from_session()
	if accepted:
		_play_die_rule_response(
			die_id,
			table_id,
			0.12,
			not table_was_full and _table_slots_full(table_id)
		)
	else:
		_reject_feedback(_lane_for_id(table_id))

func _on_die_drop_to_slot_requested(
	die_id: StringName,
	table_id: StringName,
	slot_index: int
) -> void:
	var payload := {
		"die_id": die_id,
		"table_id": table_id,
		"slot_index": slot_index,
	}
	if not _tutorial_allows(&"drag_assign", payload):
		return
	var table_was_full := _table_slots_full(table_id)
	var accepted := session.assign_dropped_die_to_slot(
		die_id,
		table_id,
		slot_index
	)
	if accepted:
		_record_tutorial_action(&"drag_assign", payload)
		SfxAccess.play(self, &"die_place")
	elif not session.last_error.is_empty():
		SfxAccess.play(self, &"error")
	refresh_from_session()
	if accepted:
		_play_die_rule_response(
			die_id,
			table_id,
			0.12,
			not table_was_full and _table_slots_full(table_id)
		)
	else:
		_reject_feedback(_lane_for_id(table_id))


func _on_die_return_requested(die_id: StringName) -> void:
	_return_die_to_tray(die_id, true)


func _on_die_drop_return_requested(die_id: StringName) -> void:
	_return_die_to_tray(die_id, false)


func _return_die_to_tray(die_id: StringName, play_transition: bool) -> void:
	var payload := {"die_id": die_id}
	var die_motion := _capture_die_motion(die_id) if play_transition else {}
	if not _tutorial_allows(&"return_die", payload):
		return
	var accepted := session.return_die_to_tray(die_id)
	if accepted:
		_record_tutorial_action(&"return_die", payload)
		SfxAccess.play(self, &"die_return")
	elif not session.last_error.is_empty():
		SfxAccess.play(self, &"error")
	refresh_from_session()
	if accepted and play_transition:
		_play_die_transition(die_motion, die_id, true)
	elif not accepted:
		_reject_feedback(_find_die_token(die_id))

func _on_gap_activated(left_id: StringName, right_id: StringName) -> void:
	var card_motion := _capture_card_motion(session.selection.card_index)
	var payload := {
		"card_index": session.selection.card_index,
		"left_id": left_id,
		"right_id": right_id,
	}
	if not _tutorial_allows(&"card_gap", payload):
		return
	var accepted := session.activate_gap(left_id, right_id)
	if accepted:
		_record_tutorial_action(&"card_gap", payload)
		SfxAccess.play(self, &"card_play")
	elif not session.last_error.is_empty():
		SfxAccess.play(self, &"error")
	refresh_from_session()
	var gap: Control = %LeftGap if left_id == &"left" else %RightGap
	if accepted:
		_play_card_transition(card_motion, gap)
		_play_card_rule_response(
			int(payload["card_index"]),
			gap,
			left_id
		)
	else:
		_reject_feedback(gap)

func _on_calibrate_pressed(delta: int) -> void:
	if session.selection.kind != InteractionState.Kind.DIE:
		SfxAccess.play(self, &"error")
		session.last_error = "请先选择一颗骰子"
		refresh_from_session()
		_reject_feedback(error_label)
		return
	var payload := {"die_id": session.selection.die_id, "delta": delta}
	if not _tutorial_allows(&"calibrate", payload):
		return
	var accepted := session.calibrate_die(session.selection.die_id, delta)
	if accepted:
		_record_tutorial_action(&"calibrate", payload)
		SfxAccess.play(self, &"calibrate_up" if delta > 0 else &"calibrate_down")
	elif not session.last_error.is_empty():
		SfxAccess.play(self, &"error")
	refresh_from_session()
	var calibrated_die := _find_die_token(payload["die_id"])
	if accepted:
		interaction_motion_layer.pulse_target(calibrated_die, &"impact")
	else:
		_reject_feedback(calibrated_die)

func _on_undo_pressed() -> void:
	if not _tutorial_allows(&"undo", {}):
		return
	var accepted := session.undo()
	if accepted:
		_record_tutorial_action(&"undo", {})
		SfxAccess.play(self, &"undo")
	elif not session.last_error.is_empty():
		SfxAccess.play(self, &"error")
	refresh_from_session()

func _on_confirm_pressed() -> void:
	if not _tutorial_allows(&"commit", {}):
		return
	var was_committed := session.controller.committed
	var report := session.commit()
	if report.valid and not was_committed and session.controller.committed:
		_record_tutorial_action(&"commit", {})
		if owns_session:
			SfxAccess.play(self, &"round_commit")
	refresh_from_session()
	if report.valid and not was_committed and session.controller.committed:
		interaction_motion_layer.pulse_target(resolution_panel, &"impact")
		resolution_panel.play_committed_report(
			report,
			_accessibility_settings()
		)

func _on_resolution_playback_finished(report: ResolutionReport) -> void:
	_clear_resolution_source_focus()
	round_committed.emit(report)

func _on_resolution_source_focus_requested(source_id: StringName) -> void:
	_clear_resolution_source_focus()
	var lane_by_id := {
		&"left": %LeftLane,
		&"middle": %MiddleLane,
		&"right": %RightLane,
	}
	if lane_by_id.has(source_id):
		lane_by_id[source_id].self_modulate = TARGET_TINT
	elif source_id == &"left_gap":
		%LeftGap.self_modulate = TARGET_TINT
	elif source_id == &"right_gap":
		%RightGap.self_modulate = TARGET_TINT

func _clear_resolution_source_focus() -> void:
	for lane in lanes:
		lane.self_modulate = Color.WHITE
	%LeftGap.self_modulate = Color.WHITE
	%RightGap.self_modulate = Color.WHITE

func _accessibility_settings() -> Dictionary:
	var settings_service := get_node_or_null("/root/SettingsService")
	if settings_service == null:
		return {}
	var snapshot: Dictionary = settings_service.call("settings_snapshot")
	return snapshot.get("accessibility", {}).duplicate(true)

func _on_run_trial_pressed() -> void:
	_launch_gold_corridor()

func _on_replay_gold_corridor_guide_pressed() -> void:
	var store := GoldCorridorGuideProgressStore.new(tutorial_config_path)
	var result := store.reset()
	if result != OK:
		_on_tutorial_persistence_warning(
			"无法重置区域提示；仍可正常进入六面诡局。"
		)
		return
	_launch_gold_corridor()

func _launch_gold_corridor() -> void:
	get_tree().root.set_meta("gold_corridor_guide_config_path", tutorial_config_path)
	SfxAccess.play(self, &"page_transition")
	get_tree().change_scene_to_file("res://scenes/run/gold_corridor_run_screen.tscn")

func _on_mirror_hall_run_pressed() -> void:
	_launch_mirror_hall()

func _on_replay_mirror_hall_guide_pressed() -> void:
	var store := MirrorHallGuideProgressStore.new(tutorial_config_path)
	var result := store.reset()
	if result != OK:
		_on_tutorial_persistence_warning(
			"无法重置反照牌厅提示；仍可正常进入反照牌厅。"
		)
		return
	_launch_mirror_hall()

func _launch_mirror_hall() -> void:
	get_tree().root.set_meta("mirror_hall_guide_config_path", tutorial_config_path)
	SfxAccess.play(self, &"page_transition")
	get_tree().change_scene_to_file("res://scenes/run/mirror_hall_run_screen.tscn")

func _on_faceless_hub_run_pressed() -> void:
	_launch_faceless_hub()

func _on_replay_faceless_hub_guide_pressed() -> void:
	var store := FacelessHubGuideProgressStore.new(tutorial_config_path)
	var result := store.reset()
	if result != OK:
		_on_tutorial_persistence_warning(
			"无法重置无面中枢提示；仍可正常进入无面中枢。"
		)
		return
	_launch_faceless_hub()

func _launch_faceless_hub() -> void:
	get_tree().root.set_meta(
		"faceless_hub_guide_config_path",
		tutorial_config_path
	)
	SfxAccess.play(self, &"page_transition")
	get_tree().change_scene_to_file(
		"res://scenes/run/faceless_hub_run_screen.tscn"
	)

func _on_replay_advanced_guide_pressed() -> void:
	var store := IronAbacusGuideProgressStore.new(tutorial_config_path)
	var reset_result := store.reset()
	if reset_result != OK:
		_on_tutorial_persistence_warning(
			"无法重置进阶引导状态；仍可正常进入六面诡局。"
		)
		return
	_launch_iron_abacus_slice()

func _launch_iron_abacus_slice() -> void:
	get_tree().root.set_meta("iron_abacus_guide_config_path", tutorial_config_path)
	SfxAccess.play(self, &"page_transition")
	get_tree().change_scene_to_file("res://scenes/run/iron_abacus_slice_screen.tscn")
