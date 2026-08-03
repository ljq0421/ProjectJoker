extends "res://tests/test_case.gd"

const EXPECTED_CUES: Array[StringName] = [
	&"ui_confirm",
	&"ui_back",
	&"panel_open",
	&"panel_close",
	&"page_transition",
	&"die_select",
	&"die_place",
	&"die_return",
	&"card_select",
	&"card_play",
	&"calibrate_up",
	&"calibrate_down",
	&"undo",
	&"route_select",
	&"shop_purchase",
	&"engraving_select",
	&"engraving_install",
	&"round_commit",
	&"resolution_tick",
	&"resolution_impact",
	&"resolution_climax",
	&"round_success",
	&"round_failure",
	&"area_complete",
	&"error",
]

func run() -> void:
	var service_script := load("res://scripts/audio/sfx_service.gd")
	assert_true(service_script != null, "SFX service script should load")
	if service_script == null:
		return

	var service: Node = service_script.new()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(service)

	var registered: Array[StringName] = service.registered_cue_ids()
	assert_equal(registered.size(), EXPECTED_CUES.size(), "cue count should stay stable")
	for cue_id in EXPECTED_CUES:
		assert_true(cue_id in registered, "missing semantic cue %s" % cue_id)
		var cue: Dictionary = service.cue_definition(cue_id)
		assert_true(cue.get("stream") is AudioStreamWAV, "%s should load WAV" % cue_id)
		assert_true(
			cue.get("bus") in [&"UI", &"Gameplay"],
			"%s should target an approved bus" % cue_id
		)

	assert_equal(service.player_pool_size(), 12, "service should own 12 players")
	assert_true(AudioServer.get_bus_index(&"SFX") >= 0, "SFX bus should exist")
	assert_true(AudioServer.get_bus_index(&"UI") >= 0, "UI bus should exist")
	assert_true(
		AudioServer.get_bus_index(&"Gameplay") >= 0,
		"Gameplay bus should exist"
	)

	var started: Array[StringName] = []
	service.cue_started.connect(
		func(cue_id: StringName, _bus_name: StringName) -> void:
			started.append(cue_id)
	)
	assert_true(service.play(&"ui_confirm"), "first UI cue should start")
	assert_true(
		not service.play(&"ui_confirm"),
		"immediate duplicate UI cue should respect cooldown"
	)
	assert_true(service.play(&"die_select"), "rapid gameplay cue should start")
	assert_true(service.play(&"die_select"), "gameplay cue should allow overlap")
	assert_equal(
		started,
		[&"ui_confirm", &"die_select", &"die_select"],
		"cue_started should report only accepted playback"
	)
	assert_true(
		not service.play(&"unknown_cue"),
		"unknown cue should fail without throwing"
	)
	assert_true(
		service.uses_independent_pitch_rng(),
		"pitch variation must use a service-local RNG"
	)

	service.free()
