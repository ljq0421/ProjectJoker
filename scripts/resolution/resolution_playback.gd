class_name ResolutionPlayback
extends RefCounted

signal event_revealed(event: ResolutionEvent, index: int)
signal completed(report: ResolutionReport)

const NORMAL_EVENT_SECONDS := 0.42
const FAST_EVENT_SECONDS := 0.14

var _report: ResolutionReport
var _speed_mode: StringName = &"normal"
var _revealed_count := 0
var _elapsed := 0.0
var _temporary_boost := false
var _is_complete := false

func start(report: ResolutionReport, speed_mode: StringName = &"normal") -> void:
	_report = report
	_speed_mode = (
		speed_mode
		if speed_mode in [&"normal", &"fast", &"instant"]
		else &"normal"
	)
	_revealed_count = 0
	_elapsed = 0.0
	_temporary_boost = false
	_is_complete = false
	if _report == null or _report.events.is_empty():
		_complete_once()
		return
	if _speed_mode == &"instant":
		finish_now()

func advance(delta: float) -> void:
	if _is_complete or _report == null:
		return
	_elapsed += maxf(delta, 0.0)
	var interval := _event_interval()
	while _elapsed + 0.000001 >= interval and not _is_complete:
		_elapsed -= interval
		_reveal_next()
		interval = _event_interval()

func set_temporary_boost(enabled: bool) -> void:
	_temporary_boost = enabled

func finish_now() -> void:
	if _is_complete:
		return
	if _report == null:
		_complete_once()
		return
	while _revealed_count < _report.events.size():
		_reveal_next()
	_complete_once()

func revealed_count() -> int:
	return _revealed_count

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

func _event_interval() -> float:
	var interval := (
		FAST_EVENT_SECONDS
		if _speed_mode == &"fast"
		else NORMAL_EVENT_SECONDS
	)
	return interval * (0.5 if _temporary_boost else 1.0)

func _reveal_next() -> void:
	if _report == null or _revealed_count >= _report.events.size():
		_complete_once()
		return
	var index := _revealed_count
	var event: ResolutionEvent = _report.events[index]
	_revealed_count += 1
	event_revealed.emit(event, index)
	if _revealed_count >= _report.events.size():
		_complete_once()

func _complete_once() -> void:
	if _is_complete:
		return
	_is_complete = true
	completed.emit(_report)
