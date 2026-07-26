class_name SingleEncounterScreen
extends Control

signal view_refreshed
signal ui_action_accepted(action: StringName, payload: Dictionary)
signal round_committed(report: ResolutionReport)

const DIE_SCENE = preload("res://scenes/components/die_token.tscn")
const CARD_SCENE = preload("res://scenes/components/card_token.tscn")
const TARGET_TINT := Color(0.68, 1.0, 0.96, 1.0)

@export var tutorial_auto_start: bool = true
@export var tutorial_config_path: String = "user://onboarding.cfg"

@onready var lanes: Array[RuleLane] = [%LeftLane, %MiddleLane, %RightLane]
@onready var dice_tray: DiceTray = %DiceTray
@onready var hand_container: HBoxContainer = %Hand
@onready var resolution_panel: ResolutionPanel = %ResolutionPanel
@onready var error_label: Label = %ErrorLabel
@onready var calibration_label: Label = %CalibrationLabel
@onready var confirm_button: Button = %ConfirmButton
@onready var tutorial: SingleEncounterTutorial = %SingleEncounterTutorial
@onready var area_label: Label = %AreaLabel
@onready var goal_label: Label = %GoalLabel
@onready var replay_tutorial_button: Button = %ReplayTutorialButton
@onready var replay_advanced_guide_button: Button = %ReplayAdvancedGuideButton
@onready var replay_gold_corridor_guide_button: Button = %ReplayGoldCorridorGuideButton
@onready var run_trial_button: Button = %RunTrialButton

var session: SingleEncounterSession
var dealer_definition: DealerDefinition

func _ready() -> void:
	session = SingleEncounterSession.new(
		SingleEncounterFixture.make_state(),
		SingleEncounterFixture.make_encounter(),
		SingleEncounterFixture.make_hand()
	)
	for lane in lanes:
		lane.lane_activated.connect(_on_lane_activated)
		lane.die_activated.connect(_on_die_activated)
		lane.die_drop_requested.connect(_on_die_drop_requested)
	dice_tray.die_return_requested.connect(_on_die_return_requested)
	%LeftGap.pressed.connect(func() -> void: _on_gap_activated(&"left", &"middle"))
	%RightGap.pressed.connect(func() -> void: _on_gap_activated(&"middle", &"right"))
	%MinusButton.pressed.connect(func() -> void: _on_calibrate_pressed(-1))
	%PlusButton.pressed.connect(func() -> void: _on_calibrate_pressed(1))
	%UndoButton.pressed.connect(_on_undo_pressed)
	confirm_button.pressed.connect(_on_confirm_pressed)
	refresh_from_session()
	tutorial.configure(self, TutorialProgressStore.new(tutorial_config_path))
	tutorial.persistence_warning.connect(_on_tutorial_persistence_warning)
	replay_tutorial_button.pressed.connect(start_tutorial_replay)
	replay_advanced_guide_button.pressed.connect(_on_replay_advanced_guide_pressed)
	replay_gold_corridor_guide_button.pressed.connect(_on_replay_gold_corridor_guide_pressed)
	run_trial_button.pressed.connect(_on_run_trial_pressed)
	if tutorial_auto_start:
		tutorial.call_deferred("maybe_start")

func bind_external_session(
	p_session: SingleEncounterSession,
	area_copy: String,
	goal_copy: String
) -> void:
	if p_session == null:
		return
	tutorial.active = false
	tutorial.visible = false
	replay_tutorial_button.visible = false
	replay_advanced_guide_button.visible = false
	replay_gold_corridor_guide_button.visible = false
	run_trial_button.visible = false
	session = p_session
	set_run_status(area_copy, goal_copy)
	refresh_from_session()

func set_run_status(area_copy: String, goal_copy: String) -> void:
	area_label.text = area_copy
	goal_label.text = goal_copy

func bind_dealer(dealer: DealerDefinition) -> void:
	dealer_definition = dealer
	if dealer == null:
		%DealerEyebrow.text = "规则监理 / MIRROR-01"
		%DealerName.text = "镜面夫人"
		%DealerRule.text = "本场规则\n从左向右逐轨解析。所有变化都会先出现在结算轨迹中。"
		%DealerHint.text = "把骰子拖入规则轨，或先选骰子再选规则轨。"
		return
	%DealerEyebrow.text = "庄家挑战 / %s" % String(dealer.id).to_upper()
	%DealerName.text = dealer.display_name
	%DealerRule.text = dealer.rule_text

func bind_verification(engraving: EngravingDefinition) -> void:
	dealer_definition = null
	%DealerEyebrow.text = "刻印校验 / GUARANTEED FACE"
	%DealerName.text = "刻印验证"
	%DealerRule.text = engraving.rule_text
	%DealerHint.text = "所选骰子的刻印面已公开强制朝上；把它分配到有效规则台。"

func show_external_error(message: String) -> void:
	session.last_error = message
	error_label.text = message

func refresh_from_session() -> void:
	var state := session.controller.state
	var selected_target_type := _selected_card_target_type()
	var engraving_catalog := session.controller.resolution_context.engraving_catalog
	for lane_index in range(lanes.size()):
		var rule := session.controller.encounter.rules[lane_index]
		var assigned: Array = []
		for die_id in state.assignments.get(rule.id, []):
			assigned.append(state.find_die(die_id))
		lanes[lane_index].bind_lane(
			rule,
			assigned,
			DIE_SCENE,
			session.selection.die_id,
			engraving_catalog
		)
		lanes[lane_index].set_legal_target(
			selected_target_type == CardDefinition.TargetType.TABLE
		)
		lanes[lane_index].set_die_target_highlight(
			selected_target_type == CardDefinition.TargetType.DIE
		)

	for child in dice_tray.get_children():
		child.queue_free()
	for die in state.dice:
		if not _is_assigned(die.id):
			var token: DieToken = DIE_SCENE.instantiate()
			dice_tray.add_child(token)
			token.bind_die_with_engravings(
				die,
				session.selection.die_id == die.id,
				engraving_catalog,
				false
			)
			token.set_legal_target(selected_target_type == CardDefinition.TargetType.DIE)
			token.die_activated.connect(_on_die_activated)

	for child in hand_container.get_children():
		child.queue_free()
	for index in range(session.hand.size()):
		var card_token: CardToken = CARD_SCENE.instantiate()
		hand_container.add_child(card_token)
		card_token.bind_card(
			index,
			session.hand[index],
			session.selection.card_index == index,
			session.is_card_used(index)
		)
		card_token.card_activated.connect(_on_card_activated)

	var gap_is_target := selected_target_type == CardDefinition.TargetType.GAP
	%LeftGap.self_modulate = TARGET_TINT if gap_is_target else Color.WHITE
	%RightGap.self_modulate = TARGET_TINT if gap_is_target else Color.WHITE
	var preview := session.preview()
	resolution_panel.bind_report(preview)
	if dealer_definition != null:
		%DealerHint.text = "已分配：%d / 6\n当前固定奖励：%d / %d" % [
			preview.assigned_dice,
			preview.dealer_reward,
			dealer_definition.fixed_reward,
		]
	error_label.text = session.last_error
	calibration_label.text = "校准点：%d" % state.calibration_points
	confirm_button.disabled = session.controller.committed
	%MinusButton.disabled = session.controller.committed or state.calibration_points <= 0
	%PlusButton.disabled = session.controller.committed or state.calibration_points <= 0
	view_refreshed.emit()

func reset_teaching_encounter() -> void:
	session = SingleEncounterSession.new(
		SingleEncounterFixture.make_state(),
		SingleEncounterFixture.make_encounter(),
		SingleEncounterFixture.make_hand()
	)
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
	session.last_error = message
	error_label.text = message

func _selected_card_target_type() -> int:
	if session.selection.kind != InteractionState.Kind.CARD:
		return -1
	return session.hand[session.selection.card_index].target_type

func _is_assigned(die_id: StringName) -> bool:
	for table_id in session.controller.state.assignments:
		if die_id in session.controller.state.assignments[table_id]:
			return true
	return false

func _on_die_activated(die_id: StringName) -> void:
	var action := &"select_die"
	var payload := {"die_id": die_id}
	if session.selection.kind == InteractionState.Kind.CARD:
		action = &"card_die"
		payload["card_index"] = session.selection.card_index
	if not _tutorial_allows(action, payload):
		return
	if session.activate_die(die_id):
		_record_tutorial_action(action, payload)
	refresh_from_session()

func _on_card_activated(card_index: int) -> void:
	var card := session.hand[card_index]
	var action := (
		&"card_global"
		if card.target_type == CardDefinition.TargetType.GLOBAL
		else &"select_card"
	)
	var payload := {"card_index": card_index}
	if not _tutorial_allows(action, payload):
		return
	if session.activate_card(card_index):
		_record_tutorial_action(action, payload)
	refresh_from_session()

func _on_lane_activated(table_id: StringName) -> void:
	var action := &"click_assign"
	var payload: Dictionary
	if session.selection.kind == InteractionState.Kind.DIE:
		payload = {"die_id": session.selection.die_id, "table_id": table_id}
	elif session.selection.kind == InteractionState.Kind.CARD:
		action = &"card_table"
		payload = {"card_index": session.selection.card_index, "table_id": table_id}
	else:
		payload = {"table_id": table_id}
	if not _tutorial_allows(action, payload):
		return
	if session.activate_table(table_id):
		_record_tutorial_action(action, payload)
	refresh_from_session()

func _on_die_drop_requested(die_id: StringName, table_id: StringName) -> void:
	var payload := {"die_id": die_id, "table_id": table_id}
	if not _tutorial_allows(&"drag_assign", payload):
		return
	if session.assign_dropped_die(die_id, table_id):
		_record_tutorial_action(&"drag_assign", payload)
	refresh_from_session()

func _on_die_return_requested(die_id: StringName) -> void:
	var payload := {"die_id": die_id}
	if not _tutorial_allows(&"return_die", payload):
		return
	if session.return_die_to_tray(die_id):
		_record_tutorial_action(&"return_die", payload)
	refresh_from_session()

func _on_gap_activated(left_id: StringName, right_id: StringName) -> void:
	var payload := {
		"card_index": session.selection.card_index,
		"left_id": left_id,
		"right_id": right_id,
	}
	if not _tutorial_allows(&"card_gap", payload):
		return
	if session.activate_gap(left_id, right_id):
		_record_tutorial_action(&"card_gap", payload)
	refresh_from_session()

func _on_calibrate_pressed(delta: int) -> void:
	if session.selection.kind != InteractionState.Kind.DIE:
		session.last_error = "请先选择一颗骰子"
		refresh_from_session()
		return
	var payload := {"die_id": session.selection.die_id, "delta": delta}
	if not _tutorial_allows(&"calibrate", payload):
		return
	if session.calibrate_die(session.selection.die_id, delta):
		_record_tutorial_action(&"calibrate", payload)
	refresh_from_session()

func _on_undo_pressed() -> void:
	if not _tutorial_allows(&"undo", {}):
		return
	if session.undo():
		_record_tutorial_action(&"undo", {})
	refresh_from_session()

func _on_confirm_pressed() -> void:
	if not _tutorial_allows(&"commit", {}):
		return
	var was_committed := session.controller.committed
	var report := session.commit()
	if report.valid and not was_committed and session.controller.committed:
		_record_tutorial_action(&"commit", {})
	refresh_from_session()
	if report.valid and not was_committed and session.controller.committed:
		round_committed.emit(report)

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
	get_tree().change_scene_to_file("res://scenes/run/gold_corridor_run_screen.tscn")

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
	get_tree().change_scene_to_file("res://scenes/run/iron_abacus_slice_screen.tscn")
