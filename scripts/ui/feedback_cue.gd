class_name FeedbackCue
extends RefCounted

enum Priority {
	AMBIENT_STATE,
	OPERATION_CONFIRMATION,
	FORMAL_RESOLUTION,
	RARE_HIGHLIGHT,
}

var kind: StringName = &""
var source: Node
var target: Node
var delta := 0
var tone: StringName = &"neutral"
var priority: Priority = Priority.AMBIENT_STATE
var exclusive := false
var copy: String = ""
var payload: Dictionary = {}

func _init(
	p_kind: StringName = &"",
	p_source: Node = null,
	p_target: Node = null,
	p_delta: int = 0,
	p_tone: StringName = &"neutral",
	p_priority: Priority = Priority.AMBIENT_STATE,
	p_exclusive: bool = false,
	p_copy: String = "",
	p_payload: Dictionary = {}
) -> void:
	kind = p_kind
	source = p_source
	target = p_target
	delta = p_delta
	tone = p_tone
	priority = p_priority
	exclusive = p_exclusive
	copy = p_copy
	payload = p_payload.duplicate(true)
