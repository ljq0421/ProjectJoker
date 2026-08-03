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
var settings_service: Node
var temporary_settings_path := ""

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_install_test_services()
	for viewport_size in [
		Vector2i(1280, 720),
		Vector2i(1600, 900),
		Vector2i(1920, 1080),
	]:
		await _check_size(viewport_size)
	_remove_settings_files(temporary_settings_path)
	if failures.is_empty():
		print("PASS settings_layout_self_check")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _check_size(viewport_size: Vector2i) -> void:
	var test_viewport := SubViewport.new()
	test_viewport.size = viewport_size
	test_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(test_viewport)
	var layer: SettingsLayer = load(
		"res://scenes/components/settings_layer.tscn"
	).instantiate()
	test_viewport.add_child(layer)
	await process_frame
	await process_frame

	var entry: Button = layer.get_node("%SettingsButton")
	var entry_rect := entry.get_global_rect()
	var rule_entry: Button = layer.get_node("%RuleReferenceButton")
	var rule_entry_rect := rule_entry.get_global_rect()
	_assert_inside_viewport(
		entry_rect,
		viewport_size,
		"settings entry",
		viewport_size
	)
	_assert_true(
		absf(entry_rect.end.x - (viewport_size.x - 24.0)) < 1.0,
		"settings entry should keep 24px right margin at %s" % viewport_size
	)
	_assert_true(
		absf(entry_rect.position.y - 24.0) < 1.0,
		"settings entry should keep 24px top margin at %s" % viewport_size
	)
	_assert_inside_viewport(
		rule_entry_rect,
		viewport_size,
		"rule reference entry",
		viewport_size
	)
	_assert_true(
		absf(rule_entry_rect.end.x - entry_rect.position.x + 8.0) < 1.0,
		"utility entries should keep an eight pixel gap at %s" % viewport_size
	)

	layer.open_settings()
	await process_frame
	var overlay: Control = layer.get_node("%SettingsOverlay")
	var overlay_rect := overlay.get_global_rect()
	_assert_true(
		overlay_rect.position == Vector2.ZERO,
		"overlay should start at the viewport origin at %s" % viewport_size
	)
	_assert_true(
		overlay_rect.size == Vector2(viewport_size),
		"overlay should cover the viewport at %s" % viewport_size
	)

	for node_name in [
		"AudioTabButton",
		"DisplayTabButton",
		"AccessibilityTabButton",
		"MasterSlider",
		"MusicSlider",
		"UiSlider",
		"GameplaySlider",
		"RestoreAudioDefaultsButton",
	]:
		var control: Control = layer.get_node("%%%s" % node_name)
		_assert_rect_inside(
			control.get_global_rect(),
			overlay_rect,
			node_name,
			viewport_size
		)

	layer._show_display_page(false)
	await process_frame
	for node_name in [
		"DisplayModeOption",
		"ResolutionOption",
		"VsyncCheck",
		"RestoreDisplayDefaultsButton",
		"ApplyDisplayButton",
	]:
		var control: Control = layer.get_node("%%%s" % node_name)
		_assert_rect_inside(
			control.get_global_rect(),
			overlay_rect,
			node_name,
			viewport_size
		)

	layer._show_accessibility_page(false)
	await process_frame
	for node_name in [
		"ReduceFlashesCheck",
		"DisableDistortionCheck",
		"ResolutionSpeedOption",
		"UiScaleOption",
		"RestoreAccessibilityDefaultsButton",
	]:
		var control: Control = layer.get_node("%%%s" % node_name)
		_assert_rect_inside(
			control.get_global_rect(),
			overlay_rect,
			node_name,
			viewport_size
		)

	var confirmation: Control = layer.get_node("%DisplayConfirmationLayer")
	confirmation.visible = true
	await process_frame
	_assert_true(
		confirmation.get_global_rect() == overlay_rect,
		"confirmation should cover settings at %s" % viewport_size
	)
	confirmation.visible = false
	layer.close_settings()
	layer.open_rule_reference()
	await process_frame
	var rule_overlay: Control = layer.get_node("%RuleReferenceOverlay")
	var rule_overlay_rect := rule_overlay.get_global_rect()
	_assert_true(
		rule_overlay_rect == overlay_rect,
		"rule reference should cover the viewport at %s" % viewport_size
	)
	for node_name in [
		"CloseRuleReferenceButton",
		"Archive01Button",
		"Archive02Button",
		"Archive03Button",
		"Archive04Button",
		"Archive05Button",
		"Archive06Button",
		"Rule01Button",
		"Rule02Button",
		"Rule03Button",
		"ArchiveContextLabel",
		"ArchiveSummaryLabel",
		"RuleDetailTitle",
		"RuleDetailFormula",
		"RuleDetailDescription",
		"RuleDetailMetrics",
		"RuleDetailTiming",
	]:
		var control: Control = rule_overlay.get_node("%%%s" % node_name)
		_assert_rect_inside(
			control.get_global_rect(),
			rule_overlay_rect,
			node_name,
			viewport_size
		)
	var spine: Control = rule_overlay.get_node(
		"SafeArea/GlassPanel/MainMargin/MainColumn/Content/ArchiveSpinePanel"
	)
	var index: Control = rule_overlay.get_node(
		"SafeArea/GlassPanel/MainMargin/MainColumn/Content/RuleIndexPanel"
	)
	var detail: Control = rule_overlay.get_node(
		"SafeArea/GlassPanel/MainMargin/MainColumn/Content/DetailPanel"
	)
	_assert_true(
		spine.get_global_rect().end.x < index.get_global_rect().position.x,
		"archive spine and rule index should not overlap at %s" % viewport_size
	)
	_assert_true(
		index.get_global_rect().end.x < detail.get_global_rect().position.x,
		"rule index and detail should not overlap at %s" % viewport_size
	)
	layer.close_rule_reference()
	layer.free()
	test_viewport.free()
	await process_frame

func _install_test_services() -> void:
	temporary_settings_path = "%s/project-joker-settings-layout-%d.cfg" % [
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

func _assert_inside_viewport(
	rect: Rect2,
	viewport_size: Vector2i,
	name: String,
	context_size: Vector2i
) -> void:
	_assert_rect_inside(
		rect,
		Rect2(Vector2.ZERO, Vector2(viewport_size)),
		name,
		context_size
	)

func _assert_rect_inside(
	rect: Rect2,
	parent_rect: Rect2,
	name: String,
	context_size: Vector2i
) -> void:
	_assert_true(
		rect.position.x >= parent_rect.position.x - 0.5
		and rect.position.y >= parent_rect.position.y - 0.5
		and rect.end.x <= parent_rect.end.x + 0.5
		and rect.end.y <= parent_rect.end.y + 0.5,
		"%s should stay inside bounds at %s: %s within %s" % [
			name,
			context_size,
			rect,
			parent_rect,
		]
	)

func _assert_true(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func _remove_settings_files(path: String) -> void:
	for candidate in [path, "%s.tmp" % path, "%s.bak" % path]:
		var absolute := ProjectSettings.globalize_path(candidate)
		if FileAccess.file_exists(absolute):
			DirAccess.remove_absolute(absolute)
