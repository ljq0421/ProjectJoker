extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await _change_and_check(
		"res://scenes/run/main_menu_screen.tscn",
		&"menu"
	)
	await _change_and_check(
		"res://scenes/run/rule_archive_screen.tscn",
		&"journey"
	)
	await _change_and_check(
		"res://scenes/run/single_encounter_screen.tscn",
		&"encounter"
	)
	await _change_and_check(
		"res://scenes/run/gold_corridor_run_screen.tscn",
		&"journey"
	)
	var area_screen := current_scene
	if area_screen != null:
		var area_session = area_screen.get("area_session")
		if area_session == null:
			failures.append("Gold Corridor did not create an area session")
		else:
			area_screen.call(
				"_on_route_selected",
				area_session.current_route_ids()[0]
			)
			await _settle()
			_assert_track(
				&"encounter",
				"Gold Corridor route selection"
			)
	if failures.is_empty():
		print("PASS music_runtime_self_check")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _change_and_check(scene_path: String, expected_track: StringName) -> void:
	var error := change_scene_to_file(scene_path)
	if error != OK:
		failures.append("failed to change scene: %s" % scene_path)
		return
	for _frame in range(20):
		await process_frame
		await create_timer(0.02).timeout
	_assert_track(expected_track, scene_path)

func _assert_track(expected_track: StringName, context: String) -> void:
	var service := root.get_node_or_null("MusicService")
	if service == null:
		failures.append("MusicService autoload is missing")
		return
	if service.current_track_id() != expected_track:
		failures.append(
			"%s expected %s but heard %s"
			% [context, expected_track, service.current_track_id()]
		)
	if not service.is_playing():
		failures.append("%s did not start music playback" % context)

func _settle() -> void:
	for _frame in range(20):
		await process_frame
		await create_timer(0.02).timeout
