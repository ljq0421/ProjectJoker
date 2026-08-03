class_name RuleLane
extends PanelContainer

signal lane_activated(table_id: StringName)
signal slot_activated(table_id: StringName, slot_index: int)
signal die_activated(die_id: StringName)
signal die_return_requested(die_id: StringName)
signal die_drop_requested(die_id: StringName, table_id: StringName)
signal die_drop_to_slot_requested(
	die_id: StringName,
	table_id: StringName,
	slot_index: int
)

const SLOT_SCENE = preload("res://scenes/components/rule_slot.tscn")
const RuleCopy = preload("res://scripts/ui/rule_copy_formatter.gd")

@onready var title_label: Label = %Title
@onready var formula_label: Label = %Formula
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
	condition_summary: String = "",
	effective_die_values: Dictionary = {},
	effective_coefficient: int = -1,
	resolution_count: int = 1
) -> void:
	table_id = rule.id
	title_label.text = rule.display_name
	formula_label.text = rule_formula_copy(rule)
	var slot_count := (
		rule.slot_count
		if effective_slot_count < 0
		else effective_slot_count
	)
	condition_label.text = effective_rule_copy(
		slot_count,
		rule.coefficient,
		effective_coefficient,
		resolution_count
	)
	if not condition_summary.is_empty():
		condition_label.text += "\n条件变化：%s" % condition_summary
	tooltip_text = _rule_detail_copy(rule)
	for child in slots.get_children():
		child.queue_free()
	for slot_index in range(slot_count):
		var slot: RuleSlot = SLOT_SCENE.instantiate()
		slots.add_child(slot)
		var die: DieState = (
			assigned_dice[slot_index]
			if slot_index < assigned_dice.size()
			else null
		)
		slot.bind_slot(
			slot_index,
			die,
			die_scene,
			selected_die_id,
			engraving_catalog,
			_position_hint(rule, slot_index),
			(
				int(effective_die_values.get(die.id, die.value))
				if die != null
				else -1
			)
		)
		slot.slot_activated.connect(
			func(index: int) -> void:
				slot_activated.emit(table_id, index)
		)
		slot.die_activated.connect(
			func(id: StringName) -> void:
				die_activated.emit(id)
		)
		slot.die_return_requested.connect(
			func(id: StringName) -> void:
				die_return_requested.emit(id)
		)
		slot.die_drop_requested.connect(
			func(id: StringName, index: int) -> void:
				die_drop_to_slot_requested.emit(id, table_id, index)
		)

func set_legal_target(value: bool) -> void:
	self_modulate = Color(0.68, 1.0, 0.96, 1.0) if value else Color.WHITE

func effective_rule_copy(
	slot_count: int,
	base_coefficient: int,
	effective_coefficient: int = -1,
	p_resolution_count: int = 1
) -> String:
	var displayed_coefficient := (
		base_coefficient
		if effective_coefficient < 1
		else effective_coefficient
	)
	var copy := "%d 个骰位 · 系数 ×%d" % [slot_count, base_coefficient]
	if displayed_coefficient != base_coefficient:
		copy += " → ×%d" % displayed_coefficient
	if p_resolution_count > 1:
		copy += " · 结算 %d 次" % p_resolution_count
	return copy

func rule_formula_copy(rule: RuleDefinition) -> String:
	return RuleCopy.formula(rule)

func _distortion_formula(effect: RuleTableTemplate.PostPassEffect) -> String:
	return RuleCopy.distortion_formula(effect)

func _rule_detail_copy(rule: RuleDefinition) -> String:
	var detail := "%s；%s" % [rule.display_name, rule_formula_copy(rule)]
	if rule.template != null and not rule.template.description.is_empty():
		detail += "；%s" % rule.template.description
	return detail

func set_target_state(active: bool, legal: bool) -> void:
	if not active:
		self_modulate = Color.WHITE
	elif legal:
		self_modulate = Color(0.68, 1.0, 0.96, 1.0)
	else:
		self_modulate = Color(0.48, 0.48, 0.58, 0.58)

func set_die_target_highlight(value: bool) -> void:
	for child in slots.get_children():
		if child is RuleSlot:
			for nested in child.get_children():
				if nested is DieToken:
					nested.set_legal_target(value)

func set_die_card_target_state(
	active: bool,
	legal_target: Callable
) -> void:
	for child in slots.get_children():
		if child is RuleSlot:
			for nested in child.get_children():
				if nested is DieToken:
					nested.set_target_state(
						active,
						legal_target.call(nested.die_id) if active else false
					)

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.get("kind") == "die"

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	die_drop_requested.emit(data.get("die_id"), table_id)

func _position_hint(rule: RuleDefinition, slot_index: int) -> String:
	var hint := "位 %d" % (slot_index + 1)
	if (
		rule.template != null
		and rule.template.condition_kind
			== RuleTableTemplate.ConditionKind.SLOT_TARGETS
		and slot_index < rule.slot_targets.size()
	):
		hint += " = %d" % rule.slot_targets[slot_index]
	return hint
