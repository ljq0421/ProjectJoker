class_name RuleResult
extends RefCounted

var valid: bool
var base_sum: int
var total: int
var reason: String

func _init(
	p_valid: bool,
	p_base_sum: int,
	p_total: int,
	p_reason: String = ""
) -> void:
	valid = p_valid
	base_sum = p_base_sum
	total = p_total
	reason = p_reason
