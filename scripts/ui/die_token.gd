class_name DieToken
extends Button

signal die_activated(die_id: StringName)
signal die_drop_requested(die_id: StringName)

const FACE_ICON_ROOT := "res://resources/ui/dream_glass/icons/dice/"
const REST_SCALE := Vector2.ONE
const HOVER_SCALE := Vector2(1.08, 1.08)
const SELECTED_SCALE := Vector2(1.12, 1.12)
const PRESSED_SCALE := Vector2(0.9, 0.9)
const LANDING_SCALE := Vector2(1.1, 1.1)
const RETURN_SCALE := Vector2(0.9, 0.9)
const MOTION_SECONDS := 0.1
const RULE_PASSED_TINT := Color(0.56, 1.0, 0.72, 1.0)
const RULE_FAILED_TINT := Color(1.0, 0.38, 0.48, 1.0)
const TARGET_TINT := Color(0.68, 1.0, 0.96, 1.0)
const ILLEGAL_TINT := Color(0.48, 0.48, 0.58, 0.58)
const ENGRAVING_MISS_COLOR := Color(0.68, 0.66, 0.76, 1.0)
const ENGRAVING_HIT_COLOR := Color(0.72, 1.0, 0.86, 1.0)
const ENGRAVING_ACTIVE_COLOR := Color(0.92, 0.72, 1.0, 1.0)

enum EvaluationState { NEUTRAL, PASSED, FAILED }
enum EngravingState { NONE, UNHIT, HIT, ACTIVE }

var die_id: StringName
var _motion_reduced := false
var _hovered := false
var _selected := false
var _pressed := false
var _accept_die_drops := false
var _motion_tween: Tween
var _evaluation_state := EvaluationState.NEUTRAL
var _target_active := false
var _target_legal := false
var _engraving_state := EngravingState.NONE

func _ready() -> void:
	pressed.connect(func() -> void: die_activated.emit(die_id))
	toggled.connect(func(_pressed: bool) -> void: _refresh_face_cue())
	mouse_entered.connect(_on_hover_changed.bind(true))
	mouse_exited.connect(_on_hover_changed.bind(false))
	focus_entered.connect(_on_focus_changed.bind(true))
	focus_exited.connect(_on_focus_changed.bind(false))
	button_down.connect(_on_pressed_changed.bind(true))
	button_up.connect(_on_pressed_changed.bind(false))
	_update_pivot()

func bind_die(
	state: DieState,
	selected: bool,
	effective_value: int = -1
) -> void:
	die_id = state.id
	_accept_die_drops = false
	_evaluation_state = EvaluationState.NEUTRAL
	_target_active = false
	_target_legal = false
	_engraving_state = EngravingState.NONE
	var selection_changed := _selected != selected
	var displayed_effective := (
		state.value if effective_value < 1 else effective_value
	)
	text = ""
	var icon_path := face_icon_path(displayed_effective)
	icon = null
	var face_icon := _face_icon()
	if face_icon != null:
		face_icon.texture = load(icon_path) if not icon_path.is_empty() else null
	var engraving_status := _engraving_status()
	if engraving_status != null:
		engraving_status.visible = false
		engraving_status.text = ""
	set_meta("engraving_state", EngravingState.NONE)
	button_pressed = selected
	_selected = selected
	_refresh_face_cue()
	_apply_semantic_tint()
	_apply_motion_state(selection_changed)
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
	_accept_die_drops = assigned
	var engraving := (
		catalog.find_engraving(state.engraving_id)
		if catalog != null and state.engraving_id != &""
		else null
	)
	if engraving == null:
		return
	var face_hit := state.rolled_value == state.engraved_face
	var displayed_effective := (
		state.value if effective_value < 1 else effective_value
	)
	_engraving_state = EngravingState.HIT if face_hit else EngravingState.UNHIT
	_apply_engraving_state()
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

func set_engraving_playback_active(value: bool) -> void:
	if _engraving_state == EngravingState.NONE:
		return
	if value and _engraving_state == EngravingState.HIT:
		_engraving_state = EngravingState.ACTIVE
	elif not value and _engraving_state == EngravingState.ACTIVE:
		_engraving_state = EngravingState.HIT
	_apply_engraving_state()

func _apply_engraving_state() -> void:
	var engraving_status := _engraving_status()
	if engraving_status == null:
		return
	engraving_status.visible = _engraving_state != EngravingState.NONE
	engraving_status.text = {
		EngravingState.UNHIT: "未命中",
		EngravingState.HIT: "命中",
		EngravingState.ACTIVE: "激活",
	}.get(_engraving_state, "")
	engraving_status.add_theme_color_override(
		"font_color",
		{
			EngravingState.UNHIT: ENGRAVING_MISS_COLOR,
			EngravingState.HIT: ENGRAVING_HIT_COLOR,
			EngravingState.ACTIVE: ENGRAVING_ACTIVE_COLOR,
		}.get(_engraving_state, ENGRAVING_MISS_COLOR)
	)
	set_meta("engraving_state", _engraving_state)

func set_legal_target(value: bool) -> void:
	self_modulate = TARGET_TINT if value else Color.WHITE

func set_rule_evaluation_state(value: int) -> void:
	_evaluation_state = value
	_apply_semantic_tint()

func set_motion_reduced(value: bool) -> void:
	_motion_reduced = value
	set_meta("motion_reduced", value)
	if value:
		_stop_motion()
		scale = REST_SCALE
		rotation = 0.0
		modulate = Color.WHITE
	else:
		_apply_motion_state(false)

func play_landing_feedback() -> void:
	set_meta("last_motion_beat", &"die_land")
	if _motion_reduced or not is_inside_tree():
		return
	_stop_motion()
	_update_pivot()
	scale = LANDING_SCALE
	rotation = 0.035 if String(die_id).hash() % 2 == 0 else -0.035
	_motion_tween = create_tween().set_parallel(true)
	_motion_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_motion_tween.tween_property(self, "scale", REST_SCALE, 0.18)
	_motion_tween.tween_property(self, "rotation", 0.0, 0.16)

func play_return_feedback() -> void:
	set_meta("last_motion_beat", &"die_return")
	if _motion_reduced or not is_inside_tree():
		return
	_stop_motion()
	_update_pivot()
	scale = RETURN_SCALE
	_motion_tween = create_tween()
	_motion_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_motion_tween.tween_property(self, "scale", REST_SCALE, 0.2)

func set_target_state(active: bool, legal: bool) -> void:
	_target_active = active
	_target_legal = legal
	_apply_semantic_tint()

func _apply_semantic_tint() -> void:
	if _target_active:
		self_modulate = TARGET_TINT if _target_legal else ILLEGAL_TINT
		return
	match _evaluation_state:
		EvaluationState.PASSED:
			self_modulate = RULE_PASSED_TINT
		EvaluationState.FAILED:
			self_modulate = RULE_FAILED_TINT
		_:
			self_modulate = Color.WHITE

func _get_drag_data(_at_position: Vector2) -> Variant:
	var preview := TextureRect.new()
	preview.custom_minimum_size = Vector2(54, 54)
	var face_icon := _face_icon()
	preview.texture = face_icon.texture if face_icon != null else null
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	set_drag_preview(preview)
	return {"kind": "die", "die_id": die_id}

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return (
		_accept_die_drops
		and data is Dictionary
		and data.get("kind") == "die"
	)

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	die_drop_requested.emit(data.get("die_id", &""))

func _face_icon() -> TextureRect:
	return get_node_or_null("%FaceIcon") as TextureRect

func _engraving_status() -> Label:
	return get_node_or_null("%EngravingStatus") as Label

func _refresh_face_cue() -> void:
	var face_icon := _face_icon()
	if face_icon == null:
		return
	face_icon.self_modulate = (
		Color(0.72, 1.0, 0.96, 1.0)
		if button_pressed or has_focus()
		else Color.WHITE
	)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_pivot()

func _on_hover_changed(value: bool) -> void:
	_hovered = value
	_apply_motion_state(true)

func _on_focus_changed(value: bool) -> void:
	_hovered = value
	_refresh_face_cue()
	_apply_motion_state(true)

func _on_pressed_changed(value: bool) -> void:
	_pressed = value
	_apply_motion_state(true)

func _apply_motion_state(animated: bool) -> void:
	if _motion_reduced:
		scale = REST_SCALE
		rotation = 0.0
		return
	var target_scale := REST_SCALE
	if _pressed:
		target_scale = PRESSED_SCALE
	elif _selected:
		target_scale = SELECTED_SCALE
	elif _hovered:
		target_scale = HOVER_SCALE
	if not animated or not is_inside_tree():
		scale = target_scale
		return
	_stop_motion()
	_update_pivot()
	_motion_tween = create_tween()
	_motion_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_motion_tween.tween_property(self, "scale", target_scale, MOTION_SECONDS)

func _stop_motion() -> void:
	if _motion_tween != null and _motion_tween.is_valid():
		_motion_tween.kill()
	_motion_tween = null

func _update_pivot() -> void:
	pivot_offset = size * 0.5
