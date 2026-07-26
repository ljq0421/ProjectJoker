class_name EngravingOutcome
extends RefCounted

var source_id: StringName
var label: String
var delta: int
var target_table_id: StringName
var effect_applied: bool

func _init(
	p_source_id: StringName,
	p_label: String,
	p_delta: int,
	p_target_table_id: StringName = &"",
	p_effect_applied: bool = true
) -> void:
	source_id = p_source_id
	label = p_label
	delta = p_delta
	target_table_id = p_target_table_id
	effect_applied = p_effect_applied
