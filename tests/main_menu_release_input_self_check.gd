extends SceneTree

var failures: Array[String] = []
var menu: MainMenuScreen

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	menu = load("res://scenes/run/main_menu_screen.tscn").instantiate()
	menu.expedition_save_path = "user://release-menu-input-expedition.cfg"
	menu.tutorial_config_path = "user://release-menu-input-onboarding.cfg"
	root.add_child(menu)
	await _settle()

	_assert_equal(
		menu.get_node("%VersionLabel").text,
		"Demo v0.1.0-demo.1",
		"main menu should bind the project version"
	)
	menu.get_node("%CreditsButton").emit_signal("pressed")
	await _settle()
	var overlay: Control = menu.get_node("%CreditsOverlay")
	var credits: TextEdit = menu.get_node("%CreditsText")
	_assert_true(overlay.visible, "credits button should open the credits overlay")
	_assert_true(
		"独立开发版本 · 开发者暂不公开" in credits.text,
		"credits should preserve private developer attribution"
	)
	_assert_true(
		"Permission is hereby granted" in credits.text,
		"credits should include the Godot MIT license text"
	)
	_assert_true(
		"Godot bundled third-party license texts" in credits.text,
		"credits should include bundled third-party license texts"
	)

	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	menu._unhandled_input(escape)
	await _settle()
	_assert_false(overlay.visible, "Escape should close the credits overlay")

	menu.get_node("%QuitButton").emit_signal("pressed")
	await _settle()
	_assert_true(
		menu.get_node("%QuitGameDialog").visible,
		"quit button should require explicit confirmation"
	)
	menu.get_node("%QuitGameDialog").hide()
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

func _assert_false(value: bool, message: String) -> void:
	_assert_true(not value, message)

func _finish() -> void:
	if failures.is_empty():
		print("PASS main_menu_release_input_self_check")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
