extends "res://tests/test_case.gd"

func run() -> void:
	var die = load("res://scenes/components/die_token.tscn").instantiate()
	var card = load("res://scenes/components/card_token.tscn").instantiate()
	var lane = load("res://scenes/components/rule_lane.tscn").instantiate()
	var panel = load("res://scenes/components/resolution_panel.tscn").instantiate()
	assert_true(die.has_signal("die_activated"), "die token should emit activation")
	assert_true(
		die.has_method("bind_die_with_engravings"),
		"die token should expose engraving binding"
	)
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
		assert_true(screen.has_method("bind_dealer"), "screen should expose dealer binding")
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
		assert_true(summary.has_signal("dealer_requested"), "summary should emit dealer entry")
		assert_true(
			summary.has_signal("dealer_retry_requested"),
			"summary should emit dealer retry"
		)
		assert_true(
			summary.has_signal("verification_retry_requested"),
			"summary should emit verification retry"
		)
		assert_true(
			summary.get_node_or_null("%ChallengeDealerButton") != null,
			"summary should expose dealer challenge button"
		)
		assert_true(
			summary.get_node_or_null("%RetryDealerButton") != null,
			"summary should expose dealer retry button"
		)
		assert_true(
			summary.get_node_or_null("%RetryVerificationButton") != null,
			"summary should expose verification retry button"
		)
		summary.free()

	var engraving_option_scene = load("res://scenes/components/engraving_option_token.tscn")
	assert_true(engraving_option_scene != null, "engraving option scene should load")
	if engraving_option_scene != null:
		var engraving_option = engraving_option_scene.instantiate()
		assert_true(
			engraving_option.has_signal("engraving_selected"),
			"engraving option should emit selection"
		)
		assert_true(
			engraving_option.has_method("bind_engraving"),
			"engraving option should bind content"
		)
		engraving_option.free()

	var reward_scene = load("res://scenes/components/engraving_reward_panel.tscn")
	assert_true(reward_scene != null, "engraving reward panel should load")
	if reward_scene != null:
		var reward = reward_scene.instantiate()
		assert_true(reward.has_method("bind_reward"), "reward panel should bind domain state")
		assert_true(reward.has_signal("install_requested"), "reward panel should request install")
		for node_name in [
			"OfferRow",
			"DieRow",
			"FaceGrid",
			"InstallEngravingButton",
			"RewardErrorLabel",
		]:
			assert_true(
				reward.get_node_or_null("%" + node_name) != null,
				"reward panel should expose %s" % node_name
			)
		reward.free()

	var shop_card_scene = load("res://scenes/components/shop_card_token.tscn")
	assert_true(shop_card_scene != null, "shop card token scene should load")
	if shop_card_scene != null:
		var shop_card = shop_card_scene.instantiate()
		assert_true(shop_card.has_method("bind_card"), "shop card should bind card content")
		assert_true(shop_card.has_signal("card_selected"), "shop card should emit selection")
		shop_card.free()

	var shop_scene = load("res://scenes/shop/shop_screen.tscn")
	assert_true(shop_scene != null, "shop screen scene should load")
	if shop_scene != null:
		var shop = shop_scene.instantiate()
		assert_true(shop.has_method("bind_session"), "shop screen should bind domain state")
		assert_true(shop.has_signal("leave_requested"), "shop should emit leave")
		shop.free()

	var three_round_scene = load("res://scenes/run/three_round_run_screen.tscn")
	assert_true(three_round_scene != null, "three round run scene should load")
	if three_round_scene != null:
		var three_round = three_round_scene.instantiate()
		assert_true(three_round.has_method("start_run"), "run screen should start a session")
		assert_true(three_round.has_method("open_shop"), "run screen should expose shop transition")
		three_round.free()

	var slice_scene = load("res://scenes/run/iron_abacus_slice_screen.tscn")
	assert_true(slice_scene != null, "Iron Abacus slice scene should load")
	if slice_scene != null:
		var slice = slice_scene.instantiate()
		assert_true(slice.has_method("start_slice"), "slice screen should start domain flow")
		assert_true(slice.has_method("bind_current_encounter"), "slice should bind encounter")
		assert_true(
			slice.get_node_or_null("%IronAbacusGuideOverlay") != null,
			"slice should own the contextual guide overlay"
		)
		slice.free()

	var gold_scene = load("res://scenes/run/gold_corridor_run_screen.tscn")
	assert_true(gold_scene != null, "Gold Corridor run scene should load")
	if gold_scene != null:
		var gold = gold_scene.instantiate()
		assert_true(gold.has_method("start_run"), "Gold Corridor should start an area run")
		assert_true(
			gold.has_method("bind_current_encounter"),
			"Gold Corridor should bind the active encounter"
		)
		for node_name in [
			"EncounterScreen",
			"ShopScreen",
			"RoundSummaryPanel",
			"RouteChoicePanel",
			"EngravingRewardPanel",
			"AreaCompletePanel",
		]:
			assert_true(
				gold.get_node_or_null("%" + node_name) != null,
				"Gold Corridor should own %s" % node_name
			)
		assert_true(
			gold.get_node_or_null("%GoldCorridorGuideOverlay") != null,
			"Gold Corridor should own the contextual guide overlay"
		)
		assert_true(
			gold.has_method("_request_guide"),
			"Gold Corridor should request guide checkpoints"
		)
		gold.free()
