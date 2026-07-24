class_name DieState
extends RefCounted

var id: StringName
var value: int
var engraving_id: StringName

func _init(p_id: StringName, p_value: int, p_engraving_id: StringName = &"") -> void:
	id = p_id
	value = p_value
	engraving_id = p_engraving_id

func clone() -> DieState:
	return DieState.new(id, value, engraving_id)
