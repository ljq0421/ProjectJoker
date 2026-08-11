class_name RuleSlot
extends Button

signal slot_activated(slot_index: int)
signal die_activated(die_id: StringName)
signal die_drop_requested(die_id: StringName, slot_index: int)
signal die_return_requested(die_id: StringName)

var index: int = -1
var die_id: StringName = &""
var selected_die_id: StringName = &""

func _ready() -> void:
	pressed.connect(func() -> void: slot_activated.emit(index))

func bind_slot(
	p_index: int,
	die: DieState,
	die_scene: PackedScene,
	p_selected_die_id: StringName,
	engraving_catalog: EngravingCatalog = null,
	position_hint: String = "",
	effective_value: int = -1,
	diagnostics: Dictionary = {},
	locked: bool = false
) -> void:
	index = p_index
	selected_die_id = p_selected_die_id
	die_id = &"" if die == null else die.id
	var index_label := get_node_or_null("%SlotIndex") as Label
	if index_label != null:
		index_label.text = (
			position_hint
			if not position_hint.is_empty()
			else "位 %d" % (index + 1)
		)
	if index_label != null:
		index_label.text = _diagnostic_icon(diagnostics) + index_label.text
		if not diagnostics.is_empty():
			index_label.add_theme_color_override(
				"font_color",
				Color("8fffb8") if diagnostics.get("state") == &"pass" else Color("ff617a")
			)
	for child in get_children():
		if child is DieToken:
			child.queue_free()
	if die == null:
		text = "＋"
		tooltip_text = "骰位 %d：空" % (index + 1)
		return
	text = ""
	tooltip_text = "骰位 %d：骰子 %s" % [index + 1, die.id]
	tooltip_text += "；右键放回骰盘"
	var token: DieToken = die_scene.instantiate()
	token.custom_minimum_size = Vector2(60, 60)
	add_child(token)
	token.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	token.bind_die_with_engravings(
		die,
		die.id == selected_die_id,
		engraving_catalog,
		true,
		effective_value,
		locked
	)
	token.tooltip_text += "\n右键放回骰盘"
	token.die_activated.connect(_on_die_activated)
	token.die_drop_requested.connect(
		func(dropped_die_id: StringName) -> void:
			die_drop_requested.emit(dropped_die_id, index)
	)
	token.gui_input.connect(_on_assigned_die_gui_input.bind(die.id))
	if not diagnostics.is_empty():
		var target_value: Variant = diagnostics.get("target")
		if target_value != null:
			tooltip_text += "\n槽位目标：%s｜实际：%s" % [target_value, diagnostics.get("value")]

func _diagnostic_icon(diagnostics: Dictionary) -> String:
	if diagnostics.is_empty():
		return "◇ "
	var relation: StringName = diagnostics.get("relation", &"")
	var arrow: String = {
		&"up": "↑",
		&"down": "↓",
		&"mirror": "↔",
		&"exact": "◎",
	}.get(relation, "")
	var state_icon := "✓" if diagnostics.get("state") == &"pass" else "×"
	return "%s%s " % [arrow, state_icon]

func _on_die_activated(activated_die_id: StringName) -> void:
	if selected_die_id != &"" and selected_die_id != activated_die_id:
		slot_activated.emit(index)
	else:
		die_activated.emit(activated_die_id)

func _on_assigned_die_gui_input(
	event: InputEvent,
	assigned_die_id: StringName
) -> void:
	if (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_RIGHT
		and event.pressed
	):
		die_return_requested.emit(assigned_die_id)
		get_viewport().set_input_as_handled()

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.get("kind") == "die"

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	die_drop_requested.emit(data.get("die_id"), index)
