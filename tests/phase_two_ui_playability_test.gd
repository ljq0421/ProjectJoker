extends "res://tests/test_case.gd"

func run() -> void:
	_test_formal_shop_service_contract()
	_test_emergency_action_contract()
	_test_engraving_feedback_contract()
	_test_resolution_combo_feedback_contract()

func _test_formal_shop_service_contract() -> void:
	var shop_scene := load("res://scenes/shop/shop_screen.tscn")
	assert_true(shop_scene != null, "formal shop scene should load")
	if shop_scene == null:
		return
	var shop: ShopScreen = shop_scene.instantiate()
	assert_true(shop.has_signal("remove_card_requested"), "shop should request card removal")
	assert_true(
		shop.has_signal("engraving_transfer_requested"),
		"shop should request engraving transfer"
	)
	assert_true(
		shop.has_method("bind_formal_context"),
		"shop should bind formal die and engraving context"
	)
	assert_true(
		shop.has_method("refresh_from_session"),
		"shop should expose a safe public refresh"
	)
	for node_name in [
		"FormalServicePanel",
		"RemoveCardButton",
		"EngravingSourceChoice",
		"EngravingTargetChoice",
		"EngravingFaceChoice",
		"TransferEngravingButton",
	]:
		assert_true(
			shop.get_node_or_null("%%%s" % node_name) != null,
			"formal shop should expose %s" % node_name
		)
	shop.free()

func _test_emergency_action_contract() -> void:
	var screen_scene := load("res://scenes/run/single_encounter_screen.tscn")
	assert_true(screen_scene != null, "encounter scene should load")
	if screen_scene == null:
		return
	var screen: SingleEncounterScreen = screen_scene.instantiate()
	for signal_name in [
		"paid_reroll_requested",
		"paid_calibration_requested",
		"paid_retry_requested",
	]:
		assert_true(screen.has_signal(signal_name), "encounter should expose %s" % signal_name)
	assert_true(
		screen.has_method("set_formal_emergency_context"),
		"formal area should be able to bind emergency availability"
	)
	for node_name in [
		"EmergencyBar",
		"EmergencyTicketLabel",
		"PaidRerollButton",
		"PaidCalibrationButton",
		"PaidRetryButton",
		"PaidRetryConfirmationDialog",
	]:
		assert_true(
			screen.get_node_or_null("%%%s" % node_name) != null,
			"encounter should expose %s" % node_name
		)
	screen.free()

func _test_engraving_feedback_contract() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var token: DieToken = load("res://scenes/components/die_token.tscn").instantiate()
	tree.root.add_child(token)
	var catalog := EngravingCatalog.new()
	var hit := DieState.new(&"d1", 4, &"engraving_echo", 4)
	token.bind_die_with_engravings(hit, false, catalog, true, 4)
	assert_equal(
		token.get_node("%EngravingStatus").text,
		"命中",
		"an engraved face should remain a stable hit before playback focus"
	)
	token.set_engraving_playback_active(true)
	assert_equal(
		token.get_node("%EngravingStatus").text,
		"激活",
		"focused engraving playback should promote hit to active"
	)
	token.set_engraving_playback_active(false)
	assert_equal(
		token.get_node("%EngravingStatus").text,
		"命中",
		"ending focus should restore the stable hit state"
	)
	var miss := DieState.new(&"d1", 3, &"engraving_echo", 4)
	token.bind_die_with_engravings(miss, false, catalog, true, 3)
	assert_equal(
		token.get_node("%EngravingStatus").text,
		"未命中",
		"an engraved die on another face should explicitly say it missed"
	)
	token.free()

func _test_resolution_combo_feedback_contract() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var panel: ResolutionPanel = load(
		"res://scenes/components/resolution_panel.tscn"
	).instantiate()
	tree.root.add_child(panel)
	assert_true(
		panel.get_node_or_null("%EngravingTotal") != null,
		"resolution panel should expose engraving contribution separately"
	)
	var storm := ResolutionEvent.new(
		&"bridge_storm",
		"风暴结算",
		20,
		20,
		true,
		false,
		&"",
		&"",
		&"",
		ResolutionEvent.ScoreSource.RULE_CHAIN,
		&"left",
		&"right",
		&"storm"
	)
	assert_equal(
		panel.event_emphasis_for(storm, 0, 1),
		&"climax",
		"storm should always use climax emphasis"
	)
	var report := ResolutionReport.new()
	report.total = 7
	report.score_breakdown[ResolutionEvent.ScoreSource.ENGRAVING] = 7
	report.events = [storm]
	panel.bind_report(report)
	assert_true(
		panel.get_node("%EngravingTotal").text.contains("+7"),
		"engraving contribution should show its signed value"
	)
	panel.free()
