extends SceneTree

class FakeDisplayAdapter:
	extends RefCounted

	var runtime := {
		"mode": "windowed",
		"window_size": Vector2i(1280, 720),
		"vsync_enabled": true,
	}

	func snapshot() -> Dictionary:
		return runtime.duplicate(true)

	func available_resolutions() -> Array[Vector2i]:
		return [
			Vector2i(1280, 720),
			Vector2i(1600, 900),
			Vector2i(1920, 1080),
		]

	func apply_settings(settings: Dictionary) -> Dictionary:
		runtime["mode"] = settings["mode"]
		runtime["window_size"] = Vector2i(
			int(settings["window_width"]),
			int(settings["window_height"])
		)
		runtime["vsync_enabled"] = settings["vsync_enabled"]
		return {"ok": true, "error": ""}

	func restore(snapshot_values: Dictionary) -> Dictionary:
		runtime = snapshot_values.duplicate(true)
		return {"ok": true, "error": ""}

var failures: Array[String] = []
var pointer_position := Vector2.ZERO
var started_cues: Array[StringName] = []
var screen: SingleEncounterScreen
var settings_layer: SettingsLayer
var settings_service: Node
var temporary_settings_path := ""

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	_install_test_services()
	screen = load(
		"res://scenes/run/single_encounter_screen.tscn"
	).instantiate()
	screen.tutorial_auto_start = false
	root.add_child(screen)
	await process_frame
	await process_frame

	settings_layer = screen.get_node("%SettingsLayer")
	_assert_true(
		settings_layer != null,
		"main encounter should expose the shared settings layer"
	)
	if settings_layer == null:
		await _finish()
		return

	var cue_count_before_hover := started_cues.size()
	await _move_pointer(
		settings_layer.get_node("%SettingsButton").get_global_rect().get_center()
	)
	_assert_equal(
		started_cues.size(),
		cue_count_before_hover,
		"hovering settings entry should stay silent"
	)

	await _click(settings_layer.get_node("%SettingsButton"))
	_assert_true(settings_layer.is_open(), "settings click should open overlay")
	_assert_true(paused, "opening settings should pause the scene tree")
	_assert_true(
		settings_layer.get_node("%SettingsOverlay").visible,
		"open settings should show the full-screen overlay"
	)
	_assert_latest(&"panel_open", "opening should play panel_open once")

	await _click(settings_layer.get_node("%AccessibilityTabButton"))
	_assert_true(
		settings_layer.get_node("%AccessibilityPage").visible,
		"accessibility tab should show accessibility controls"
	)
	await _click(settings_layer.get_node("%ReduceFlashesCheck"))
	await _click(settings_layer.get_node("%DisableDistortionCheck"))
	_assert_true(
		bool(settings_service.call(
			"accessibility_value",
			&"reduce_flashes"
		)),
		"real pointer should enable reduced flashes"
	)
	_assert_true(
		bool(settings_service.call(
			"accessibility_value",
			&"disable_distortion"
		)),
		"real pointer should disable distortion"
	)
	var speed_option: OptionButton = settings_layer.get_node(
		"%ResolutionSpeedOption"
	)
	speed_option.select(1)
	speed_option.item_selected.emit(1)
	_assert_equal(
		settings_service.call(
			"accessibility_value",
			&"resolution_speed"
		),
		"fast",
		"resolution speed option should persist fast mode"
	)
	var scale_option: OptionButton = settings_layer.get_node("%UiScaleOption")
	scale_option.select(1)
	scale_option.item_selected.emit(1)
	await process_frame
	_assert_true(
		absf(root.content_scale_factor - 1.1) < 0.001,
		"110% UI scale should apply to the root window"
	)
	await _click(
		settings_layer.get_node("%RestoreAccessibilityDefaultsButton")
	)
	await process_frame
	_assert_true(
		absf(root.content_scale_factor - 1.0) < 0.001,
		"restoring accessibility defaults should restore 100% UI scale"
	)
	await _click(settings_layer.get_node("%AudioTabButton"))

	var assignments_before: Dictionary = (
		screen.session.controller.state.assignments.duplicate(true)
	)
	await _click(_find_die(&"d1"))
	_assert_equal(
		screen.session.controller.state.assignments,
		assignments_before,
		"overlay should block underlying gameplay input"
	)

	var cue_count_before_page_hover := started_cues.size()
	await _move_pointer(
		settings_layer.get_node("%DisplayTabButton")
		.get_global_rect()
		.get_center()
	)
	_assert_equal(
		started_cues.size(),
		cue_count_before_page_hover,
		"hovering a settings category should stay silent"
	)

	var cues_before_drag := started_cues.size()
	await _drag_slider(settings_layer.get_node("%UiSlider"), 0.72)
	_assert_equal(
		started_cues.size(),
		cues_before_drag + 1,
		"one completed slider drag should request exactly one preview: %s"
		% [started_cues]
	)
	_assert_latest(
		&"ui_confirm",
		"UI slider drag should preview the UI cue"
	)

	await _click(settings_layer.get_node("%DisplayTabButton"))
	_assert_true(
		settings_layer.get_node("%DisplayPage").visible,
		"display tab should show display controls"
	)
	settings_service.call("set_display_draft_mode", "fullscreen")
	_assert_true(
		bool(settings_service.call("can_apply_display_draft")),
		"fullscreen display draft should be applicable"
	)
	_assert_false(
		settings_layer.get_node("%ApplyDisplayButton").disabled,
		"display apply button should be enabled"
	)
	await _click(settings_layer.get_node("%ApplyDisplayButton"))
	_assert_true(
		settings_service.call("display_confirmation_active"),
		"display apply should open confirmation; error=%s draft=%s"
		% [
			settings_service.call("last_error"),
			settings_service.call("display_draft"),
		]
	)
	_assert_true(
		settings_layer.get_node("%DisplayConfirmationLayer").visible,
		"display confirmation should visibly block settings"
	)
	await _click(settings_layer.get_node("%RevertDisplayButton"))
	_assert_false(
		settings_service.call("display_confirmation_active"),
		"manual revert should close confirmation"
	)

	settings_service.call("set_display_draft_mode", "fullscreen")
	await _click(settings_layer.get_node("%ApplyDisplayButton"))
	settings_service._process(11.0)
	_assert_false(
		settings_service.call("display_confirmation_active"),
		"confirmation timeout should revert"
	)
	_assert_false(
		settings_layer.get_node("%DisplayConfirmationLayer").visible,
		"timeout should hide confirmation layer"
	)

	await _press_escape()
	_assert_false(settings_layer.is_open(), "Escape should close settings")
	_assert_false(paused, "closing should restore the prior unpaused state")
	_assert_latest(&"panel_close", "closing should play panel_close once")

	var session_before := screen.session
	var state_before := screen.session.controller.state
	await _click(settings_layer.get_node("%RuleReferenceButton"))
	_assert_true(
		settings_layer.is_rule_reference_open(),
		"rule reference click should open the read-only overlay"
	)
	_assert_true(paused, "opening rule reference should pause the scene tree")
	var reference: Control = settings_layer.get_node("%RuleReferenceOverlay")
	_assert_true(reference.visible, "rule reference overlay should become visible")
	_assert_true(
		reference.get_node("%CurrentRulesButton").visible,
		"active encounter should expose its current three rules"
	)
	_assert_equal(
		reference.get_node("%ArchiveContextLabel").text,
		"当前牌局",
		"active encounter should open on the current-rules spine"
	)
	_assert_equal(screen.session, session_before, "opening reference should keep the session")
	_assert_equal(
		screen.session.controller.state,
		state_before,
		"opening reference should keep the mutable round state"
	)
	await _click(reference.get_node("%Archive06Button"))
	await _click(reference.get_node("%Rule03Button"))
	_assert_equal(
		reference.get_node("%RuleDetailTitle").text,
		"反向台",
		"real pointer should open the canonical reverse-table entry"
	)
	_assert_true(
		reference.get_node("%RuleDetailTiming").text.contains("翻转"),
		"reverse-table entry should explain its timing"
	)
	await _press_f1()
	_assert_false(
		settings_layer.is_rule_reference_open(),
		"F1 should close the rule reference overlay"
	)
	_assert_false(paused, "closing rule reference should restore play")
	_assert_equal(screen.session, session_before, "closing reference should keep the session")

	paused = true
	settings_layer.open_settings()
	_assert_true(
		settings_layer.is_open(),
		"settings should open when the host was already paused"
	)
	settings_layer.close_settings()
	_assert_true(
		paused,
		"closing should preserve a pre-existing paused state"
	)
	paused = false
	await _finish()

func _install_test_services() -> void:
	var sfx := root.get_node_or_null("SfxService")
	if sfx == null:
		sfx = load("res://scripts/audio/sfx_service.gd").new()
		sfx.name = "SfxService"
		root.add_child(sfx)
	sfx.cue_started.connect(
		func(cue_id: StringName, _bus_name: StringName) -> void:
			started_cues.append(cue_id)
	)

	temporary_settings_path = "%s/project-joker-settings-input-%d.cfg" % [
		OS.get_temp_dir(),
		Time.get_ticks_usec(),
	]
	settings_service = root.get_node_or_null("SettingsService")
	if settings_service == null:
		settings_service = load(
			"res://scripts/settings/settings_service.gd"
		).new()
		settings_service.name = "SettingsService"
		root.add_child(settings_service)
	settings_service.configure_for_test(
		SettingsStore.new(temporary_settings_path),
		FakeDisplayAdapter.new(),
		10.0
	)

func _find_die(id: StringName) -> DieToken:
	for node in screen.find_children("*", "Button", true, false):
		if node is DieToken and node.die_id == id:
			return node
	return null

func _click(control: Control) -> void:
	_assert_true(control != null, "click target should exist")
	if control == null:
		return
	await _click_at_point(control.get_global_rect().get_center())

func _click_at_point(point: Vector2) -> void:
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

func _drag_slider(slider: HSlider, ratio: float) -> void:
	var rect := slider.get_global_rect()
	var start := Vector2(rect.position.x + 8.0, rect.get_center().y)
	var finish := Vector2(
		rect.position.x + rect.size.x * ratio,
		rect.get_center().y
	)
	await _move_pointer(start)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = start
	root.push_input(press, true)
	await process_frame
	var motion := InputEventMouseMotion.new()
	motion.position = finish
	motion.relative = finish - start
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(motion, true)
	pointer_position = finish
	await process_frame
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = finish
	root.push_input(release, true)
	await process_frame

func _move_pointer(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.relative = point - pointer_position
	root.push_input(motion, true)
	pointer_position = point
	await process_frame

func _press_escape() -> void:
	var press := InputEventKey.new()
	press.keycode = KEY_ESCAPE
	press.pressed = true
	root.push_input(press, true)
	await process_frame
	var release := InputEventKey.new()
	release.keycode = KEY_ESCAPE
	release.pressed = false
	root.push_input(release, true)
	await process_frame

func _press_f1() -> void:
	var press := InputEventKey.new()
	press.keycode = KEY_F1
	press.pressed = true
	root.push_input(press, true)
	await process_frame
	var release := InputEventKey.new()
	release.keycode = KEY_F1
	release.pressed = false
	root.push_input(release, true)
	await process_frame

func _assert_latest(cue_id: StringName, message: String) -> void:
	_assert_true(not started_cues.is_empty(), message)
	if not started_cues.is_empty():
		_assert_equal(started_cues[-1], cue_id, message)

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
	_remove_settings_files(temporary_settings_path)
	if failures.is_empty():
		print("PASS settings_input_self_check")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _remove_settings_files(path: String) -> void:
	if path.is_empty():
		return
	for candidate in [path, "%s.tmp" % path, "%s.bak" % path]:
		var absolute := ProjectSettings.globalize_path(candidate)
		if FileAccess.file_exists(absolute):
			DirAccess.remove_absolute(absolute)
