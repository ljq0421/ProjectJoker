extends "res://tests/test_case.gd"

func run() -> void:
	assert_equal(
		ProjectSettings.get_setting("application/run/main_scene"),
		"res://scenes/run/main_menu_screen.tscn",
		"project should start at the dedicated main menu"
	)
	var packed := load("res://scenes/run/main_menu_screen.tscn")
	assert_true(packed != null, "main menu scene should load")
	if packed == null:
		return
	var menu: Control = packed.instantiate()
	for node_name in [
		"PracticeButton",
		"GoldCorridorButton",
		"MirrorHallButton",
		"FacelessHubButton",
	]:
		var button := menu.get_node_or_null("%" + node_name) as Button
		assert_true(button != null, "main menu should expose %s" % node_name)
		if button != null:
			assert_false(button.text.is_empty(), "%s needs visible copy" % node_name)
	menu.free()
