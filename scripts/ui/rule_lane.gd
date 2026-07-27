class_name RuleLane
extends PanelContainer

signal lane_activated(table_id: StringName)
signal die_activated(die_id: StringName)
signal die_drop_requested(die_id: StringName, table_id: StringName)

@onready var title_label: Label = %Title
@onready var condition_label: Label = %Condition
@onready var slots: HBoxContainer = %Slots

var table_id: StringName

func _gui_input(event: InputEvent) -> void:
	if (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
	):
		lane_activated.emit(table_id)
		accept_event()

func bind_lane(
	rule: RuleDefinition,
	assigned_dice: Array,
	die_scene: PackedScene,
	selected_die_id: StringName,
	engraving_catalog: EngravingCatalog = null,
	effective_slot_count: int = -1,
	condition_summary: String = ""
) -> void:
	table_id = rule.id
	title_label.text = rule.display_name
	var slot_count := (
		rule.slot_count
		if effective_slot_count < 0
		else effective_slot_count
	)
	condition_label.text = "%d 个骰位 · 系数 ×%d" % [
		slot_count,
		rule.coefficient,
	]
	if not condition_summary.is_empty():
		condition_label.text += "\n条件变化：%s" % condition_summary
	for child in slots.get_children():
		child.queue_free()
	for die in assigned_dice:
		var token: DieToken = die_scene.instantiate()
		slots.add_child(token)
		token.bind_die_with_engravings(
			die,
			die.id == selected_die_id,
			engraving_catalog,
			true
		)
		token.die_activated.connect(func(id: StringName) -> void: die_activated.emit(id))
	for empty_index in range(slot_count - assigned_dice.size()):
		var empty := Label.new()
		empty.text = "＋"
		empty.custom_minimum_size = Vector2(54, 54)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slots.add_child(empty)

func set_legal_target(value: bool) -> void:
	self_modulate = Color(0.68, 1.0, 0.96, 1.0) if value else Color.WHITE

func set_target_state(active: bool, legal: bool) -> void:
	if not active:
		self_modulate = Color.WHITE
	elif legal:
		self_modulate = Color(0.68, 1.0, 0.96, 1.0)
	else:
		self_modulate = Color(0.48, 0.48, 0.58, 0.58)

func set_die_target_highlight(value: bool) -> void:
	for child in slots.get_children():
		if child is DieToken:
			child.set_legal_target(value)

func set_die_card_target_state(
	active: bool,
	legal_target: Callable
) -> void:
	for child in slots.get_children():
		if child is DieToken:
			child.set_target_state(
				active,
				legal_target.call(child.die_id) if active else false
			)

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.get("kind") == "die"

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	die_drop_requested.emit(data.get("die_id"), table_id)
