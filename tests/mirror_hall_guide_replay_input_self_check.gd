extends SceneTree

var failures: Array[String] = []
var pointer_position := Vector2.ZERO

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	await _verify_normal_entry_preserves_progress()
	await _verify_replay_resets_only_mirror_guide()
	await _finish()

func _verify_normal_entry_preserves_progress() -> void:
	var path := _temporary_config_path("normal")
	_seed_config(path)
	var before := _load_section(path, MirrorHallGuideProgressStore.SECTION)
	var entry := await _open_entry(path)
	await _click(entry.get_node("%MirrorHallRunButton"))
	await _settle()
	var run_screen := current_scene as MirrorHallRunScreen
	_assert_true(run_screen != null, "mirror entry should open Mirror Hall")
	if run_screen != null:
		_assert_equal(
			run_screen.guide_config_path,
			path,
			"mirror entry should pass the configured guide path"
		)
	_assert_equal(
		_load_section(path, MirrorHallGuideProgressStore.SECTION),
		before,
		"normal mirror entry must preserve guide progress"
	)
	await _free_current_scene()
	DirAccess.remove_absolute(path)

func _verify_replay_resets_only_mirror_guide() -> void:
	var path := _temporary_config_path("replay")
	_seed_config(path)
	var gold_before := _load_section(path, "gold_corridor_guide_v1")
	var onboarding_before := _load_section(path, "onboarding")
	var entry := await _open_entry(path)
	await _click(entry.get_node("%ReplayMirrorHallGuideButton"))
	await _settle()
	var run_screen := current_scene as MirrorHallRunScreen
	_assert_true(run_screen != null, "mirror replay should open Mirror Hall")
	if run_screen != null:
		_assert_equal(
			run_screen.guide_config_path,
			path,
			"mirror replay should pass the temporary config path"
		)
	var reset_store := MirrorHallGuideProgressStore.new(path)
	_assert_false(reset_store.is_dismissed(), "mirror replay should clear dismissed")
	for checkpoint_id in [&"direction", &"mirror", &"dealer"]:
		_assert_false(
			reset_store.is_seen(checkpoint_id),
			"mirror replay should clear %s" % checkpoint_id
		)
	_assert_equal(
		_load_section(path, "gold_corridor_guide_v1"),
		gold_before,
		"mirror replay must preserve Gold Corridor guide state"
	)
	_assert_equal(
		_load_section(path, "onboarding"),
		onboarding_before,
		"mirror replay must preserve base tutorial state"
	)
	await _free_current_scene()
	DirAccess.remove_absolute(path)

func _open_entry(path: String) -> SingleEncounterScreen:
	var entry: SingleEncounterScreen = load(
		"res://scenes/run/single_encounter_screen.tscn"
	).instantiate()
	entry.tutorial_auto_start = false
	entry.tutorial_config_path = path
	root.add_child(entry)
	current_scene = entry
	await _settle()
	return entry

func _seed_config(path: String) -> void:
	DirAccess.remove_absolute(path)
	var config := ConfigFile.new()
	config.set_value("onboarding", "done", true)
	config.set_value("gold_corridor_guide_v1", "dismissed", true)
	config.set_value("gold_corridor_guide_v1", "seen_route", true)
	config.set_value(MirrorHallGuideProgressStore.SECTION, "dismissed", true)
	config.set_value(MirrorHallGuideProgressStore.SECTION, "seen_direction", true)
	config.set_value(MirrorHallGuideProgressStore.SECTION, "seen_mirror", true)
	config.set_value(MirrorHallGuideProgressStore.SECTION, "seen_dealer", true)
	_assert_equal(config.save(path), OK, "temporary guide config should save")

func _load_section(path: String, section: String) -> Dictionary:
	var config := ConfigFile.new()
	_assert_equal(config.load(path), OK, "temporary guide config should load")
	var values := {}
	if config.has_section(section):
		for key in config.get_section_keys(section):
			values[key] = config.get_value(section, key)
	return values

func _click(control: Control) -> void:
	_assert_true(control != null, "click target should exist")
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

func _free_current_scene() -> void:
	var screen := current_scene
	if is_instance_valid(screen):
		screen.queue_free()
	await process_frame
	current_scene = null

func _temporary_config_path(label: String) -> String:
	return OS.get_temp_dir().path_join(
		"project-joker-mirror-entry-%s-%d.cfg" % [label, Time.get_ticks_usec()]
	)

func _settle() -> void:
	await process_frame
	await process_frame
	await process_frame
	await process_frame

func _finish() -> void:
	if failures.is_empty():
		print("MIRROR HALL GUIDE REPLAY INPUT SELF CHECK PASSED")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _assert_true(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func _assert_false(value: bool, message: String) -> void:
	_assert_true(not value, message)

func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		failures.append("%s: expected %s, got %s" % [message, expected, actual])
