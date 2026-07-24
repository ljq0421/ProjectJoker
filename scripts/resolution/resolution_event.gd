class_name ResolutionEvent
extends RefCounted

var source_id: StringName
var label: String
var delta: int
var running_total: int

func _init(
	p_source_id: StringName,
	p_label: String,
	p_delta: int,
	p_running_total: int
) -> void:
	source_id = p_source_id
	label = p_label
	delta = p_delta
	running_total = p_running_total
