class_name ResolutionEvent
extends RefCounted

var source_id: StringName
var label: String
var delta: int
var running_total: int
var effect_applied: bool
var is_mirror_copy: bool
var source_card_id: StringName
var source_slot_id: StringName
var mirror_slot_id: StringName

func _init(
	p_source_id: StringName,
	p_label: String,
	p_delta: int,
	p_running_total: int,
	p_effect_applied: bool = true,
	p_is_mirror_copy: bool = false,
	p_source_card_id: StringName = &"",
	p_source_slot_id: StringName = &"",
	p_mirror_slot_id: StringName = &""
) -> void:
	source_id = p_source_id
	label = p_label
	delta = p_delta
	running_total = p_running_total
	effect_applied = p_effect_applied
	is_mirror_copy = p_is_mirror_copy
	source_card_id = p_source_card_id
	source_slot_id = p_source_slot_id
	mirror_slot_id = p_mirror_slot_id
