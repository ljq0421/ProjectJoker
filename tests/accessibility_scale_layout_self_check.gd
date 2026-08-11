extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_assert_true(
		String(ProjectSettings.get_setting("display/window/stretch/mode"))
		== "canvas_items",
		"project stretch mode should use canvas_items"
	)
	_assert_true(
		String(ProjectSettings.get_setting("display/window/stretch/aspect"))
		== "keep",
		"project stretch aspect should preserve the 16:9 canvas"
	)
	for window_size in [
		Vector2i(1280, 720),
		Vector2i(1920, 1080),
	]:
		for scale_percent in [100, 110, 125]:
			await _check_layout(window_size, scale_percent)
	root.content_scale_factor = 1.0
	if failures.is_empty():
		print("PASS accessibility_scale_layout_self_check")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _check_layout(window_size: Vector2i, scale_percent: int) -> void:
	root.size = window_size
	root.content_scale_factor = float(scale_percent) / 100.0
	await process_frame
	var screen: SingleEncounterScreen = load(
		"res://scenes/run/single_encounter_screen.tscn"
	).instantiate()
	screen.tutorial_auto_start = false
	root.add_child(screen)
	await process_frame
	await process_frame
	for fixed_control in [
		[screen.get_node("SafeArea/RootColumn/TopBar"), Vector2(1856, 32), "TopBar"],
		[screen.get_node("SafeArea/RootColumn/TopBar/RestrictionSlot"), Vector2(260, 32), "RestrictionSlot"],
		[screen.get_node("SafeArea/RootColumn/AreaDirectiveSlot"), Vector2(1856, 40), "AreaDirectiveSlot"],
		[screen.get_node("SafeArea/RootColumn/Body"), Vector2(1856, 836), "Body"],
		[screen.get_node("SafeArea/RootColumn/Body/DealerPanel"), Vector2(230, 836), "DealerPanel"],
		[screen.get_node("SafeArea/RootColumn/Body/Center"), Vector2(1290, 836), "Center"],
		[screen.get_node("%LeftLane"), Vector2(371, 302), "LeftLane"],
		[screen.get_node("%MiddleLane"), Vector2(372, 302), "MiddleLane"],
		[screen.get_node("%RightLane"), Vector2(371, 302), "RightLane"],
		[screen.get_node("%LeftGap"), Vector2(72, 256), "LeftGap"],
		[screen.get_node("%RightGap"), Vector2(72, 256), "RightGap"],
		[screen.get_node("SafeArea/RootColumn/Body/Center/Lanes/LeftGapColumn/LeftMirrorSlot"), Vector2(72, 40), "LeftMirrorSlot"],
		[screen.get_node("SafeArea/RootColumn/Body/Center/Lanes/RightGapColumn/RightMirrorSlot"), Vector2(72, 40), "RightMirrorSlot"],
		[screen.get_node("SafeArea/RootColumn/Body/Center/DiceRow"), Vector2(1290, 102), "DiceRow"],
		[screen.get_node("%Hand"), Vector2(1290, 126), "Hand"],
		[screen.get_node("%CardDetailPanel"), Vector2(1290, 150), "CardDetailPanel"],
		[screen.get_node("SafeArea/RootColumn/Body/Center/ActionBar"), Vector2(1290, 42), "ActionBar"],
		[screen.get_node("SafeArea/RootColumn/Body/Center/EmergencyBar"), Vector2(1290, 42), "EmergencyBar"],
		[screen.get_node("%ResolutionPanel"), Vector2(300, 836), "ResolutionPanel"],
	]:
		_assert_size(
			fixed_control[0],
			fixed_control[1],
			fixed_control[2],
			window_size,
			scale_percent
		)
	var viewport_rect := root.get_visible_rect()
	_assert_rect_inside(
		screen.get_global_rect(),
		viewport_rect,
		"encounter root",
		window_size,
		scale_percent
	)

	var settings: SettingsLayer = screen.get_node("%SettingsLayer")
	settings.open_settings()
	settings._show_accessibility_page(false)
	await process_frame
	var overlay_rect: Rect2 = (
		settings.get_node("%SettingsOverlay") as Control
	).get_global_rect()
	_assert_rect_inside(
		overlay_rect,
		viewport_rect,
		"settings overlay",
		window_size,
		scale_percent
	)
	for node_name in [
		"AccessibilityTabButton",
		"ReduceFlashesCheck",
		"DisableDistortionCheck",
		"ResolutionSpeedOption",
		"UiScaleOption",
		"RestoreAccessibilityDefaultsButton",
	]:
		var control: Control = settings.get_node("%%%s" % node_name)
		_assert_rect_inside(
			control.get_global_rect(),
			overlay_rect,
			node_name,
			window_size,
			scale_percent
		)
	settings.close_settings()

	var report := ResolutionReport.new()
	report.events = [
		ResolutionEvent.new(&"left", "左侧规则台", 8, 8),
		ResolutionEvent.new(&"middle", "中央规则台", 4, 12),
	]
	report.total = 12
	screen.resolution_panel.play_committed_report(report, {
		"resolution_speed": "normal",
		"reduce_flashes": true,
		"disable_distortion": true,
	})
	await process_frame
	for fixed_control in [
		[screen.resolution_panel, Vector2(300, 836), "ResolutionPanel"],
		[screen.resolution_panel.get_node("%TimelineShell"), Vector2(268, 608), "TimelineShell"],
		[screen.resolution_panel.get_node("%PlaybackActionSlot"), Vector2(268, 46), "PlaybackActionSlot"],
		[screen.resolution_panel.get_node("%BoostResolutionButton"), Vector2(132, 46), "BoostResolutionButton"],
		[screen.resolution_panel.get_node("%FinishResolutionButton"), Vector2(132, 46), "FinishResolutionButton"],
	]:
		_assert_size(
			fixed_control[0],
			fixed_control[1],
			fixed_control[2],
			window_size,
			scale_percent
		)
	var narrative: Control = load(
		"res://scenes/components/narrative_card.tscn"
	).instantiate()
	screen.add_child(narrative)
	var area := AreaCatalog.new().gold_corridor()
	narrative.show_area_transition(area, {
		"deck_ids": area.starting_deck_ids,
		"intel_tickets": 0,
		"die_profiles": [],
	}, {
		"reduce_flashes": true,
		"disable_distortion": true,
	})
	await process_frame
	for node_name in [
		"NarrativeCard",
		"NarrativeTitle",
		"NarrativeBody",
		"NarrativeContextLabel",
		"NarrativeContinueButton",
		"NarrativeExitButton",
	]:
		var control: Control = narrative.get_node("%%%s" % node_name)
		_assert_rect_inside(
			control.get_global_rect(),
			viewport_rect,
			node_name,
			window_size,
			scale_percent
		)
	var expedition_save_path := OS.get_temp_dir().path_join(
		"project-joker-narrative-layout-%d.cfg" % Time.get_ticks_usec()
	)
	root.set_meta("expedition_launch_mode", &"new")
	root.set_meta("expedition_seed", 20260729)
	root.set_meta("expedition_save_path", expedition_save_path)
	var expedition: ExpeditionRunScreen = load(
		"res://scenes/run/expedition_run_screen.tscn"
	).instantiate()
	root.add_child(expedition)
	await process_frame
	await process_frame
	expedition._show_summary()
	await process_frame
	for node_name in [
		"ExpeditionSummaryPanel",
		"ExpeditionAreaHistoryLabel",
		"ExpeditionFinalBuildLabel",
		"ExpeditionEpilogueLabel",
		"ReturnFromExpeditionButton",
	]:
		var control: Control = expedition.get_node("%%%s" % node_name)
		_assert_rect_inside(
			control.get_global_rect(),
			viewport_rect,
			node_name,
			window_size,
			scale_percent
		)
	expedition.queue_free()
	for path in [
		expedition_save_path,
		expedition_save_path + ".tmp",
		expedition_save_path + ".bak",
	]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	screen.queue_free()
	await process_frame

func _assert_rect_inside(
	rect: Rect2,
	bounds: Rect2,
	name: String,
	window_size: Vector2i,
	scale_percent: int
) -> void:
	if (
		rect.position.x < bounds.position.x - 0.5
		or rect.position.y < bounds.position.y - 0.5
		or rect.end.x > bounds.end.x + 0.5
		or rect.end.y > bounds.end.y + 0.5
	):
		failures.append(
			"%s should stay visible at %s / %d%%: %s within %s"
			% [name, window_size, scale_percent, rect, bounds]
		)

func _assert_size(
	control: Control,
	expected: Vector2,
	name: String,
	window_size: Vector2i,
	scale_percent: int
) -> void:
	if not control.size.is_equal_approx(expected):
		failures.append(
			"%s should keep fixed logical size at %s / %d%%: %s, expected %s"
			% [name, window_size, scale_percent, control.size, expected]
		)

func _assert_true(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
