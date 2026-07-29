extends "res://tests/test_case.gd"

const PANEL_SCENE_PATH := "res://scenes/components/resolution_panel.tscn"

func run() -> void:
	_test_scene_contract()
	_test_preview_and_committed_playback_contract()
	_test_accessibility_modes_change_visual_policy()
	_test_single_encounter_defers_parent_notification()

func _test_scene_contract() -> void:
	var scene := load(PANEL_SCENE_PATH)
	assert_true(scene != null, "resolution panel scene should load")
	if scene == null:
		return
	var panel: ResolutionPanel = scene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(panel)
	for node_name in [
		"ResolutionHeading",
		"PlaybackStatus",
		"EventList",
		"Total",
		"PlaybackActions",
		"BoostResolutionButton",
		"FinishResolutionButton",
	]:
		assert_true(
			panel.get_node_or_null("%%%s" % node_name) != null,
			"resolution panel should expose %s" % node_name
		)
	panel.free()

func _test_preview_and_committed_playback_contract() -> void:
	var panel: ResolutionPanel = load(PANEL_SCENE_PATH).instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(panel)
	var report := _fixture_report()
	panel.bind_report(report)
	assert_equal(
		panel.get_node("%EventList").get_child_count(),
		report.events.size(),
		"preview should remain immediate"
	)
	assert_equal(
		panel.get_node("%ResolutionHeading").text,
		"预测轨迹",
		"preview should be explicitly labelled"
	)

	var completion_count := [0]
	panel.playback_finished.connect(
		func(completed_report: ResolutionReport) -> void:
			assert_true(
				completed_report == report,
				"panel should return the original committed report"
			)
			completion_count[0] += 1
	)
	panel.play_committed_report(report, {
		"resolution_speed": "normal",
		"reduce_flashes": false,
		"disable_distortion": false,
	})
	assert_true(panel.is_playing(), "normal committed report should start playback")
	assert_equal(
		panel.get_node("%EventList").get_child_count(),
		0,
		"committed playback should begin before the first event"
	)
	panel.advance_playback_for_test(0.42)
	assert_equal(
		panel.get_node("%EventList").get_child_count(),
		1,
		"first interval should reveal one event"
	)
	var first_row: Label = panel.get_node("%EventList").get_child(0)
	assert_true(
		first_row.text.contains("0 → 8"),
		"event row should show old and new totals"
	)
	assert_true(
		first_row.text.contains("生效"),
		"event row should name its applied status"
	)
	panel.finish_playback()
	assert_equal(
		panel.get_node("%EventList").get_child_count(),
		report.events.size(),
		"finish should reveal all remaining committed events"
	)
	assert_equal(
		panel.get_node("%Total").text,
		"正式结算：12",
		"finished playback should show the committed total"
	)
	assert_equal(completion_count[0], 1, "panel completion should emit once")
	panel.finish_playback()
	assert_equal(completion_count[0], 1, "panel finish should be idempotent")
	panel.free()

func _test_accessibility_modes_change_visual_policy() -> void:
	var panel: ResolutionPanel = load(PANEL_SCENE_PATH).instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(panel)
	panel.play_committed_report(_fixture_report(), {
		"resolution_speed": "instant",
		"reduce_flashes": true,
		"disable_distortion": true,
	})
	assert_false(panel.is_playing(), "instant mode should finish immediately")
	var first_row: Label = panel.get_node("%EventList").get_child(0)
	assert_true(
		first_row.get_meta("flash_suppressed", false),
		"reduced flashes should suppress row brightness pulse"
	)
	assert_true(
		first_row.get_meta("motion_suppressed", false),
		"disabled distortion should suppress row displacement"
	)
	panel.free()

func _test_single_encounter_defers_parent_notification() -> void:
	var source := FileAccess.get_file_as_string(
		"res://scripts/ui/single_encounter_screen.gd"
	)
	assert_true(
		source.contains("play_committed_report"),
		"encounter screen should start formal playback after commit"
	)
	assert_true(
		source.contains("_on_resolution_playback_finished"),
		"encounter screen should notify parents from playback completion"
	)

func _fixture_report() -> ResolutionReport:
	var report := ResolutionReport.new()
	report.events = [
		ResolutionEvent.new(&"left", "左侧规则台", 8, 8),
		ResolutionEvent.new(&"dealer", "庄家规则未触发", 0, 8, false),
		ResolutionEvent.new(&"bridge", "桥接手法", 4, 12),
	]
	report.total = 12
	return report
