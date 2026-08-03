extends SceneTree

const LOGICAL_SIZE := Vector2i(1920, 1080)

var failures: Array[String] = []
var output_path := ""

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output_path = argument.trim_prefix("--output=")
	call_deferred("_run")

func _run() -> void:
	root.size = LOGICAL_SIZE
	root.content_scale_size = LOGICAL_SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	var guide_path := OS.get_temp_dir().path_join(
		"project-joker-gold-guide-chrome-%d.cfg" % Time.get_ticks_usec()
	)
	DirAccess.remove_absolute(guide_path)
	var screen: GoldCorridorRunScreen = load(
		"res://scenes/run/gold_corridor_run_screen.tscn"
	).instantiate()
	screen.guide_config_path = guide_path
	root.add_child(screen)
	await _settle()

	var overlay: IronAbacusGuideOverlay = screen.get_node(
		"%GoldCorridorGuideOverlay"
	)
	var navigation_bar: Control = screen.get_node("NavigationBar")
	var settings_layer: SettingsLayer = screen.get_node("%SettingsLayer")
	_assert_true(overlay.is_open(), "route guide should open")
	_assert_false(
		navigation_bar.visible,
		"route guide should hide the navigation chrome that covered its title"
	)
	_assert_false(
		settings_layer.get_node("%SettingsButton").visible,
		"route guide should hide the settings entry"
	)
	_assert_false(
		settings_layer.get_node("%RuleReferenceButton").visible,
		"route guide should hide the rule-reference entry"
	)
	var card: Control = overlay.get_node("%GuideCard")
	for label_name in ["GuideProgress", "GuideTitle", "GuideInstruction"]:
		var label: Label = overlay.get_node("%" + label_name)
		_assert_true(
			label.visible and card.get_global_rect().encloses(label.get_global_rect()),
			"%s should remain fully visible inside the route guide" % label_name
		)
	await _capture_if_requested()

	overlay.acknowledge_current()
	await _settle()
	_assert_true(navigation_bar.visible, "closing the guide should restore navigation")
	_assert_true(
		settings_layer.get_node("%SettingsButton").visible,
		"closing the guide should restore the settings entry"
	)
	_assert_true(
		settings_layer.get_node("%RuleReferenceButton").visible,
		"closing the guide should restore the rule-reference entry"
	)

	screen.queue_free()
	await process_frame
	DirAccess.remove_absolute(guide_path)
	if failures.is_empty():
		print("PASS gold_corridor_guide_chrome_layout_self_check")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _settle() -> void:
	await process_frame
	await process_frame
	await process_frame

func _capture_if_requested() -> void:
	if output_path.is_empty():
		return
	RenderingServer.force_draw(false)
	await process_frame
	var image := root.get_texture().get_image()
	if image == null or image.save_png(output_path) != OK:
		failures.append("route guide chrome capture should be writable")

func _assert_true(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func _assert_false(value: bool, message: String) -> void:
	_assert_true(not value, message)
