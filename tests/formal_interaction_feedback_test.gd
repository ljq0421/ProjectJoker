extends "res://tests/test_case.gd"

const GOLD := Color("f5c94d")

func run() -> void:
	_test_locked_modifier_uses_gold_star()
	_test_route_copy_explains_random_position()
	_test_rule_lane_semantic_colors_and_target_precedence()
	_test_used_die_card_exposes_confirmed_target()
	_test_rule_feedback_uses_changed_complete_lanes()
	_test_rule_feedback_reports_both_sides_of_a_value_swap()

func _test_locked_modifier_uses_gold_star() -> void:
	var reveal: NarrativeCard = (
		load("res://scenes/components/narrative_card.tscn") as PackedScene
	).instantiate() as NarrativeCard
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(reveal)
	var area := AreaCatalog.new().gold_corridor()
	var modifier_id := AreaRunModifierCatalog.GOLD_STRAIGHT_GIFT
	assert_true(
		reveal.show_area_modifier_reveal(area, modifier_id, {
			&"d1": 1, &"d2": 2, &"d3": 3,
			&"d4": 4, &"d5": 5, &"d6": 6,
		}),
		"the formal reveal should accept its regional modifier"
	)
	var candidates := reveal.get_node("%ModifierCandidates") as RichTextLabel
	assert_true(candidates.visible, "modifier candidates should use their dedicated colored list")
	assert_true(
		"[color=#f5c94d]★" in candidates.text,
		"the actually locked modifier should be a bold gold starred line"
	)
	assert_true(
		"[color=#858ba3]○" in candidates.text,
		"unselected candidates should remain visually muted"
	)
	reveal.free()

func _test_route_copy_explains_random_position() -> void:
	var panel: RouteChoicePanel = load(
		"res://scenes/components/route_choice_panel.tscn"
	).instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(panel)
	var area := AreaCatalog.new().gold_corridor()
	assert_true(
		panel.bind_routes(
			area.first_route_ids,
			area,
			area.starting_deck_ids,
			CardCatalog.new()
		),
		"the formal route fixture should bind"
	)
	assert_true(
		"左右仅为本次随机摆位" in panel.get_node("%RouteInstruction").text,
		"route choice should explain that left and right have no fixed meaning"
	)
	panel.free()

func _test_rule_lane_semantic_colors_and_target_precedence() -> void:
	var lane: RuleLane = load("res://scenes/components/rule_lane.tscn").instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(lane)
	var rule := SingleEncounterFixture.make_encounter().rules[0]
	var state := SingleEncounterFixture.make_state()
	lane.bind_lane(
		rule,
		[state.find_die(&"d1"), state.find_die(&"d6")],
		load("res://scenes/components/die_token.tscn"),
		&"",
		null,
		2,
		"",
		{},
		-1,
		1,
		RuleLane.EvaluationState.FAILED
	)
	assert_equal(
		lane.self_modulate,
		RuleLane.RULE_FAILED_TINT,
		"a full failed lane should be red"
	)
	var first_slot := lane.get_node("%Slots").get_child(0) as RuleSlot
	var die_token := first_slot.get_node_or_null("DieToken") as DieToken
	assert_true(die_token != null, "the semantic lane fixture should render dice")
	if die_token != null:
		assert_equal(
			die_token.self_modulate,
			DieToken.RULE_FAILED_TINT,
			"dice in a failed collective rule should share the red state"
		)
	lane.set_target_state(true, true)
	assert_equal(
		lane.self_modulate,
		RuleLane.TARGET_TINT,
		"active legal targeting should override evaluation color"
	)
	lane.set_target_state(false, false)
	assert_equal(
		lane.self_modulate,
		RuleLane.RULE_FAILED_TINT,
		"ending targeting should restore evaluation color"
	)
	lane.set_evaluation_state(RuleLane.EvaluationState.PASSED)
	assert_equal(
		lane.self_modulate,
		RuleLane.RULE_PASSED_TINT,
		"a full passing lane should be green"
	)
	lane.set_evaluation_state(RuleLane.EvaluationState.NEUTRAL)
	assert_equal(lane.self_modulate, Color.WHITE, "an incomplete lane should stay neutral")
	lane.free()

func _test_used_die_card_exposes_confirmed_target() -> void:
	var session := SingleEncounterSession.new(
		SingleEncounterFixture.make_state(),
		SingleEncounterFixture.make_encounter(),
		SingleEncounterFixture.make_hand()
	)
	assert_true(session.activate_card(0), "the point card should select")
	assert_true(session.activate_die(&"d2"), "choosing the die should commit the card")
	assert_equal(
		session.used_card_target_copy(0),
		"已确认 · D2",
		"the used card should derive its committed target from PlayedCard"
	)
	var token: CardToken = load("res://scenes/components/card_token.tscn").instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(token)
	token.bind_card(
		0,
		session.hand[0],
		false,
		true,
		"",
		"",
		session.used_card_target_copy(0)
	)
	assert_true(token.get_node("%CommittedBadge").visible, "used cards should show the badge")
	assert_equal(
		token.get_node("%CommittedBadge").text,
		"已确认 · D2",
		"the badge should name the locked die target"
	)
	token.free()


func _test_rule_feedback_uses_changed_complete_lanes() -> void:
	var screen: SingleEncounterScreen = load(
		"res://scenes/run/single_encounter_screen.tscn"
	).instantiate()
	screen.tutorial_auto_start = false
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(screen)
	var layer: InteractionMotionLayer = screen.get_node("%InteractionMotionLayer")
	var left: RuleLane = screen.get_node("%LeftLane")

	_clear_rule_feedback_meta(layer)
	assert_true(screen.session.activate_die(&"d1"), "fixture should select d1")
	assert_true(screen.session.activate_table(&"left"), "fixture should place d1")
	screen.refresh_from_session()
	assert_equal(
		layer.get_meta("last_rule_evaluation_targets", []),
		[],
		"an incomplete changed lane should not pulse"
	)

	assert_true(screen.session.activate_die(&"d6"), "fixture should select d6")
	assert_true(screen.session.activate_table(&"left"), "fixture should complete left")
	screen.refresh_from_session()
	_assert_rule_feedback(layer, [left], [&"success"], "completing exact seven")

	_clear_rule_feedback_meta(layer)
	screen.refresh_from_session()
	assert_equal(
		layer.get_meta("last_rule_evaluation_targets", []),
		[],
		"an unchanged refresh should not replay feedback"
	)

	_clear_rule_feedback_meta(layer)
	assert_true(screen.session.activate_card(1), "coefficient card should select")
	assert_true(screen.session.activate_table(&"left"), "coefficient card should play")
	screen.refresh_from_session()
	_assert_rule_feedback(
		layer,
		[left],
		[&"success"],
		"a changed lane that stays satisfied"
	)

	_clear_rule_feedback_meta(layer)
	assert_true(screen.session.calibrate_die(&"d5", -1), "unassigned d5 should calibrate")
	screen.refresh_from_session()
	assert_equal(
		layer.get_meta("last_rule_evaluation_targets", []),
		[],
		"calibrating an unassigned die should not pulse a rule lane"
	)

	_clear_rule_feedback_meta(layer)
	assert_true(screen.session.calibrate_die(&"d1", 1), "assigned d1 should calibrate")
	screen.refresh_from_session()
	_assert_rule_feedback(layer, [left], [&"failure"], "breaking exact seven")

	_clear_rule_feedback_meta(layer)
	assert_true(screen.session.undo(), "undo should restore the assigned calibration")
	screen.refresh_from_session()
	_assert_rule_feedback(layer, [left], [&"success"], "undo restoring exact seven")
	screen.free()


func _test_rule_feedback_reports_both_sides_of_a_value_swap() -> void:
	var screen: SingleEncounterScreen = load(
		"res://scenes/run/single_encounter_screen.tscn"
	).instantiate()
	screen.tutorial_auto_start = false
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(screen)
	for assignment in [
		[&"d2", &"left"],
		[&"d5", &"left"],
		[&"d4", &"right"],
	]:
		assert_true(
			screen.session.activate_die(assignment[0]),
			"swap fixture should select %s" % assignment[0]
		)
		assert_true(
			screen.session.activate_table(assignment[1]),
			"swap fixture should place %s" % assignment[0]
		)
	screen.refresh_from_session()
	var layer: InteractionMotionLayer = screen.get_node("%InteractionMotionLayer")
	_clear_rule_feedback_meta(layer)
	var source := screen.session.controller.state.find_die(&"d2")
	var target := screen.session.controller.state.find_die(&"d4")
	var source_value := source.value
	source.value = target.value
	target.value = source_value
	screen.refresh_from_session()
	_assert_rule_feedback(
		layer,
		[screen.get_node("%LeftLane"), screen.get_node("%RightLane")],
		[&"failure", &"success"],
		"a cross-lane value swap"
	)
	screen.free()


func _clear_rule_feedback_meta(layer: InteractionMotionLayer) -> void:
	layer.set_meta("last_rule_evaluation_targets", [])
	layer.set_meta("last_rule_evaluation_tones", [])


func _assert_rule_feedback(
	layer: InteractionMotionLayer,
	targets: Array,
	tones: Array,
	context: String
) -> void:
	var expected_ids: Array[int] = []
	for target in targets:
		expected_ids.append((target as Control).get_instance_id())
	assert_equal(
		layer.get_meta("last_rule_evaluation_targets", []),
		expected_ids,
		"%s should target the changed complete lanes" % context
	)
	assert_equal(
		layer.get_meta("last_rule_evaluation_tones", []),
		tones,
		"%s should expose the semantic result" % context
	)
