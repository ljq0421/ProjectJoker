extends "res://tests/test_case.gd"

const CARD_SCENE := preload("res://scenes/components/card_token.tscn")
const DIE_SCENE := preload("res://scenes/components/die_token.tscn")
const PANEL_SCENE := preload("res://scenes/components/resolution_panel.tscn")
const ENCOUNTER_SCENE := preload("res://scenes/run/single_encounter_screen.tscn")


func run() -> void:
	_test_token_motion_contracts()
	_test_die_motion_keeps_square_aspect()
	_test_resolution_emphasis_contract()
	_test_encounter_motion_layer_contract()
	_test_response_sequence_and_climax_contract()
	_test_refresh_preserves_interaction_identity()
	_test_die_transition_has_one_visible_instance()
	_test_die_arrival_does_not_replay_local_motion()


func _test_token_motion_contracts() -> void:
	var card = CARD_SCENE.instantiate()
	var die = DIE_SCENE.instantiate()
	assert_true(
		card.has_method("set_motion_reduced"),
		"card token should expose reduced-motion policy"
	)
	assert_true(
		card.has_method("play_commit_feedback"),
		"card token should expose a committed-play beat"
	)
	assert_true(
		die.has_method("set_motion_reduced"),
		"die token should expose reduced-motion policy"
	)
	assert_true(
		die.has_method("play_landing_feedback"),
		"die token should expose a landing beat"
	)
	assert_true(
		die.has_method("play_return_feedback"),
		"die token should expose a return beat"
	)
	card.free()
	die.free()


func _test_die_motion_keeps_square_aspect() -> void:
	var die: DieToken = DIE_SCENE.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(die)
	die.bind_die(DieState.new(&"d5", 5), false)
	die.play_landing_feedback()
	assert_true(
		is_equal_approx(die.scale.x, die.scale.y),
		"die landing feedback must keep the face square"
	)
	die.play_return_feedback()
	assert_true(
		is_equal_approx(die.scale.x, die.scale.y),
		"die return feedback must keep the face square"
	)
	var layer_source := FileAccess.get_file_as_string(
		"res://scripts/ui/interaction_motion_layer.gd"
	)
	assert_false(
		layer_source.contains('Vector2(1.08, 0.9)'),
		"the die flight contact beat must use uniform scale"
	)
	die.free()


func _test_resolution_emphasis_contract() -> void:
	var panel = PANEL_SCENE.instantiate()
	var normal := ResolutionEvent.new(&"left", "左侧规则台", 3, 3)
	var muted := ResolutionEvent.new(&"dealer", "庄家规则未触发", 0, 3, false)
	var impact := ResolutionEvent.new(&"bridge", "桥接手法", 12, 15)
	assert_true(
		panel.has_method("event_emphasis_for"),
		"resolution panel should classify event emphasis"
	)
	if panel.has_method("event_emphasis_for"):
		assert_equal(
			panel.event_emphasis_for(muted, 0, 3),
			&"muted",
			"non-applied events should stay visually quiet"
		)
		assert_equal(
			panel.event_emphasis_for(normal, 0, 3),
			&"standard",
			"ordinary applied events should use standard emphasis"
		)
		assert_equal(
			panel.event_emphasis_for(impact, 1, 3),
			&"impact",
			"large deltas should receive impact emphasis"
		)
		assert_equal(
			panel.event_emphasis_for(normal, 2, 3),
			&"standard",
			"the final event should remain ordinary so the total gets its own climax"
		)
		assert_equal(
			panel.sfx_cue_for_emphasis(&"standard"),
			&"resolution_tick",
			"ordinary score beats should use the light resolution cue"
		)
		assert_equal(
			panel.sfx_cue_for_emphasis(&"impact"),
			&"resolution_impact",
			"large score beats should use the impact cue"
		)
		assert_equal(
			panel.sfx_cue_for_emphasis(&"climax"),
			&"resolution_climax",
			"the final score beat should use the climax cue"
		)
	panel.free()


func _test_encounter_motion_layer_contract() -> void:
	var screen = ENCOUNTER_SCENE.instantiate()
	assert_true(
		screen.get_node_or_null("%InteractionMotionLayer") != null,
		"encounter screen should own a dedicated motion layer"
	)
	if screen.get_node_or_null("%InteractionMotionLayer") != null:
		var layer = screen.get_node("%InteractionMotionLayer")
		assert_true(
			layer.has_method("fly_die"),
			"motion layer should animate a die between gameplay regions"
		)
		assert_true(
			layer.has_method("fly_card"),
			"motion layer should animate committed cards toward their target"
		)
		assert_true(
			layer.has_method("pulse_target"),
			"motion layer should animate the affected rule target"
		)
	screen.free()


func _test_response_sequence_and_climax_contract() -> void:
	var screen: SingleEncounterScreen = ENCOUNTER_SCENE.instantiate()
	screen.tutorial_auto_start = false
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(screen)
	var layer: InteractionMotionLayer = screen.get_node("%InteractionMotionLayer")
	assert_true(
		layer.has_method("play_response_sequence"),
		"motion layer should sequence source, affected object, rule, and prediction"
	)
	if layer.has_method("play_response_sequence"):
		layer.play_response_sequence([
			{"role": &"source", "target": screen.get_node("%Hand")},
			{"role": &"affected", "target": screen.get_node("%DiceTray")},
			{"role": &"rule", "target": screen.get_node("%MiddleLane")},
			{
				"role": &"prediction",
				"target": screen.resolution_panel.get_node("%Total"),
			},
		])
		assert_equal(
			layer.get_meta("last_response_sequence", []),
			[&"source", &"affected", &"rule", &"prediction"],
			"response feedback should preserve the four-stage semantic order"
		)
		layer._pulse_response_stage(
			screen.get_node("%Hand").get_instance_id(),
			&"source"
		)
		assert_true(
			layer.get_node_or_null("ResponsePulse_source") != null,
			"each response stage should draw a visible spatial pulse ring"
		)
		layer._pulse_response_stage(
			screen.get_node("%MiddleLane").get_instance_id(),
			&"rule"
		)
		var rule_pulse := layer.get_node_or_null("ResponsePulse_rule") as Panel
		assert_true(
			rule_pulse != null
			and rule_pulse.get_node_or_null("ResponseBadge") != null
			and "规则台已响应" in rule_pulse.get_node("ResponseBadge").text,
			"the full-lane response should carry a prominent in-lane status badge"
		)
		if rule_pulse != null:
			var rule_style := rule_pulse.get_theme_stylebox("panel") as StyleBoxFlat
			assert_true(
				rule_style != null
				and rule_style.get_border_width(SIDE_LEFT) >= 8,
				"the full-lane response should use a clearly visible luminous border"
			)
	screen.free()


func _test_refresh_preserves_interaction_identity() -> void:
	var screen: SingleEncounterScreen = ENCOUNTER_SCENE.instantiate()
	screen.tutorial_auto_start = false
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(screen)
	var first_card: CardToken = screen.get_node("%Hand").get_child(0)
	var first_die: DieToken = screen.get_node("%DiceTray").get_child(0)
	var card_instance_id := first_card.get_instance_id()
	var die_instance_id := first_die.get_instance_id()
	screen.refresh_from_session()
	assert_equal(
		screen.get_node("%Hand").get_child(0).get_instance_id(),
		card_instance_id,
		"refresh should preserve hand-card identity for continuous motion"
	)
	assert_equal(
		screen.get_node("%DiceTray").get_child(0).get_instance_id(),
		die_instance_id,
		"refresh should preserve tray-die identity for continuous motion"
	)
	screen.free()


func _test_die_transition_has_one_visible_instance() -> void:
	var screen: SingleEncounterScreen = ENCOUNTER_SCENE.instantiate()
	screen.tutorial_auto_start = false
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(screen)
	var capture: Dictionary = screen._capture_die_motion(&"d5")
	assert_true(
		screen.session.assign_dropped_die_to_slot(&"d5", &"middle", 1),
		"motion fixture should assign d5 to the middle slot"
	)
	screen.refresh_from_session()
	screen._complete_die_transition(capture, &"d5", false)
	var target: DieToken = screen._find_die_token(&"d5")
	assert_true(target != null, "assigned die should exist at its destination")
	if target != null:
		assert_equal(
			target.modulate.a,
			0.0,
			"the destination die should stay hidden while its flight ghost is visible"
		)
	var motion_layer: Control = screen.get_node("%InteractionMotionLayer")
	assert_equal(
		motion_layer.get_child_count(),
		1,
		"a die transition should render exactly one flight ghost"
	)
	screen.free()


func _test_die_arrival_does_not_replay_local_motion() -> void:
	var screen: SingleEncounterScreen = ENCOUNTER_SCENE.instantiate()
	screen.tutorial_auto_start = false
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(screen)
	var target: DieToken = screen._find_die_token(&"d5")
	assert_true(target != null, "arrival fixture should find d5")
	if target != null:
		var hidden_modulate := target.modulate
		hidden_modulate.a = 0.0
		target.modulate = hidden_modulate
		screen._finish_die_transition(target.get_instance_id(), false)
		assert_equal(target.modulate.a, 1.0, "arrival should reveal the real die")
		assert_equal(
			target.scale,
			Vector2.ONE,
			"arrival should reveal at rest scale instead of starting a second bounce"
		)
		assert_false(
			target.has_meta("last_motion_beat"),
			"the completed flight should not replay die-local landing motion"
		)
		assert_false(
			target.has_meta("last_motion_emphasis"),
			"the completed flight should not stack a target pulse on the die"
		)
	screen.free()
