extends SceneTree

var failures: Array[String] = []
var pointer_position := Vector2.ZERO

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	change_scene_to_file("res://scenes/run/main_menu_screen.tscn")
	await _settle()
	await _click(current_scene.get_node("%RuleHandbookButton"))
	await _settle()
	var archive := current_scene as RuleArchiveScreen
	_assert_true(archive != null, "main-menu pointer click should open rule handbook")
	if archive == null:
		_finish()
		return
	var handbook := archive.handbook_panel

	await _click(handbook.get_node("%Archive06Button"))
	await _click(handbook.get_node("%PracticeArchiveButton"))
	await _settle()
	_assert_true(
		archive.current_definition.id == &"archive_06",
		"pointer click should open distortion archive"
	)
	await _complete_distortion_archive(archive)
	_assert_true(
		archive.get_node("%CompletionPanel").visible,
		"commit should open the archive completion page"
	)

	await _click(archive.get_node("%RetryPracticeButton"))
	await _settle()
	_assert_true(
		not archive.get_node("%CompletionPanel").visible
		and not archive.encounter_screen.session.controller.committed,
		"retry should rebuild the same archive without persistence"
	)
	await _click(archive.get_node("%BackToHandbookButton"))
	await _settle()
	_assert_true(
		archive.get_node("%HandbookPanel").visible,
		"encounter navigation should return to the shared handbook"
	)

	await _click(handbook.get_node("%Archive06Button"))
	await _click(handbook.get_node("%PracticeArchiveButton"))
	await _settle()
	await _complete_distortion_archive(archive)
	await _click(archive.get_node("%CompletionHandbookButton"))
	await _settle()
	_assert_true(
		archive.get_node("%HandbookPanel").visible,
		"completion page should return to the shared handbook"
	)

	await _click(handbook.get_node("%Archive06Button"))
	await _click(handbook.get_node("%PracticeArchiveButton"))
	await _settle()
	await _complete_distortion_archive(archive)
	await _click(archive.get_node("%CompletionHomeButton"))
	await _settle()
	_assert_true(
		current_scene is MainMenuScreen,
		"completion page should return to the main menu"
	)

	await _click(current_scene.get_node("%RuleHandbookButton"))
	await _settle()
	archive = current_scene as RuleArchiveScreen
	await _click(archive.handbook_panel.get_node("%CloseRuleReferenceButton"))
	await _settle()
	_assert_true(
		current_scene is MainMenuScreen,
		"rule handbook should return to the main menu"
	)

	await _click(current_scene.get_node("%RuleHandbookButton"))
	await _settle()
	archive = current_scene as RuleArchiveScreen
	await _click(archive.handbook_panel.get_node("%Archive01Button"))
	await _click(archive.handbook_panel.get_node("%PracticeArchiveButton"))
	await _settle()
	await _click(archive.get_node("%HomeButton"))
	await _settle()
	_assert_true(
		current_scene is MainMenuScreen,
		"archive encounter navigation should return to the main menu"
	)
	_finish()

func _complete_distortion_archive(archive: RuleArchiveScreen) -> void:
	var encounter := archive.encounter_screen
	for placement in [
		[&"d1", &"left", 0],
		[&"d2", &"left", 1],
		[&"d3", &"middle", 0],
		[&"d4", &"middle", 1],
		[&"d5", &"right", 0],
		[&"d6", &"right", 1],
	]:
		await _click(_find_die(encounter, placement[0]))
		await _click(_find_slot(encounter, placement[1], placement[2]))
	await _click(encounter.get_node("%ConfirmButton"))
	encounter.resolution_panel.finish_playback()
	await _settle()
	_assert_true(
		encounter.session.controller.committed,
		"real pointer assignments should complete the archive round"
	)

func _find_die(encounter: SingleEncounterScreen, die_id: StringName) -> DieToken:
	for node in encounter.find_children("*", "Button", true, false):
		if (
			node is DieToken
			and not node.is_queued_for_deletion()
			and node.die_id == die_id
		):
			return node
	return null

func _find_slot(
	encounter: SingleEncounterScreen,
	table_id: StringName,
	slot_index: int
) -> RuleSlot:
	var lane_by_id := {
		&"left": encounter.get_node("%LeftLane"),
		&"middle": encounter.get_node("%MiddleLane"),
		&"right": encounter.get_node("%RightLane"),
	}
	for node in lane_by_id[table_id].find_children("*", "Button", true, false):
		if (
			node is RuleSlot
			and not node.is_queued_for_deletion()
			and node.index == slot_index
		):
			return node
	return null

func _click(control: Control) -> void:
	_assert_true(control != null, "pointer target should exist")
	if control == null:
		return
	var point := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.relative = point - pointer_position
	root.push_input(motion, true)
	pointer_position = point
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

func _settle() -> void:
	await process_frame
	await process_frame

func _finish() -> void:
	if failures.is_empty():
		print("PASS rule_archive_input_self_check")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _assert_true(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
