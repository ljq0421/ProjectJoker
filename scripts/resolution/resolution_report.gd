class_name ResolutionReport
extends RefCounted

var valid: bool = true
var reason: String = ""
var total: int = 0
var events: Array[ResolutionEvent] = []

func event_signature() -> Array[String]:
	var signature: Array[String] = []
	for event in events:
		signature.append("%s|%s|%d|%d" % [
			event.source_id,
			event.label,
			event.delta,
			event.running_total,
		])
	return signature
