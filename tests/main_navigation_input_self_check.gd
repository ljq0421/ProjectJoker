extends SceneTree

var _failed := false
var _pointer_position := Vector2.ZERO

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	change_scene_to_file("res://scenes/run/main_menu_screen.tscn")
	await _settle()
	for route in [
		{
			"button": "GoldCorridorButton",
			"screen": GoldCorridorRunScreen,
		},
		{
			"button": "MirrorHallButton",
			"screen": MirrorHallRunScreen,
		},
		{
			"button": "FacelessHubButton",
			"screen": FacelessHubRunScreen,
		},
	]:
		var menu := current_scene
		_assert(
			menu != null
			and menu.scene_file_path == "res://scenes/run/main_menu_screen.tscn",
			"main menu should be current before opening a route"
		)
		if menu == null:
			break
		var entry_button := menu.get_node("%" + route.button) as Button
		await _click(entry_button)
		await _settle()
		var area := current_scene as AreaRunScreen
		_assert(
			area != null and is_instance_of(area, route.screen),
			"%s should open its requested area" % route.button
		)
		if area == null:
			break
		await _click(area.get_node("%HomeButton") as Button)
		await _settle()
		_assert(
			current_scene != null
			and current_scene.scene_file_path == "res://scenes/run/main_menu_screen.tscn",
			"HomeButton should return each area to the main menu"
		)

	if _failed:
		quit(1)
	else:
		print("MAIN NAVIGATION INPUT SELF CHECK PASSED")
		quit(0)

func _settle() -> void:
	await process_frame
	await process_frame
	await process_frame

func _click(control: Control) -> void:
	_assert(control != null, "navigation click target should exist")
	if control == null:
		return
	var point := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.relative = point - _pointer_position
	root.push_input(motion, true)
	_pointer_position = point
	await process_frame
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

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
