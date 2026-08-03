extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var menu: MainMenuScreen = load(
		"res://scenes/run/main_menu_screen.tscn"
	).instantiate()
	menu.expedition_save_path = "user://main-menu-layout-expedition.cfg"
	menu.tutorial_config_path = "user://main-menu-layout-onboarding.cfg"
	root.add_child(menu)
	await _settle()
	var grid: GridContainer = menu.get_node("SafeArea/Content/RouteGrid")
	var cards: Array[Control] = []
	for child in grid.get_children():
		if child is PanelContainer:
			cards.append(child)
	_assert_equal(cards.size(), 3, "practice row should contain three region cards")
	for card in cards:
		_assert_true(
			card.size.x >= 480.0,
			"practice card should use one third of the available row; width=%s" % card.size.x
		)
	_assert_true(
		grid.get_global_rect().encloses(cards[-1].get_global_rect()),
		"the final practice card should remain inside the full-width grid"
	)
	var safe_area: Control = menu.get_node("SafeArea")
	var footer: Control = menu.get_node("SafeArea/Content/ReleaseFooter")
	_assert_true(
		safe_area.get_global_rect().encloses(footer.get_global_rect()),
		"release footer should remain inside the main-menu safe area"
	)
	menu.queue_free()
	await process_frame
	_finish()

func _settle() -> void:
	await process_frame
	await process_frame
	await process_frame

func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	_assert_true(actual == expected, "%s; expected=%s actual=%s" % [message, expected, actual])

func _assert_true(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func _finish() -> void:
	if failures.is_empty():
		print("PASS main_menu_layout_self_check")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
