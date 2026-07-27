class_name MirrorCopyResult
extends RefCounted

var accepted: bool
var generated: bool
var copy: PlayedCard
var reason: String

func _init(
	p_accepted: bool,
	p_generated: bool = false,
	p_copy: PlayedCard = null,
	p_reason: String = ""
) -> void:
	accepted = p_accepted
	generated = p_generated
	copy = p_copy
	reason = p_reason
