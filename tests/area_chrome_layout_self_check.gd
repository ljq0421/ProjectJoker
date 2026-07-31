extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.content_scale_factor = 1.0
	root.size = Vector2i(1920, 1080)
	var screen: Control = load(
		"res://scenes/run/area_run_screen.tscn"
	).instantiate()
	root.add_child(screen)
	await _settle()
	var home: Control = screen.get_node("%HomeButton")
	var encounter_title: Control = screen.get_node(
		"EncounterScreen/SafeArea/RootColumn/TopBar/AreaLabel"
	)
	_assert_no_overlap(home, encounter_title, "encounter title")

	var shop: Control = screen.get_node("%ShopScreen")
	shop.visible = true
	await _settle()
	var shop_title: Control = shop.get_node("SafeArea/RootColumn/Header/Title")
	_assert_no_overlap(home, shop_title, "shop title")
	_assert_inside(home, Rect2(Vector2.ZERO, Vector2(root.size)), "home button")

	screen.free()
	if failures.is_empty():
		print("PASS area_chrome_layout_self_check")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _assert_no_overlap(first: Control, second: Control, label: String) -> void:
	if first.get_global_rect().intersects(second.get_global_rect()):
		failures.append(
			"home button overlaps %s: %s vs %s"
			% [label, first.get_global_rect(), second.get_global_rect()]
		)

func _assert_inside(control: Control, bounds: Rect2, label: String) -> void:
	var rect := control.get_global_rect()
	if (
		rect.position.x < bounds.position.x
		or rect.position.y < bounds.position.y
		or rect.end.x > bounds.end.x
		or rect.end.y > bounds.end.y
	):
		failures.append("%s leaves viewport: %s" % [label, rect])

func _settle() -> void:
	await process_frame
	await process_frame
	await process_frame
