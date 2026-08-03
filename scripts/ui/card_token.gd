class_name CardToken
extends Button

const Formatter = preload("res://scripts/ui/card_display_formatter.gd")

const REST_SCALE := Vector2.ONE
const HOVER_SCALE := Vector2(1.035, 1.035)
const SELECTED_SCALE := Vector2(1.055, 1.055)
const PRESSED_SCALE := Vector2(0.965, 0.965)
const GLASS_HIGHLIGHT := Color(1.08, 1.12, 1.16, 1.0)
const MOTION_SECONDS := 0.12

signal card_activated(card_index: int)

var card_index: int
var _motion_reduced := false
var _hovered := false
var _selected := false
var _pressed := false
var _motion_tween: Tween

func _ready() -> void:
	pressed.connect(func() -> void: card_activated.emit(card_index))
	mouse_entered.connect(_on_hover_changed.bind(true))
	mouse_exited.connect(_on_hover_changed.bind(false))
	focus_entered.connect(_on_hover_changed.bind(true))
	focus_exited.connect(_on_hover_changed.bind(false))
	button_down.connect(_on_pressed_changed.bind(true))
	button_up.connect(_on_pressed_changed.bind(false))
	_update_pivot()

func bind_card(
	index: int,
	definition: CardDefinition,
	selected: bool,
	used: bool,
	_selection_step: String = "",
	disabled_reason: String = ""
) -> void:
	card_index = index
	var selection_changed := _selected != selected
	var formatter := Formatter.new()
	var face := get_node_or_null("CardFaceContent")
	if face != null:
		text = ""
		icon = null
		face.bind_card(definition)
	else:
		text = formatter.compact_copy(definition)
		icon = load(formatter.effect_icon_path(definition))
	button_pressed = selected
	_selected = selected
	disabled = used or not disabled_reason.is_empty()
	if face != null:
		face.set_interaction_state(selected, disabled)
	tooltip_text = "%s · %s · %s · %s；目标：%s；%s" % [
		definition.suit_copy(),
		definition.rank_label,
		definition.rarity_copy(),
		definition.display_name,
		target_copy_for(definition),
		definition.rule_text,
	]
	if not disabled_reason.is_empty():
		tooltip_text += "；当前不可用：%s" % disabled_reason
	_apply_motion_state(selection_changed)

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

func play_commit_feedback() -> void:
	set_meta("last_motion_beat", &"card_commit")
	if _motion_reduced or not is_inside_tree():
		return
	_stop_motion()
	_update_pivot()
	_motion_tween = create_tween()
	_motion_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_motion_tween.tween_property(self, "scale", Vector2(0.94, 1.06), 0.07)
	_motion_tween.parallel().tween_property(self, "modulate", GLASS_HIGHLIGHT, 0.07)
	_motion_tween.tween_property(self, "scale", SELECTED_SCALE, 0.14).set_trans(
		Tween.TRANS_BACK
	)
	_motion_tween.parallel().tween_property(self, "modulate", Color.WHITE, 0.14)

func target_copy_for(definition: CardDefinition) -> String:
	return Formatter.new().target_copy_for(definition)

func _target_copy(target_type: CardDefinition.TargetType) -> String:
	return Formatter.new().target_copy(target_type)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_pivot()

func _on_hover_changed(value: bool) -> void:
	_hovered = value
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
	elif _hovered and not disabled:
		target_scale = HOVER_SCALE
	var target_rotation := 0.0
	if (_hovered or _selected) and not disabled:
		target_rotation = 0.012 if card_index % 2 == 0 else -0.012
	if not animated or not is_inside_tree():
		scale = target_scale
		rotation = target_rotation
		return
	_stop_motion()
	_update_pivot()
	_motion_tween = create_tween().set_parallel(true)
	_motion_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_motion_tween.tween_property(self, "scale", target_scale, MOTION_SECONDS)
	_motion_tween.tween_property(self, "rotation", target_rotation, MOTION_SECONDS)

func _stop_motion() -> void:
	if _motion_tween != null and _motion_tween.is_valid():
		_motion_tween.kill()
	_motion_tween = null

func _update_pivot() -> void:
	pivot_offset = size * 0.5
