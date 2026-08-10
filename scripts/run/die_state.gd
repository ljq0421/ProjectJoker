class_name DieState
extends RefCounted

var id: StringName
var rolled_value: int
var value: int
var engraving_id: StringName
var engraved_face: int
var faulted := false

func _init(
	p_id: StringName,
	p_value: int,
	p_engraving_id: StringName = &"",
	p_engraved_face: int = 0,
	p_rolled_value: int = 0,
	p_faulted: bool = false
) -> void:
	id = p_id
	value = p_value
	rolled_value = p_value if p_rolled_value == 0 else p_rolled_value
	engraving_id = p_engraving_id
	engraved_face = p_engraved_face
	faulted = p_faulted

func clone() -> DieState:
	return DieState.new(id, value, engraving_id, engraved_face, rolled_value, faulted)
