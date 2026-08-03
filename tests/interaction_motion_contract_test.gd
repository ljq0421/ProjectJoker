extends "res://tests/test_case.gd"

const CARD_SCENE := preload("res://scenes/components/card_token.tscn")
const DIE_SCENE := preload("res://scenes/components/die_token.tscn")
const PANEL_SCENE := preload("res://scenes/components/resolution_panel.tscn")
const ENCOUNTER_SCENE := preload("res://scenes/run/single_encounter_screen.tscn")


func run() -> void:
	_test_token_motion_contracts()
	_test_resolution_emphasis_contract()
	_test_encounter_motion_layer_contract()
	_test_refresh_preserves_interaction_identity()


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
			&"climax",
			"the final applied event should carry the climax"
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
