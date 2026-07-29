class_name RuleSlot
extends Button

signal slot_activated(slot_index: int)
signal die_activated(die_id: StringName)
signal die_drop_requested(die_id: StringName, slot_index: int)

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
	position_hint: String = ""
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
	for child in get_children():
		if child is DieToken:
			child.queue_free()
	if die == null:
		text = "＋"
		tooltip_text = "骰位 %d：空" % (index + 1)
		return
	text = ""
	tooltip_text = "骰位 %d：骰子 %s" % [index + 1, die.id]
	var token: DieToken = die_scene.instantiate()
	token.custom_minimum_size = Vector2(54, 54)
	token.position = Vector2(5, 24)
	add_child(token)
	token.bind_die_with_engravings(
		die,
		die.id == selected_die_id,
		engraving_catalog,
		true
	)
	token.die_activated.connect(_on_die_activated)

func _on_die_activated(activated_die_id: StringName) -> void:
	if selected_die_id != &"" and selected_die_id != activated_die_id:
		slot_activated.emit(index)
	else:
		die_activated.emit(activated_die_id)

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.get("kind") == "die"

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	die_drop_requested.emit(data.get("die_id"), index)
