extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var screen: SingleEncounterScreen = load(
		"res://scenes/run/single_encounter_screen.tscn"
	).instantiate()
	screen.tutorial_auto_start = false
	screen.tutorial_config_path = OS.get_temp_dir().path_join(
		"project-joker-tutorial-layout-%d.cfg" % Time.get_ticks_usec()
	)
	root.add_child(screen)
	await process_frame
	await process_frame
	screen.start_tutorial_replay()
	await process_frame
	await process_frame

	var tutorial: Control = screen.get_node("%SingleEncounterTutorial")
	var callout: Control = tutorial.get_node("%TutorialCallout")
	var replay: Control = screen.get_node("%ReplayTutorialButton")
	_assert_true(tutorial.visible, "replay should show tutorial")
	_assert_inside(screen.get_rect(), callout.get_global_rect(), "tutorial callout")
	_assert_inside(screen.get_rect(), replay.get_global_rect(), "replay button")
	_assert_true(
		tutorial.get_node("%FocusRings").get_child_count() >= 3,
		"welcome should focus the three lanes and resolution panel"
	)

	var path := screen.tutorial_config_path
	screen.queue_free()
	await process_frame
	DirAccess.remove_absolute(path)
	if failures.is_empty():
		print("PASS tutorial_layout_self_check")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _assert_inside(parent_rect: Rect2, child_rect: Rect2, label: String) -> void:
	_assert_true(parent_rect.encloses(child_rect), "%s must remain inside root" % label)

func _assert_true(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
