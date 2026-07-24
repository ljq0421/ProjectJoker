class_name ActionResult
extends RefCounted

var accepted: bool
var reason: String
var next_state: RoundState

func _init(p_accepted: bool, p_reason: String, p_next_state: RoundState) -> void:
	accepted = p_accepted
	reason = p_reason
	next_state = p_next_state
