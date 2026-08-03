extends SceneTree

const MAIN_MENU_SCENE := "res://scenes/run/main_menu_screen.tscn"
const PRACTICE_SCENE := "res://scenes/run/single_encounter_screen.tscn"
const EXPEDITION_SETUP_SCENE := "res://scenes/run/expedition_setup_screen.tscn"

var _failed := false
var _pointer_position := Vector2.ZERO
var _tutorial_path := ""
var _expedition_path := ""

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	_tutorial_path = OS.get_environment("TEMP").path_join(
		"project-joker-main-menu-onboarding-%d.cfg" % Time.get_ticks_usec()
	)
	_expedition_path = OS.get_environment("TEMP").path_join(
		"project-joker-main-menu-expedition-%d.cfg" % Time.get_ticks_usec()
	)
	root.set_meta("tutorial_config_path", _tutorial_path)
	root.set_meta("expedition_save_path", _expedition_path)
	change_scene_to_file(MAIN_MENU_SCENE)
	await _settle()

	var menu := current_scene as MainMenuScreen
	_assert(menu != null, "fresh player should begin at the main menu")
	if menu == null:
		_finish()
		return
	await _click(menu.get_node("%StartExpeditionButton") as Button)
	await _settle()

	var practice := current_scene as SingleEncounterScreen
	_assert(practice != null, "fresh expedition should route through the base tutorial")
	_assert(
		practice != null and practice.scene_file_path == PRACTICE_SCENE,
		"fresh expedition should open the practice scene"
	)
	_assert(
		practice != null and practice.tutorial.active and practice.tutorial.visible,
		"fresh expedition should visibly start the tutorial"
	)
	if practice == null:
		_finish()
		return
	await _click(practice.tutorial.skip_button)
	await _settle()
	_assert(
		current_scene is ExpeditionSetupScreen
		and current_scene.scene_file_path == EXPEDITION_SETUP_SCENE,
		"skipping the first-run tutorial should continue to expedition setup"
	)
	_assert(
		TutorialProgressStore.new(_tutorial_path).is_done(),
		"tutorial skip should persist before continuing"
	)

	if current_scene is ExpeditionSetupScreen:
		await _click(current_scene.get_node("%ReturnFromSetupButton") as Button)
		await _settle()
	menu = current_scene as MainMenuScreen
	_assert(menu != null, "setup return should restore the main menu")
	if menu == null:
		_finish()
		return
	await _click(menu.get_node("%TutorialButton") as Button)
	await _settle()
	practice = current_scene as SingleEncounterScreen
	_assert(practice != null, "tutorial replay entry should open practice")
	_assert(
		practice != null and practice.tutorial.active and practice.tutorial.visible,
		"tutorial replay entry should reset and visibly restart the tutorial"
	)
	_assert(
		not TutorialProgressStore.new(_tutorial_path).is_done(),
		"tutorial replay entry should clear completed state"
	)
	if practice != null:
		await _click(practice.tutorial.skip_button)
		await _settle()
	_assert(
		current_scene is MainMenuScreen,
		"closing a manual tutorial replay should return to the main menu"
	)
	_finish()

func _settle(frames := 5) -> void:
	for _frame in range(frames):
		await process_frame

func _click(control: Control) -> void:
	_assert(control != null, "onboarding click target should exist")
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

func _finish() -> void:
	if not _tutorial_path.is_empty():
		DirAccess.remove_absolute(_tutorial_path)
	if not _expedition_path.is_empty():
		DirAccess.remove_absolute(_expedition_path)
	if _failed:
		quit(1)
	else:
		print("MAIN MENU ONBOARDING INPUT SELF CHECK PASSED")
		quit(0)
