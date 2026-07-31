extends "res://tests/test_case.gd"

const EXPECTED_TRACKS: Array[StringName] = [
	&"menu",
	&"journey",
	&"encounter",
]

func run() -> void:
	var service_script := load("res://scripts/audio/music_service.gd")
	assert_true(service_script != null, "music service script should load")
	if service_script == null:
		return

	var service: Node = service_script.new()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(service)

	assert_true(AudioServer.get_bus_index(&"Music") >= 0, "Music bus should exist")
	assert_equal(
		service.registered_track_ids(),
		EXPECTED_TRACKS,
		"music service should expose the three approved contexts"
	)
	for track_id in EXPECTED_TRACKS:
		var definition: Dictionary = service.track_definition(track_id)
		assert_true(
			definition.get("stream") is AudioStreamWAV,
			"%s should load a WAV stream" % track_id
		)
		assert_equal(
			definition.get("bus"),
			&"Music",
			"%s should target the Music bus" % track_id
		)

	assert_equal(
		service.context_for_scene_path(
			"res://scenes/run/main_menu_screen.tscn"
		),
		&"menu",
		"main menu should use the menu track"
	)
	assert_equal(
		service.context_for_scene_path(
			"res://scenes/shop/shop_screen.tscn"
		),
		&"journey",
		"shop should use the journey track"
	)
	assert_equal(
		service.context_for_scene_path(
			"res://scenes/run/single_encounter_screen.tscn"
		),
		&"encounter",
		"encounters should use the encounter track"
	)
	assert_equal(
		service.context_for_scene_path(
			"res://scenes/run/expedition_run_screen.tscn"
		),
		&"encounter",
		"the expedition host should sustain the encounter track"
	)
	assert_true(
		service.has_method("context_for_area_phase"),
		"music service should map embedded area phases"
	)
	if not service.has_method("context_for_area_phase"):
		service.free()
		return
	for phase_name in [
		&"route_choice",
		&"shop",
		&"engraving_reward",
		&"engraving_install",
		&"complete",
	]:
		assert_equal(
			service.context_for_area_phase(phase_name),
			&"journey",
			"%s should use journey music" % phase_name
		)
	for phase_name in [&"normal_room", &"dealer"]:
		assert_equal(
			service.context_for_area_phase(phase_name),
			&"encounter",
			"%s should use encounter music" % phase_name
		)
	assert_equal(
		service.context_for_area_phase(&"unknown"),
		&"",
		"unknown area phases should fail closed"
	)

	assert_true(
		service.play_context(&"menu", false),
		"known context should start playback"
	)
	assert_equal(service.current_track_id(), &"menu", "menu track should be active")
	assert_false(
		service.play_context(&"unknown", false),
		"unknown context should fail safely"
	)

	service.free()
