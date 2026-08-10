extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	for viewport_size in [Vector2i(1920, 1080), Vector2i(1280, 720)]:
		root.content_scale_size = viewport_size
		root.size = viewport_size
		await _check_main_menu(viewport_size)
		await _check_custom_setup(viewport_size)
		await _check_archive(viewport_size)
		await _check_special_room_panel(viewport_size)
	_finish()

func _check_main_menu(viewport_size: Vector2i) -> void:
	var screen: Control = load("res://scenes/run/main_menu_screen.tscn").instantiate()
	root.add_child(screen)
	await _settle()
	for node_name in [
		"DailyChallengeButton", "CustomExpeditionButton", "AchievementArchiveButton",
	]:
		_assert_inside(screen.get_node("%" + node_name), viewport_size, "main menu " + node_name)
	var safe_area: Control = screen.get_node("SafeArea")
	var content: Control = screen.get_node("SafeArea/Content")
	_assert_encloses(safe_area, content, "main menu content at %s" % viewport_size)
	screen.queue_free()
	await process_frame

func _check_custom_setup(viewport_size: Vector2i) -> void:
	var screen: Control = load("res://scenes/run/custom_expedition_setup_screen.tscn").instantiate()
	root.add_child(screen)
	await _settle()
	for node_name in [
		"DeckOption", "AreaCountOption", "TargetMultiplierOption", "DecorationOption",
		"CustomSetupSummary",
		"ReturnButton", "ContinueCustomButton", "StartCustomButton",
	]:
		_assert_inside(screen.get_node("%" + node_name), viewport_size, "custom " + node_name)
	var scroll: ScrollContainer = screen.get_node("SafeArea/Content/Scroll")
	_assert_inside(scroll, viewport_size, "custom scroll")
	_assert_true(scroll.size.y >= 200.0, "custom choices retain a usable scroll area at %s" % viewport_size)
	screen.queue_free()
	await process_frame

func _check_archive(viewport_size: Vector2i) -> void:
	var screen: Control = load("res://scenes/run/achievement_archive_screen.tscn").instantiate()
	root.add_child(screen)
	await _settle()
	_assert_inside(screen.get_node("Margin/Content/Scroll"), viewport_size, "achievement scroll")
	_assert_inside(screen.get_node("%ReturnButton"), viewport_size, "achievement return")
	_assert_equal(
		screen.get_node("%AchievementList").get_child_count(),
		AchievementCatalog.new().ids().size(),
		"archive keeps twelve rows at %s" % viewport_size
	)
	screen.queue_free()
	await process_frame

func _check_special_room_panel(viewport_size: Vector2i) -> void:
	var panel: Control = load("res://scenes/components/area_event_panel.tscn").instantiate()
	root.add_child(panel)
	await _settle()
	var area := AreaRunSession.new(20260810, AreaCatalog.new().faceless_hub())
	_assert_true(area.start().accepted, "special panel fixture starts")
	area.flow_cursor = 2
	area.phase = AreaRunSession.Phase.CHOICE_ROOM
	panel.bind_choice_room(area)
	await _settle()
	_assert_inside(panel.get_node("Center/Panel"), viewport_size, "special room panel")
	_assert_inside(panel.get_node("%EventOptions"), viewport_size, "special room options")
	_assert_true(
		panel.get_node("%EventOptions").get_child_count() >= 3,
		"choice room exposes all contract options at %s" % viewport_size
	)
	panel.queue_free()
	await process_frame

func _assert_inside(control: Control, viewport_size: Vector2i, label: String) -> void:
	var rect := control.get_global_rect()
	var bounds := Rect2(Vector2.ZERO, Vector2(viewport_size))
	if not bounds.encloses(rect) or rect.size.x <= 0.0 or rect.size.y <= 0.0:
		failures.append("%s leaves %s; rect=%s" % [label, viewport_size, rect])

func _assert_encloses(outer: Control, inner: Control, label: String) -> void:
	if not outer.get_global_rect().encloses(inner.get_global_rect()):
		failures.append("%s overflows; outer=%s inner=%s" % [
			label, outer.get_global_rect(), inner.get_global_rect(),
		])

func _assert_true(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		failures.append("%s; expected=%s actual=%s" % [message, expected, actual])

func _settle() -> void:
	await process_frame
	await process_frame
	await process_frame

func _finish() -> void:
	if failures.is_empty():
		print("PASS phase_three_layout_self_check")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
