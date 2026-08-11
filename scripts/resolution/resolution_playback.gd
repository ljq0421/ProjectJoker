class_name ResolutionPlayback
extends RefCounted

const PlaybackStep = preload("res://scripts/resolution/resolution_playback_step.gd")

signal event_revealed(event: ResolutionEvent, index: int)
signal step_revealed(step: RefCounted, index: int)
signal completed(report: ResolutionReport)

const NORMAL_EVENT_SECONDS := 0.42
const FAST_EVENT_SECONDS := 0.14
const NORMAL_DURATION_CAP := 2.2
const FAST_DURATION_CAP := 1.0

var _report: ResolutionReport
var _steps: Array = []
var _speed_mode: StringName = &"normal"
var _revealed_count := 0
var _revealed_step_count := 0
var _elapsed := 0.0
var _temporary_boost := false
var _paused := false
var _is_complete := false
var _finishing_now := false

func start(report: ResolutionReport, speed_mode: StringName = &"normal") -> void:
	_report = report
	_steps = build_steps(report)
	_speed_mode = speed_mode if speed_mode in [&"normal", &"fast", &"instant"] else &"normal"
	_revealed_count = 0
	_revealed_step_count = 0
	_elapsed = 0.0
	_temporary_boost = false
	_paused = false
	_is_complete = false
	_finishing_now = false
	if _report == null or _steps.is_empty():
		_complete_once()
		return
	if _speed_mode == &"instant":
		finish_now()

func advance(delta: float) -> void:
	if _is_complete or _paused or _report == null:
		return
	_elapsed += maxf(delta, 0.0)
	var interval := _step_interval()
	while _elapsed + 0.000001 >= interval and not _is_complete and not _paused:
		_elapsed -= interval
		_reveal_next_step()
		interval = _step_interval()

func set_temporary_boost(enabled: bool) -> void:
	_temporary_boost = enabled

func set_paused(enabled: bool) -> void:
	_paused = enabled and not _is_complete
	if not _paused and not _is_complete and _revealed_step_count >= _steps.size():
		_complete_once()

func is_paused() -> bool:
	return _paused

func finish_now() -> void:
	if _is_complete:
		return
	_paused = false
	_finishing_now = true
	if _report == null:
		_finishing_now = false
		_complete_once()
		return
	while _revealed_step_count < _steps.size():
		_reveal_next_step()
	_finishing_now = false
	_complete_once()

func is_finishing_now() -> bool:
	return _finishing_now

func revealed_count() -> int:
	return _revealed_count

func revealed_step_count() -> int:
	return _revealed_step_count

func is_complete() -> bool:
	return _is_complete

func final_total() -> int:
	return _report.total if _report != null else 0

func report() -> ResolutionReport:
	return _report

func speed_mode() -> StringName:
	return _speed_mode

func temporary_boost_enabled() -> bool:
	return _temporary_boost

func steps() -> Array:
	return _steps.duplicate()

func estimated_duration() -> float:
	if _speed_mode == &"instant":
		return 0.0
	return _step_interval(false) * _steps.size()

func build_steps(report: ResolutionReport) -> Array:
	var result: Array = []
	if report == null:
		return result
	for index in range(report.events.size()):
		var event: ResolutionEvent = report.events[index]
		var highlight_kind := _highlight_kind(event)
		var current = result.back() if not result.is_empty() else null
		if current == null or not _can_append(current, event, highlight_kind):
			current = PlaybackStep.new()
			current.highlight_kind = highlight_kind
			result.append(current)
		current.append_event(event, index)
	return result

func _step_interval(include_boost: bool = true) -> float:
	if _steps.is_empty():
		return 0.0
	var base := FAST_EVENT_SECONDS if _speed_mode == &"fast" else NORMAL_EVENT_SECONDS
	var cap := FAST_DURATION_CAP if _speed_mode == &"fast" else NORMAL_DURATION_CAP
	var interval := minf(base, cap / float(_steps.size()))
	if include_boost and _temporary_boost:
		interval *= 0.5
	return interval

func _reveal_next_step() -> void:
	if _report == null or _revealed_step_count >= _steps.size():
		_complete_once()
		return
	var step_index := _revealed_step_count
	var step: RefCounted = _steps[step_index]
	_revealed_step_count += 1
	step_revealed.emit(step, step_index)
	for local_index in range(step.events.size()):
		var original_index: int = int(step.original_indices[local_index])
		_revealed_count += 1
		event_revealed.emit(step.events[local_index], original_index)
	if _revealed_step_count >= _steps.size() and not _paused:
		_complete_once()

func _can_append(
	step,
	event: ResolutionEvent,
	highlight_kind: StringName
) -> bool:
	if step.is_rare_highlight() or highlight_kind != &"":
		return false
	var previous: ResolutionEvent = step.representative_event()
	if previous == null:
		return true
	if previous.source_id == event.source_id and event.source_id != &"":
		return true
	if previous.source_table_id != &"" and previous.source_table_id == event.source_table_id:
		return true
	return (
		previous.combo_kind != &""
		and previous.combo_kind == event.combo_kind
		and previous.target_table_id == event.source_table_id
	)

func _highlight_kind(event: ResolutionEvent) -> StringName:
	if event.combo_kind in [&"storm", &"resonance"]:
		return event.combo_kind
	if event.source_id == &"full_table_critical":
		return &"lucky"
	if String(event.source_id).begins_with("engraving_set_"):
		return &"engraving_set"
	if event.combo_kind in [&"dealer_complete", &"achievement"]:
		return event.combo_kind
	return &""

func _complete_once() -> void:
	if _is_complete:
		return
	_is_complete = true
	_paused = false
	completed.emit(_report)
