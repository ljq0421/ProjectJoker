extends "res://tests/test_case.gd"

func run() -> void:
	var die = load("res://scenes/components/die_token.tscn").instantiate()
	var card = load("res://scenes/components/card_token.tscn").instantiate()
	var lane = load("res://scenes/components/rule_lane.tscn").instantiate()
	var panel = load("res://scenes/components/resolution_panel.tscn").instantiate()
	assert_true(die.has_signal("die_activated"), "die token should emit activation")
	assert_true(card.has_signal("card_activated"), "card token should emit activation")
	assert_true(lane.has_signal("lane_activated"), "lane should emit click activation")
	assert_true(lane.has_signal("die_drop_requested"), "lane should emit die drops")
	assert_true(die.has_method("set_legal_target"), "die token should expose target highlight")
	assert_true(lane.has_method("set_legal_target"), "lane should expose table target highlight")
	assert_true(lane.has_method("set_die_target_highlight"), "lane should highlight assigned dice")
	assert_true(panel.has_method("bind_report"), "resolution panel should bind reports")
	die.free()
	card.free()
	lane.free()
	panel.free()

	var screen_scene = load("res://scenes/run/single_encounter_screen.tscn")
	assert_true(screen_scene != null, "single encounter screen should load")
	if screen_scene != null:
		var screen = screen_scene.instantiate()
		assert_true(screen.has_method("refresh_from_session"), "screen should expose refresh binding")
		assert_true(
			screen.has_signal("round_committed"),
			"screen should report a newly committed round"
		)
		assert_true(
			screen.has_method("bind_external_session"),
			"screen should accept an externally owned session"
		)
		assert_true(
			screen.has_method("set_run_status"),
			"screen should expose run header binding"
		)
		screen.free()

	var tutorial_scene = load("res://scenes/components/single_encounter_tutorial.tscn")
	assert_true(tutorial_scene != null, "tutorial overlay scene should load")
	if tutorial_scene != null:
		var tutorial = tutorial_scene.instantiate()
		assert_true(tutorial.has_method("configure"), "tutorial should accept screen and store")
		assert_true(tutorial.has_method("allows"), "tutorial should guard gameplay actions")
		tutorial.free()

	var summary_scene = load("res://scenes/components/round_summary_panel.tscn")
	assert_true(summary_scene != null, "round summary scene should load")
	if summary_scene != null:
		var summary = summary_scene.instantiate()
		assert_true(summary.has_method("show_run_state"), "summary should bind run state")
		assert_true(summary.has_signal("next_round_requested"), "summary should emit next round")
		assert_true(summary.has_signal("shop_requested"), "summary should emit shop entry")
		summary.free()
