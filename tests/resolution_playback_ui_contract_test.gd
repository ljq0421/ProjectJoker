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
		"PredictionTotal",
		"EmptyState",
		"EventScroll",
		"EventList",
		"HiddenEventSummary",
		"EventDetail",
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
	assert_true(
		panel.get_node("%PredictionTotal").tooltip_text.contains("基础分"),
		"prediction total detail should retain the eight-part score ledger"
	)
	assert_true(
		panel.get_node("%PredictionTotal").tooltip_text.contains("庄家奖励"),
		"prediction total detail should retain the eighth category"
	)
	assert_equal(
		_score_row_count(panel),
		3,
		"preview should immediately show only score-changing events"
	)
	assert_equal(
		panel.get_node("%PredictionTotal").text,
		"9",
		"preview should lead with the predicted total"
	)
	var hidden_summary = panel.get_node("%HiddenEventSummary")
	assert_true(hidden_summary.visible, "zero-value events should use a compact summary")
	assert_equal(
		hidden_summary.get_node("%EventTitle").text,
		"其他影响 1 · 未触发 1",
		"summary should distinguish applied effects from misses"
	)
	assert_equal(
		panel.get_node("%ResolutionHeading").text,
		"预测轨迹",
		"preview should be explicitly labelled"
	)
	var preview_row = panel.get_node("%EventList").get_child(0)
	preview_row.grab_focus()
	assert_true(
		panel.get_node("%EventDetail").text.contains("0 → 8（+8）"),
		"keyboard focus should expose the complete event arithmetic"
	)
	assert_true(
		preview_row.tooltip_text.contains("左侧规则台"),
		"mouse tooltip should retain the full event label"
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
		_score_row_count(panel),
		0,
		"committed playback should begin before the first event"
	)
	panel.advance_playback_for_test(0.42)
	assert_equal(
		_score_row_count(panel),
		1,
		"first interval should reveal one event"
	)
	var first_row = panel.get_node("%EventList").get_child(0)
	assert_true(
		first_row.tooltip_text.contains("0 → 8（+8）"),
		"event detail should show old and new totals"
	)
	assert_equal(
		first_row.get_node("%EventDelta").text,
		"+8",
		"compact event row should lead with its signed delta"
	)
	panel.finish_playback()
	assert_equal(
		_score_row_count(panel),
		3,
		"finish should reveal all score-changing committed events"
	)
	assert_equal(
		panel.get_node("%PredictionTotal").text,
		"9",
		"finished playback should show the committed total"
	)
	assert_equal(
		panel.get_node("%HiddenEventSummary").get_meta("collapsed_event_count"),
		2,
		"finish should preserve zero-value events in the summary"
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
	var first_row = panel.get_node("%EventList").get_child(0)
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

func _score_row_count(panel: ResolutionPanel) -> int:
	var count := 0
	for child in panel.get_node("%EventList").get_children():
		if child.name != "HiddenEventSummary":
			count += 1
	return count

func _fixture_report() -> ResolutionReport:
	var report := ResolutionReport.new()
	var base := ResolutionEvent.new(&"left", "左侧规则台：精确命中", 8, 8)
	var direction := ResolutionEvent.new(
		&"mirror_flow",
		"区域异变：结算方向翻转",
		0,
		8
	)
	direction.score_source = ResolutionEvent.ScoreSource.AREA_MODIFIER
	var missed := ResolutionEvent.new(
		&"dealer",
		"庄家规则未触发",
		0,
		8,
		false
	)
	missed.score_source = ResolutionEvent.ScoreSource.DEALER
	var bridge := ResolutionEvent.new(&"bridge", "桥接手法：左轨传递", 4, 12)
	bridge.score_source = ResolutionEvent.ScoreSource.CARD
	bridge.source_table_id = &"left"
	bridge.target_table_id = &"middle"
	bridge.combo_kind = &"bridge"
	var penalty := ResolutionEvent.new(
		&"area_penalty",
		"区域惩罚：未分配骰子",
		-3,
		9
	)
	penalty.score_source = ResolutionEvent.ScoreSource.AREA_MODIFIER
	report.events = [base, direction, missed, bridge, penalty]
	report.total = 9
	report.score_breakdown[ResolutionEvent.ScoreSource.BASE] = 8
	report.score_breakdown[ResolutionEvent.ScoreSource.CARD] = 4
	report.score_breakdown[ResolutionEvent.ScoreSource.AREA_MODIFIER] = -3
	return report
