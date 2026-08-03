class_name DieToken
extends Button

signal die_activated(die_id: StringName)

const FACE_ICON_ROOT := "res://resources/ui/dream_glass/icons/dice/"

var die_id: StringName

func _ready() -> void:
	pressed.connect(func() -> void: die_activated.emit(die_id))

func bind_die(
	state: DieState,
	selected: bool,
	effective_value: int = -1
) -> void:
	die_id = state.id
	var displayed_effective := (
		state.value if effective_value < 1 else effective_value
	)
	text = ""
	var icon_path := face_icon_path(displayed_effective)
	icon = load(icon_path) if not icon_path.is_empty() else null
	button_pressed = selected
	tooltip_text = (
		"骰子 %s：初始 %d，手法牌后 %d"
		% [state.id, state.value, displayed_effective]
		if displayed_effective != state.value
		else "骰子 %s：点数 %d" % [state.id, state.value]
	)

func face_icon_path(value: int) -> String:
	if value < 1 or value > 6:
		return ""
	return "%sdie_%d.svg" % [FACE_ICON_ROOT, value]

func bind_die_with_engravings(
	state: DieState,
	selected: bool,
	catalog: EngravingCatalog = null,
	assigned: bool = false,
	effective_value: int = -1
) -> void:
	bind_die(state, selected, effective_value)
	var engraving := (
		catalog.find_engraving(state.engraving_id)
		if catalog != null and state.engraving_id != &""
		else null
	)
	if engraving == null:
		return
	var face_hit := state.rolled_value == state.engraved_face
	var active := assigned and face_hit
	var displayed_effective := (
		state.value if effective_value < 1 else effective_value
	)
	text = "激活" if active else ("命中" if face_hit else "刻印")
	tooltip_text = (
		"骰子 %s：掷出 %d，初始 %d，手法牌后 %d；%s" % [
			state.id,
			state.rolled_value,
			state.value,
			displayed_effective,
			engraving.rule_text,
		]
		if displayed_effective != state.value
		else "骰子 %s：原始 %d，有效 %d；%s" % [
			state.id,
			state.rolled_value,
			state.value,
			engraving.rule_text,
		]
	)

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
	var preview := TextureRect.new()
	preview.custom_minimum_size = Vector2(68, 68)
	preview.texture = icon
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	set_drag_preview(preview)
	return {"kind": "die", "die_id": die_id}
