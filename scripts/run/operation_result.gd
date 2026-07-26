class_name OperationResult
extends RefCounted

var accepted: bool
var reason: String

func _init(p_accepted: bool, p_reason: String = "") -> void:
	accepted = p_accepted
	reason = p_reason
