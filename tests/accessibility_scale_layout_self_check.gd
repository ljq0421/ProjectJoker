extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
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
	for node_name in [
		"ResolutionPanel",
		"BoostResolutionButton",
		"FinishResolutionButton",
	]:
		var control: Control = (
			screen.resolution_panel
			if node_name == "ResolutionPanel"
			else screen.resolution_panel.get_node("%%%s" % node_name)
		)
		_assert_rect_inside(
			control.get_global_rect(),
			viewport_rect,
			node_name,
			window_size,
			scale_percent
		)
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
