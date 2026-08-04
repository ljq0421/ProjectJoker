class_name DiceFirstDieToken
extends Button

signal die_activated(die_id: StringName)

const CYAN := Color(0.55, 1.0, 0.94, 1.0)
const VIOLET := Color(0.9, 0.66, 1.0, 1.0)
const GOLD := Color(1.0, 0.78, 0.34, 1.0)
const MUTED := Color(0.52, 0.62, 0.72, 1.0)

@onready var value_label: Label = %ValueLabel
@onready var status_label: Label = %StatusLabel

var die_id: StringName = &""
var die_value := 0
var _motion_reduced := false

func _ready() -> void:
	pressed.connect(func() -> void: die_activated.emit(die_id))
	pivot_offset = size * 0.5

func bind_die(
	p_die_id: StringName,
	value: int,
	selected: bool,
	resonant: bool,
	assignment_copy: String,
	risk_selected: bool
) -> void:
	die_id = p_die_id
	die_value = value
	value_label.text = str(value) if value > 0 else "?"
	status_label.text = (
		"重投 −2分/−1能量" if risk_selected
		else assignment_copy if not assignment_copy.is_empty()
		else "组合中" if resonant
		else "基础分"
	)
	self_modulate = (
		GOLD if risk_selected
		else CYAN if selected
		else VIOLET if resonant
		else MUTED if not assignment_copy.is_empty()
		else Color.WHITE
	)
	set_meta("resonant", resonant)
	set_meta("risk_selected", risk_selected)
	set_meta("assignment_copy", assignment_copy)
	tooltip_text = "%s · 当前点数 %d%s" % [
		String(die_id).to_upper(),
		value,
		" · 已形成骰子组合" if resonant else "",
	]

func set_motion_reduced(value: bool) -> void:
	_motion_reduced = value

func play_roll_feedback(delay: float = 0.0) -> void:
	if _motion_reduced or not is_inside_tree():
		return
	pivot_offset = size * 0.5
	rotation = -0.12
	scale = Vector2(0.78, 0.78)
	modulate.a = 0.45
	var tween := create_tween()
	tween.tween_interval(delay)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.12, 1.12), 0.18)
	tween.parallel().tween_property(self, "rotation", 0.08, 0.18)
	tween.parallel().tween_property(self, "modulate:a", 1.0, 0.12)
	tween.tween_property(self, "scale", Vector2.ONE, 0.12)
	tween.parallel().tween_property(self, "rotation", 0.0, 0.12)

func play_resonance_feedback() -> void:
	if _motion_reduced or not is_inside_tree():
		return
	pivot_offset = size * 0.5
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.12)
	tween.tween_property(self, "scale", Vector2.ONE, 0.18)
