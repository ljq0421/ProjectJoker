extends "res://tests/test_case.gd"

const Playback = preload("res://scripts/resolution/resolution_playback.gd")
const Cue = preload("res://scripts/ui/feedback_cue.gd")
const MotionLayer = preload("res://scripts/ui/interaction_motion_layer.gd")
const SnapshotCodec = preload("res://scripts/run/run_snapshot_codec.gd")

func run() -> void:
	_test_playback_grouping_is_order_preserving_and_conservative()
	_test_rare_steps_are_isolated()
	_test_feedback_priority_queue()
	_test_diagnostics_stay_out_of_snapshots()
	_test_original_assets_are_registered()

func _test_playback_grouping_is_order_preserving_and_conservative() -> void:
	var report := ResolutionReport.new()
	report.events = [
		ResolutionEvent.new(&"left", "base", 4, 4),
		ResolutionEvent.new(&"left", "coefficient", 6, 10),
		ResolutionEvent.new(&"right", "other", 3, 13),
	]
	report.total = 13
	var signature := report.event_signature()
	var playback = Playback.new()
	playback.start(report, &"normal")
	var steps: Array = playback.steps()
	assert_equal(steps.size(), 2, "adjacent events from one source should form one step")
	assert_equal(steps[0].original_indices, [0, 1], "group should retain original event indices")
	assert_equal(steps[0].delta, 10, "group delta must equal the sum of its events")
	assert_true(playback.estimated_duration() <= Playback.NORMAL_DURATION_CAP, "normal playback should stay within its duration cap")
	playback.finish_now()
	assert_equal(report.event_signature(), signature, "playback grouping must not rewrite report events")

func _test_rare_steps_are_isolated() -> void:
	var report := ResolutionReport.new()
	report.events = [
		ResolutionEvent.new(&"left", "base", 4, 4),
		ResolutionEvent.new(&"bridge_storm", "storm", 20, 24, true, false, &"", &"", &"", ResolutionEvent.ScoreSource.RULE_CHAIN, &"", &"", &"storm"),
		ResolutionEvent.new(&"dealer", "dealer", 8, 32),
	]
	report.total = 32
	var playback = Playback.new()
	playback.start(report, &"fast")
	var steps: Array = playback.steps()
	assert_equal(steps.size(), 3, "rare highlights must remain independent steps")
	assert_equal(steps[1].highlight_kind, &"storm", "storm should retain its highlight semantic")
	assert_true(playback.estimated_duration() <= Playback.FAST_DURATION_CAP, "fast playback should stay within its duration cap")

func _test_feedback_priority_queue() -> void:
	var layer = MotionLayer.new()
	var started: Array[StringName] = []
	layer.enqueue_feedback(
		Cue.new(&"operation", null, null, 0, &"neutral", Cue.Priority.OPERATION_CONFIRMATION),
		func() -> void: started.append(&"operation")
	)
	layer.enqueue_feedback(
		Cue.new(&"ambient", null, null, 0, &"neutral", Cue.Priority.AMBIENT_STATE),
		func() -> void: started.append(&"ambient")
	)
	layer.enqueue_feedback(
		Cue.new(&"rare", null, null, 0, &"rare", Cue.Priority.RARE_HIGHLIGHT, true),
		func() -> void: started.append(&"rare")
	)
	layer.finish_active_feedback()
	assert_equal(started, [&"operation", &"rare"], "rare highlight should be next after the current focus finishes")
	layer.finish_active_feedback()
	assert_equal(started, [&"operation", &"rare", &"ambient"], "ambient feedback should resume after the rare highlight")
	layer.free()

func _test_diagnostics_stay_out_of_snapshots() -> void:
	var report := ResolutionReport.new()
	report.rule_diagnostics = {
		&"left": {"actual": 5, "target": 7, "delta": -2},
	}
	var snapshot := SnapshotCodec.report_to_snapshot(report)
	assert_false(snapshot.has("rule_diagnostics"), "presentation diagnostics must not change the save shape")

func _test_original_assets_are_registered() -> void:
	for path in [
		"res://resources/ui/dream_glass/feedback/trace_gold_corridor.svg",
		"res://resources/ui/dream_glass/feedback/trace_mirror_hall.svg",
		"res://resources/ui/dream_glass/feedback/trace_faceless_hub.svg",
		"res://resources/ui/dream_glass/feedback/seal_storm.svg",
		"res://resources/ui/dream_glass/feedback/seal_resonance.svg",
		"res://resources/ui/dream_glass/feedback/seal_lucky.svg",
		"res://resources/ui/dream_glass/feedback/seal_engraving_set.svg",
		"res://resources/ui/dream_glass/feedback/seal_dealer.svg",
		"res://resources/ui/dream_glass/feedback/seal_achievement.svg",
		"res://resources/audio/sfx/zz_feedback_gold_corridor.wav",
		"res://resources/audio/sfx/zz_feedback_mirror_hall.wav",
		"res://resources/audio/sfx/zz_feedback_faceless_hub.wav",
	]:
		assert_true(ResourceLoader.exists(path), "feedback asset should be importable: %s" % path)
