extends "res://tests/test_case.gd"

const PLAYBACK_SCRIPT = preload(
	"res://scripts/resolution/resolution_playback.gd"
)

func run() -> void:
	assert_true(
		ResourceLoader.exists("res://scripts/resolution/resolution_playback.gd"),
		"resolution playback model should exist"
	)
	if failures.size() > 0:
		return
	_test_order_and_single_completion()
	_test_fast_boost_and_skip_share_final_state()
	_test_instant_mode_finishes_without_recalculation()

func _test_order_and_single_completion() -> void:
	var report := _fixture_report()
	var playback = PLAYBACK_SCRIPT.new()
	var revealed: Array[StringName] = []
	var completion_count := [0]
	playback.event_revealed.connect(
		func(event: ResolutionEvent, _index: int) -> void:
			revealed.append(event.source_id)
	)
	playback.completed.connect(
		func(completed_report: ResolutionReport) -> void:
			assert_true(
				completed_report == report,
				"playback should complete with the original report instance"
			)
			completion_count[0] += 1
	)
	playback.start(report, &"normal")
	assert_equal(playback.revealed_count(), 0, "normal playback should start empty")
	playback.advance(PLAYBACK_SCRIPT.NORMAL_EVENT_SECONDS)
	assert_equal(revealed, [&"left"], "first event should reveal first")
	playback.advance(PLAYBACK_SCRIPT.NORMAL_EVENT_SECONDS * 2.0)
	assert_equal(
		revealed,
		[&"left", &"bridge", &"dealer"],
		"large advances should preserve report order"
	)
	assert_true(playback.is_complete(), "last event should complete playback")
	assert_equal(completion_count[0], 1, "completion should emit exactly once")
	playback.advance(10.0)
	playback.finish_now()
	assert_equal(completion_count[0], 1, "completed playback should remain idempotent")

func _test_fast_boost_and_skip_share_final_state() -> void:
	var fast = PLAYBACK_SCRIPT.new()
	fast.start(_fixture_report(), &"fast")
	fast.advance(PLAYBACK_SCRIPT.FAST_EVENT_SECONDS)
	assert_equal(fast.revealed_count(), 1, "fast mode should use its shorter interval")
	fast.set_temporary_boost(true)
	fast.advance(PLAYBACK_SCRIPT.FAST_EVENT_SECONDS * 0.5)
	assert_equal(
		fast.revealed_count(),
		2,
		"temporary boost should halve the current event interval"
	)
	fast.finish_now()
	assert_equal(fast.revealed_count(), 3, "skip should reveal every remaining event")
	assert_equal(fast.final_total(), 12, "skip should retain the report total")

func _test_instant_mode_finishes_without_recalculation() -> void:
	var report := _fixture_report()
	var signatures_before := report.event_signature()
	var playback = PLAYBACK_SCRIPT.new()
	var revealed: Array[StringName] = []
	playback.event_revealed.connect(
		func(event: ResolutionEvent, _index: int) -> void:
			revealed.append(event.source_id)
	)
	playback.start(report, &"instant")
	assert_true(playback.is_complete(), "instant mode should finish during start")
	assert_equal(
		revealed,
		[&"left", &"bridge", &"dealer"],
		"instant mode should still reveal events in report order"
	)
	assert_equal(
		report.event_signature(),
		signatures_before,
		"playback must not mutate or regenerate resolution events"
	)

func _fixture_report() -> ResolutionReport:
	var report := ResolutionReport.new()
	report.events = [
		ResolutionEvent.new(&"left", "左侧规则台", 8, 8),
		ResolutionEvent.new(&"bridge", "桥接手法", 4, 12),
		ResolutionEvent.new(&"dealer", "庄家规则未触发", 0, 12, false),
	]
	report.total = 12
	return report
