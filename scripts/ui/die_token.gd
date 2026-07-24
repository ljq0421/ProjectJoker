class_name DieToken
extends Button

signal die_activated(die_id: StringName)

var die_id: StringName

func _ready() -> void:
	pressed.connect(func() -> void: die_activated.emit(die_id))

func bind_die(state: DieState, selected: bool) -> void:
	die_id = state.id
	text = str(state.value)
	button_pressed = selected
	tooltip_text = "骰子 %s：点数 %d" % [state.id, state.value]

func set_legal_target(value: bool) -> void:
	self_modulate = Color(0.68, 1.0, 0.96, 1.0) if value else Color.WHITE

func _get_drag_data(_at_position: Vector2) -> Variant:
	var preview := Label.new()
	preview.text = text
	preview.add_theme_font_size_override("font_size", 28)
	set_drag_preview(preview)
	return {"kind": "die", "die_id": die_id}
