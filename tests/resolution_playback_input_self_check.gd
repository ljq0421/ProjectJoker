extends SceneTree

class FakeDisplayAdapter:
	extends RefCounted

	func snapshot() -> Dictionary:
		return {
			"mode": "windowed",
			"window_size": Vector2i(1280, 720),
			"vsync_enabled": true,
		}

	func available_resolutions() -> Array[Vector2i]:
		return [
			Vector2i(1280, 720),
			Vector2i(1600, 900),
			Vector2i(1920, 1080),
		]

	func apply_settings(_settings: Dictionary) -> Dictionary:
		return {"ok": true, "error": ""}

	func restore(_snapshot_values: Dictionary) -> Dictionary:
		return {"ok": true, "error": ""}

var failures: Array[String] = []
var pointer_position := Vector2.ZERO
var screen: SingleEncounterScreen
var committed_reports: Array[ResolutionReport] = []
var temporary_settings_path := ""

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	_install_settings_fixture()
	screen = load(
		"res://scenes/run/single_encounter_screen.tscn"
	).instantiate()
	screen.tutorial_auto_start = false
	root.add_child(screen)
	await process_frame
	await process_frame
	screen.round_committed.connect(
		func(report: ResolutionReport) -> void:
			committed_reports.append(report)
	)
	for assignment in [
		[&"d1", &"left"],
		[&"d6", &"left"],
		[&"d2", &"middle"],
		[&"d3", &"middle"],
		[&"d4", &"right"],
		[&"d5", &"right"],
	]:
		screen.session.activate_die(assignment[0])
		screen.session.activate_table(assignment[1])
	screen.refresh_from_session()
	await process_frame

	await _click(screen.get_node("%ConfirmButton"))
	_assert_true(
		screen.resolution_panel.is_playing(),
		"real confirmation click should start formal playback"
	)
	_assert_equal(
		committed_reports.size(),
		0,
		"parent notification should wait for formal playback"
	)
	var report := screen.session.commit()
	_assert_true(report != null, "domain commit should already be complete")
	if report != null:
		_assert_equal(
			_event_row_count(),
			0,
			"formal playback should begin before revealing the first event"
		)

	await _click(
		screen.resolution_panel.get_node("%BoostResolutionButton")
	)
	_assert_true(
		screen.resolution_panel.get_node(
			"%BoostResolutionButton"
		).button_pressed,
		"real pointer should enable temporary 2x playback"
	)
	await _click(
		screen.resolution_panel.get_node("%FinishResolutionButton")
	)
	_assert_false(
		screen.resolution_panel.is_playing(),
		"real pointer should finish the remaining playback"
	)
	_assert_equal(
		committed_reports.size(),
		1,
		"event playback should hand the result directly to the round summary"
	)
	var motion_layer: InteractionMotionLayer = screen.get_node("%InteractionMotionLayer")
	_assert_true(
		motion_layer.get_node_or_null("ResolutionClimaxOverlay") == null,
		"formal resolution must not open a second popup before round summary"
	)
	if report != null:
		_assert_equal(
			_represented_event_count(),
			report.events.size(),
			"finished playback should account for every committed event"
		)
		_assert_equal(
			committed_reports[0].event_signature(),
			report.event_signature(),
			"parent should receive the exact committed event sequence"
		)

	await _finish()

func _event_row_count() -> int:
	var event_list: Control = screen.resolution_panel.get_node("%EventList")
	var hidden_summary: Control = screen.resolution_panel.get_node(
		"%HiddenEventSummary"
	)
	var count := 0
	for child in event_list.get_children():
		if child != hidden_summary:
			count += 1
	return count

func _represented_event_count() -> int:
	var hidden_summary: Control = screen.resolution_panel.get_node(
		"%HiddenEventSummary"
	)
	var collapsed_count := (
		int(hidden_summary.get_meta("collapsed_event_count", 0))
		if hidden_summary.visible
		else 0
	)
	return _event_row_count() + collapsed_count

func _install_settings_fixture() -> void:
	temporary_settings_path = (
		"%s/project-joker-resolution-playback-input-%d.cfg"
		% [OS.get_temp_dir(), Time.get_ticks_usec()]
	)
	var service := root.get_node_or_null("SettingsService")
	if service == null:
		service = load(
			"res://scripts/settings/settings_service.gd"
		).new()
		service.name = "SettingsService"
		root.add_child(service)
	service.configure_for_test(
		SettingsStore.new(temporary_settings_path),
		FakeDisplayAdapter.new(),
		10.0
	)

func _click(control: Control) -> void:
	_assert_true(control != null, "click target should exist")
	if control == null:
		return
	var point := control.get_global_rect().get_center()
	await _move_pointer(point)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = point
	root.push_input(press, true)
	await process_frame
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = point
	root.push_input(release, true)
	await process_frame

func _move_pointer(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.relative = point - pointer_position
	root.push_input(motion, true)
	pointer_position = point
	await process_frame

func _assert_true(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func _assert_false(value: bool, message: String) -> void:
	if value:
		failures.append(message)

func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		failures.append(
			"%s; expected=%s actual=%s" % [message, expected, actual]
		)

func _finish() -> void:
	if screen != null:
		screen.queue_free()
	await process_frame
	for candidate in [
		temporary_settings_path,
		"%s.tmp" % temporary_settings_path,
		"%s.bak" % temporary_settings_path,
	]:
		var absolute := ProjectSettings.globalize_path(candidate)
		if FileAccess.file_exists(absolute):
			DirAccess.remove_absolute(absolute)
	if failures.is_empty():
		print("PASS resolution_playback_input_self_check")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
