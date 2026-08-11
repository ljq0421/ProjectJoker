class_name ResolutionPlaybackStep
extends RefCounted

var original_indices: Array[int] = []
var events: Array[ResolutionEvent] = []
var delta := 0
var running_total := 0
var label: String = ""
var score_source: ResolutionEvent.ScoreSource = ResolutionEvent.ScoreSource.BASE
var highlight_kind: StringName = &""

func append_event(event: ResolutionEvent, original_index: int) -> void:
	if events.is_empty():
		label = event.label
		score_source = event.score_source
	events.append(event)
	original_indices.append(original_index)
	delta += event.delta
	running_total = event.running_total

func representative_event() -> ResolutionEvent:
	return events.back() if not events.is_empty() else null

func is_rare_highlight() -> bool:
	return highlight_kind != &""
