extends "res://tests/test_case.gd"

const INTEL_NODES := [
	"IntelDimmer",
	"IntelLedger",
	"IntelTitle",
	"IntelSubtitle",
	"RouteMode",
	"RouteIntelPages",
	"LeftIntelName",
	"LeftIntelBody",
	"LeftIntelGoal",
	"LeftIntelReward",
	"LeftIntelSynergy",
	"LeftIntelRuleOne",
	"LeftIntelRuleTwo",
	"LeftIntelRuleThree",
	"RightIntelName",
	"RightIntelBody",
	"RightIntelGoal",
	"RightIntelReward",
	"RightIntelSynergy",
	"RightIntelRuleOne",
	"RightIntelRuleTwo",
	"RightIntelRuleThree",
	"DealerMode",
	"DealerIntelScroll",
	"DealerIntelName",
	"DealerIntelTarget",
	"DealerIntelMechanism",
	"DealerIntelSchedule",
	"DealerRoundOneTitle",
	"DealerRoundOneDirection",
	"DealerRoundOneRules",
	"DealerRoundTwoTitle",
	"DealerRoundTwoDirection",
	"DealerRoundTwoRules",
	"DealerRoundThreeTitle",
	"DealerRoundThreeDirection",
	"DealerRoundThreeRules",
	"DealerIntelRestrictions",
	"CloseIntelButton",
	"IntelErrorLabel",
]

func run() -> void:
	_test_route_brief_formatter()
	_test_intel_panel_contract()

func _test_route_brief_formatter() -> void:
	var formatter_script = load("res://scripts/ui/route_brief_formatter.gd")
	assert_true(formatter_script != null, "route brief formatter should load")
	if formatter_script == null:
		return
	var template := RuleTableTemplate.new()
	template.display_name = "区间"
	template.description = "总点数必须落在公开区间内。"
	template.condition_kind = RuleTableTemplate.ConditionKind.SUM_RANGE
	var rule := RuleDefinition.new()
	rule.display_name = "公开区间"
	rule.template = template
	rule.slot_count = 2
	rule.minimum_value = 6
	rule.maximum_value = 9
	rule.coefficient = 4
	var copy: String = formatter_script.rule_text(rule)
	assert_true("2 个骰位" in copy, "rule brief should expose slot count")
	assert_true("系数 ×4" in copy, "rule brief should expose coefficient")
	assert_true("6–9" in copy, "rule brief should expose sum range")

	template.condition_kind = RuleTableTemplate.ConditionKind.SLOT_TARGETS
	rule.slot_targets = PackedInt32Array([2, 5])
	copy = formatter_script.rule_text(rule)
	assert_true("2 / 5" in copy, "rule brief should expose slot targets")

	var area := AreaCatalog.new().gold_corridor()
	var room := area.find_room(area.first_route_ids[0])
	var names: Array[String] = formatter_script.matching_card_names(
		room,
		area.starting_deck_ids,
		CardCatalog.new()
	)
	assert_false(names.is_empty(), "route brief should find matching deck cards")
	assert_false(
		formatter_script.synergy_text(names).is_empty(),
		"route brief should format matching deck cards"
	)

func _test_intel_panel_contract() -> void:
	var packed = load("res://scenes/components/shop_intel_panel.tscn")
	assert_true(packed != null, "shop intel panel should load")
	if packed == null:
		return
	var panel = packed.instantiate()
	assert_true(panel.has_signal("closed"), "shop intel panel should emit close")
	assert_true(panel.has_method("bind_snapshot"), "shop intel panel should bind snapshots")
	assert_true(panel.has_method("close"), "shop intel panel should close")
	assert_equal(panel.anchor_right, 1.0, "intel panel should anchor full width")
	assert_equal(panel.anchor_bottom, 1.0, "intel panel should anchor full height")
	for node_name in INTEL_NODES:
		assert_true(
			panel.get_node_or_null("%" + node_name) != null,
			"intel panel should expose %s" % node_name
		)

	var tree := Engine.get_main_loop() as SceneTree
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2.ZERO
	panel.size = Vector2(1920, 1080)
	tree.root.add_child(panel)
	assert_false(panel.visible, "intel panel should begin hidden")

	var areas := AreaCatalog.new()
	var cards := CardCatalog.new()
	var dealers := DealerCatalog.new()
	var gold := areas.gold_corridor()
	assert_true(
		panel.bind_snapshot(
			ShopIntelSnapshot.routes(gold.second_route_ids),
			gold,
			gold.starting_deck_ids,
			cards,
			dealers
		),
		"route intel should bind"
	)
	assert_true(panel.visible, "route intel should show panel")
	assert_true(panel.get_node("%RouteIntelPages").visible, "route pages should show")
	assert_false(panel.get_node("%DealerIntelScroll").visible, "dealer view should hide")
	assert_false(panel.get_node("%LeftIntelBody").text.is_empty(), "left route should bind")
	assert_false(panel.get_node("%RightIntelBody").text.is_empty(), "right route should bind")
	assert_true("累计目标" in panel.get_node("%LeftIntelGoal").text, "left goal should bind")
	assert_true("成功奖励" in panel.get_node("%RightIntelReward").text, "right reward should bind")
	assert_false(panel.get_node("%LeftIntelSynergy").text.is_empty(), "synergy should bind")
	for node_name in [
		"LeftIntelRuleOne",
		"LeftIntelRuleTwo",
		"LeftIntelRuleThree",
		"RightIntelRuleOne",
		"RightIntelRuleTwo",
		"RightIntelRuleThree",
	]:
		assert_false(
			panel.get_node("%" + node_name).text.is_empty(),
			"%s should bind a public rule" % node_name
		)

	assert_true(
		panel.bind_snapshot(
			ShopIntelSnapshot.dealer(gold.dealer_id, gold.dealer_target),
			gold,
			gold.starting_deck_ids,
			cards,
			dealers
		),
		"gold dealer intel should bind"
	)
	assert_equal(panel.get_node("%DealerIntelName").text, "铁算盘", "gold dealer name")
	assert_true("150" in panel.get_node("%DealerIntelTarget").text, "gold target")
	assert_true("固定奖励" in panel.get_node("%DealerIntelMechanism").text, "gold mechanism")
	for node_name in [
		"DealerRoundOneTitle",
		"DealerRoundTwoTitle",
		"DealerRoundThreeTitle",
	]:
		assert_true(
			"固定规则" in panel.get_node("%" + node_name).text,
			"gold dealer should repeat fixed rules"
		)
	assert_true(
		"精确为 7" in panel.get_node("%DealerRoundThreeRules").text,
		"fixed dealer round should expose rule details"
	)

	var mirror := areas.mirror_hall()
	assert_true(
		panel.bind_snapshot(
			ShopIntelSnapshot.dealer(mirror.dealer_id, mirror.dealer_target),
			mirror,
			mirror.starting_deck_ids,
			cards,
			dealers
		),
		"mirror dealer intel should bind"
	)
	assert_equal(panel.get_node("%DealerIntelName").text, "镜面夫人", "mirror dealer name")
	assert_true(
		"从右向左" in panel.get_node("%DealerRoundOneDirection").text,
		"mirror direction should be public"
	)
	assert_true(
		"镜像副本" in panel.get_node("%DealerRoundOneDirection").text,
		"mirror-copy mechanism should be public"
	)

	var faceless := areas.faceless_hub()
	assert_true(
		panel.bind_snapshot(
			ShopIntelSnapshot.dealer(
				faceless.dealer_id,
				faceless.dealer_target
			),
			faceless,
			faceless.starting_deck_ids,
			cards,
			dealers
		),
		"dealer intel should bind"
	)
	assert_false(panel.get_node("%RouteIntelPages").visible, "route view should hide")
	assert_true(panel.get_node("%DealerIntelScroll").visible, "dealer view should show")
	assert_true(
		"240" in panel.get_node("%DealerIntelTarget").text,
		"dealer target should be public"
	)
	assert_true(
		"正面" in panel.get_node("%DealerRoundOneTitle").text,
		"dealer schedule should include all public rounds"
	)
	assert_true("反面" in panel.get_node("%DealerRoundTwoTitle").text, "round two should bind")
	assert_true("无面" in panel.get_node("%DealerRoundThreeTitle").text, "round three should bind")
	assert_true(
		"从右向左" in panel.get_node("%DealerRoundTwoDirection").text,
		"faceless reverse round should expose direction"
	)
	assert_true(
		"独手裁决" in panel.get_node("%DealerIntelRestrictions").text,
		"operation restriction name should be public"
	)
	assert_true(
		"最多使用 1 张" in panel.get_node("%DealerIntelRestrictions").text,
		"operation restriction description should be public"
	)
	assert_true(
		"三席到场" in panel.get_node("%DealerIntelRestrictions").text,
		"distribution restriction name should be public"
	)
	assert_true(
		"都必须至少分配 1 颗骰子" in panel.get_node("%DealerIntelRestrictions").text,
		"distribution restriction description should be public"
	)

	assert_false(
		panel.bind_snapshot(
			ShopIntelSnapshot.routes(gold.first_route_ids),
			gold,
			gold.starting_deck_ids,
			cards,
			dealers
		),
		"snapshot for the wrong route pair should fail closed"
	)
	assert_false(panel.visible, "invalid route snapshot should hide panel")
	assert_false(
		panel.bind_snapshot(
			ShopIntelSnapshot.dealer(gold.dealer_id, gold.dealer_target),
			null,
			gold.starting_deck_ids,
			cards,
			dealers
		),
		"missing area should fail closed"
	)
	var unknown_deck: Array[StringName] = gold.starting_deck_ids.duplicate()
	unknown_deck[0] = &"unknown_card"
	assert_false(
		panel.bind_snapshot(
			ShopIntelSnapshot.dealer(gold.dealer_id, gold.dealer_target),
			gold,
			unknown_deck,
			cards,
			dealers
		),
		"unknown deck card should fail closed"
	)
	assert_false(
		panel.bind_snapshot(
			ShopIntelSnapshot.dealer(mirror.dealer_id, mirror.dealer_target),
			gold,
			gold.starting_deck_ids,
			cards,
			dealers
		),
		"dealer mismatch should fail closed"
	)
	var incomplete: AreaDefinition = faceless.duplicate(true)
	incomplete.dealer_round_schedule = DealerRoundSchedule.new()
	assert_false(
		panel.bind_snapshot(
			ShopIntelSnapshot.dealer(
				incomplete.dealer_id,
				incomplete.dealer_target
			),
			incomplete,
			incomplete.starting_deck_ids,
			cards,
			dealers
		),
		"incomplete dealer schedule should fail closed"
	)

	assert_true(
		panel.bind_snapshot(
			ShopIntelSnapshot.dealer(gold.dealer_id, gold.dealer_target),
			gold,
			gold.starting_deck_ids,
			cards,
			dealers
		),
		"panel should recover after invalid data"
	)
	panel.get_node("%CloseIntelButton").emit_signal("pressed")
	assert_false(panel.visible, "close should hide intel panel")
	assert_equal(
		panel.mouse_filter,
		Control.MOUSE_FILTER_IGNORE,
		"closed intel panel should release input"
	)
	panel.free()
