class_name SingleEncounterScreen
extends Control

const DIE_SCENE = preload("res://scenes/components/die_token.tscn")
const CARD_SCENE = preload("res://scenes/components/card_token.tscn")
const TARGET_TINT := Color(0.68, 1.0, 0.96, 1.0)

@onready var lanes: Array[RuleLane] = [%LeftLane, %MiddleLane, %RightLane]
@onready var dice_tray: DiceTray = %DiceTray
@onready var hand_container: HBoxContainer = %Hand
@onready var resolution_panel: ResolutionPanel = %ResolutionPanel
@onready var error_label: Label = %ErrorLabel
@onready var calibration_label: Label = %CalibrationLabel
@onready var confirm_button: Button = %ConfirmButton

var session: SingleEncounterSession

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

func refresh_from_session() -> void:
	var state := session.controller.state
	var selected_target_type := _selected_card_target_type()
	for lane_index in range(lanes.size()):
		var rule := session.controller.encounter.rules[lane_index]
		var assigned: Array = []
		for die_id in state.assignments.get(rule.id, []):
			assigned.append(state.find_die(die_id))
		lanes[lane_index].bind_lane(
			rule,
			assigned,
			DIE_SCENE,
			session.selection.die_id
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
			token.bind_die(die, session.selection.die_id == die.id)
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
	resolution_panel.bind_report(session.preview())
	error_label.text = session.last_error
	calibration_label.text = "校准点：%d" % state.calibration_points
	confirm_button.disabled = session.controller.committed
	%MinusButton.disabled = session.controller.committed or state.calibration_points <= 0
	%PlusButton.disabled = session.controller.committed or state.calibration_points <= 0

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
	session.activate_die(die_id)
	refresh_from_session()

func _on_card_activated(card_index: int) -> void:
	session.activate_card(card_index)
	refresh_from_session()

func _on_lane_activated(table_id: StringName) -> void:
	session.activate_table(table_id)
	refresh_from_session()

func _on_die_drop_requested(die_id: StringName, table_id: StringName) -> void:
	session.assign_dropped_die(die_id, table_id)
	refresh_from_session()

func _on_die_return_requested(die_id: StringName) -> void:
	session.return_die_to_tray(die_id)
	refresh_from_session()

func _on_gap_activated(left_id: StringName, right_id: StringName) -> void:
	session.activate_gap(left_id, right_id)
	refresh_from_session()

func _on_calibrate_pressed(delta: int) -> void:
	if session.selection.kind != InteractionState.Kind.DIE:
		session.last_error = "请先选择一颗骰子"
	else:
		session.calibrate_die(session.selection.die_id, delta)
	refresh_from_session()

func _on_undo_pressed() -> void:
	session.undo()
	refresh_from_session()

func _on_confirm_pressed() -> void:
	session.commit()
	refresh_from_session()
