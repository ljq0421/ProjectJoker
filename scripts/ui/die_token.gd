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

func bind_die_with_engravings(
	state: DieState,
	selected: bool,
	catalog: EngravingCatalog = null,
	assigned: bool = false
) -> void:
	bind_die(state, selected)
	var engraving := (
		catalog.find_engraving(state.engraving_id)
		if catalog != null and state.engraving_id != &""
		else null
	)
	if engraving == null:
		return
	var face_hit := state.rolled_value == state.engraved_face
	var active := assigned and face_hit
	var value_copy := (
		str(state.value)
		if state.value == state.rolled_value
		else "%d（原 %d）" % [state.value, state.rolled_value]
	)
	text = "%s\n%s · %d 面\n%s" % [
		value_copy,
		engraving.display_name,
		state.engraved_face,
		"本轮激活" if active else ("刻印面命中" if face_hit else "未激活"),
	]
	tooltip_text = "骰子 %s：原始 %d，有效 %d；%s" % [
		state.id,
		state.rolled_value,
		state.value,
		engraving.rule_text,
	]

func set_legal_target(value: bool) -> void:
	self_modulate = Color(0.68, 1.0, 0.96, 1.0) if value else Color.WHITE

func set_target_state(active: bool, legal: bool) -> void:
	if not active:
		self_modulate = Color.WHITE
	elif legal:
		self_modulate = Color(0.68, 1.0, 0.96, 1.0)
	else:
		self_modulate = Color(0.48, 0.48, 0.58, 0.58)

func _get_drag_data(_at_position: Vector2) -> Variant:
	var preview := Label.new()
	preview.text = text
	preview.add_theme_font_size_override("font_size", 28)
	set_drag_preview(preview)
	return {"kind": "die", "die_id": die_id}
