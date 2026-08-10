extends "res://tests/test_case.gd"

const ROUTE_NODES := [
	"RouteDimmer",
	"RouteLedger",
	"RouteTitle",
	"LedgerMark",
	"LeftRouteName",
	"LeftRouteDescription",
	"LeftRouteGoal",
	"LeftRouteReward",
	"LeftRouteTags",
	"LeftRouteSynergy",
	"LeftLaneOne",
	"LeftLaneTwo",
	"LeftLaneThree",
	"LeftRouteButton",
	"RightRouteName",
	"RightRouteDescription",
	"RightRouteGoal",
	"RightRouteReward",
	"RightRouteTags",
	"RightRouteSynergy",
	"RightLaneOne",
	"RightLaneTwo",
	"RightLaneThree",
	"RightRouteButton",
	"RouteErrorLabel",
]

const COMPLETE_NODES := [
	"CompleteDimmer",
	"CompleteTitle",
	"RouteHistoryLabel",
	"ScoreHistoryLabel",
	"PurchaseHistoryLabel",
	"FinalDeckLabel",
	"FinalResourceLabel",
	"FinalEngravingLabel",
	"RestartAreaButton",
	"ReturnEntryButton",
	"CompleteErrorLabel",
]

func run() -> void:
	_test_route_panel_contract()
	_test_complete_panel_contract()

func _test_route_panel_contract() -> void:
	var packed = load("res://scenes/components/route_choice_panel.tscn")
	assert_true(packed != null, "route choice panel should load")
	if packed == null:
		return
	var panel = packed.instantiate()
	assert_true(panel.has_signal("route_selected"), "route panel should emit selection")
	assert_true(panel.has_method("bind_routes"), "route panel should bind route data")
	assert_true(panel.has_method("show_error"), "route panel should show errors")
	assert_true(panel.has_method("close"), "route panel should close")
	assert_equal(panel.anchor_right, 1.0, "route panel should anchor full width")
	assert_equal(panel.anchor_bottom, 1.0, "route panel should anchor full height")
	for node_name in ROUTE_NODES:
		assert_true(
			panel.get_node_or_null("%" + node_name) != null,
			"route panel should expose %s" % node_name
		)

	var tree := Engine.get_main_loop() as SceneTree
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2.ZERO
	panel.size = Vector2(1920, 1080)
	tree.root.add_child(panel)
	assert_false(panel.visible, "route panel should begin hidden")
	assert_equal(
		panel.mouse_filter,
		Control.MOUSE_FILTER_IGNORE,
		"hidden route panel should release input"
	)
	assert_true(
		panel.bind_routes(
			AreaCatalog.new().gold_corridor().first_route_ids,
			AreaCatalog.new().gold_corridor(),
			AreaCatalog.new().gold_corridor().starting_deck_ids,
			CardCatalog.new()
		),
		"valid routes should bind"
	)
	assert_true(panel.visible, "valid bind should show route panel")
	assert_equal(
		panel.mouse_filter,
		Control.MOUSE_FILTER_STOP,
		"visible route panel should block background input"
	)
	assert_false(panel.get_node("%LeftRouteName").text.is_empty(), "left route should bind")
	assert_false(panel.get_node("%RightRouteName").text.is_empty(), "right route should bind")
	assert_false(panel.get_node("%LeftLaneOne").text.is_empty(), "left lanes should bind")
	assert_false(panel.get_node("%RightRouteSynergy").text.is_empty(), "synergy should bind")
	assert_true(
		panel.get_node("%LeftRouteTags").text.contains("策略｜"),
		"route tags should expose the relative pressure strategy"
	)
	var strategy_copy: String = panel.get_node("%LeftRouteTags").text
	assert_true(
		strategy_copy.contains("稳健")
			or strategy_copy.contains("进阶")
			or strategy_copy.contains("高压"),
		"strategy tag should use the public three-level vocabulary"
	)
	assert_equal(
		panel.get_node("%RouteTitle").text,
		"金线回廊 · 路线账簿",
		"gold route title should use the bound area name"
	)
	assert_equal(
		panel.get_node("%LedgerMark").text,
		"区域 01 / 选路 1/2",
		"gold first route should show its actual area and route index"
	)
	assert_true(
		"单轮" in panel.get_node("%RouteInstruction").text,
		"gold route instruction should disclose the single-round contract"
	)
	var mirror_area := AreaCatalog.new().mirror_hall()
	var no_challenges: Array[StringName] = []
	assert_true(
		panel.bind_routes(
			mirror_area.first_route_ids,
			mirror_area,
			mirror_area.starting_deck_ids,
			CardCatalog.new(),
			no_challenges,
			1
		),
		"mirror routes should bind"
	)
	assert_equal(
		panel.get_node("%RouteTitle").text,
		"反照牌厅 · 路线账簿",
		"mirror route title should use the bound area name"
	)
	assert_equal(
		panel.get_node("%LedgerMark").text,
		"区域 02 / 选路 2/2",
		"mirror second route should show its actual area and route index"
	)
	assert_true(
		"三轮反照" in panel.get_node("%RouteInstruction").text,
		"mirror route instruction should disclose the reflection structure"
	)
	var faceless_area := AreaCatalog.new().faceless_hub()
	assert_true(
		panel.bind_routes(
			faceless_area.first_route_ids,
			faceless_area,
			faceless_area.starting_deck_ids,
			CardCatalog.new()
		),
		"faceless routes should bind"
	)
	assert_equal(
		panel.get_node("%RouteTitle").text,
		"无面中枢 · 路线账簿",
		"faceless route title should use the bound area name"
	)

	var selected := {"id": &""}
	panel.route_selected.connect(func(room_id: StringName) -> void: selected.id = room_id)
	panel.get_node("%LeftRouteButton").emit_signal("pressed")
	assert_true(selected.id != &"", "route button should emit stable room ID")

	var invalid_route_ids: Array[StringName] = [&"gold_room_precise_steps"]
	assert_false(
		panel.bind_routes(
			invalid_route_ids,
			AreaCatalog.new().gold_corridor(),
			CardCatalog.new().starter_ids(),
			CardCatalog.new()
		),
		"invalid route count should fail closed"
	)
	assert_false(panel.visible, "invalid route data should hide panel")
	assert_equal(
		panel.mouse_filter,
		Control.MOUSE_FILTER_IGNORE,
		"failed route bind should release input"
	)
	panel.free()

func _test_complete_panel_contract() -> void:
	var packed = load("res://scenes/components/area_complete_panel.tscn")
	assert_true(packed != null, "area complete panel should load")
	if packed == null:
		return
	var panel = packed.instantiate()
	assert_true(panel.has_signal("restart_requested"), "completion should request restart")
	assert_true(panel.has_signal("return_requested"), "completion should request return")
	assert_true(panel.has_method("bind_summary"), "completion should bind domain summary")
	assert_true(panel.has_method("show_error"), "completion should show errors")
	assert_true(panel.has_method("close"), "completion should close")
	assert_equal(panel.anchor_right, 1.0, "completion should anchor full width")
	assert_equal(panel.anchor_bottom, 1.0, "completion should anchor full height")
	for node_name in COMPLETE_NODES:
		assert_true(
			panel.get_node_or_null("%" + node_name) != null,
			"completion should expose %s" % node_name
		)

	var tree := Engine.get_main_loop() as SceneTree
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2.ZERO
	panel.size = Vector2(1920, 1080)
	tree.root.add_child(panel)
	assert_false(panel.visible, "completion should begin hidden")
	var summary := {
		"area_id": &"gold_corridor",
		"rng_state": 12345,
		"rooms": [
			{
				"room_id": &"gold_room_precise_steps",
				"target_total": 100,
				"cumulative_total": 126,
			},
			{
				"room_id": &"gold_room_parallel_proof",
				"target_total": 135,
				"cumulative_total": 148,
			},
		],
		"dealer": {
			"id": &"dealer_iron_abacus",
			"target_total": 150,
			"cumulative_total": 171,
		},
		"purchases": [
			{
				"offer_id": &"shop_deep_drop",
				"replaced_id": &"starter_nudge_up_1",
				"price": 1,
			},
			{
				"offer_id": &"shop_reverse_backup",
				"replaced_id": &"starter_map_1",
				"price": 1,
			},
		],
		"services": [
			{
				"shop_index": 0,
				"service_type": ShopServiceRecord.ServiceType.REFRESH,
				"price": 1,
				"intel_kind": -1,
			},
			{
				"shop_index": 0,
				"service_type": ShopServiceRecord.ServiceType.INTEL,
				"price": 1,
				"intel_kind": ShopIntelSnapshot.Kind.ROUTE_PAIR,
			},
			{
				"shop_index": 1,
				"service_type": ShopServiceRecord.ServiceType.REFRESH,
				"price": 1,
				"intel_kind": -1,
			},
			{
				"shop_index": 1,
				"service_type": ShopServiceRecord.ServiceType.INTEL,
				"price": 1,
				"intel_kind": ShopIntelSnapshot.Kind.DEALER,
			},
		],
		"deck_ids": _summary_deck(),
		"intel_tickets": 3,
		"engraving_id": &"engraving_anchor",
		"die_id": &"d1",
		"face": 4,
		"die_profiles": [{}, {}, {}, {}, {}, {}],
	}
	assert_true(
		panel.bind_summary(
			summary,
			AreaCatalog.new().gold_corridor(),
			CardCatalog.new(),
			DealerCatalog.new(),
			EngravingCatalog.new()
		),
		"valid summary should bind"
	)
	assert_true(panel.visible, "valid summary should show completion")
	assert_equal(
		panel.mouse_filter,
		Control.MOUSE_FILTER_STOP,
		"visible completion should block background input"
	)
	assert_true(
		panel.get_node("%RouteHistoryLabel").text.contains("精确步阶"),
		"summary should resolve room names"
	)
	assert_true(
		panel.get_node("%FinalEngravingLabel").text.contains("锚定"),
		"summary should resolve engraving name"
	)
	var transaction_text: String = panel.get_node("%PurchaseHistoryLabel").text
	assert_true("深降推码" in transaction_text, "purchase arrows should remain")
	assert_true("回转备份" in transaction_text, "second purchase should remain")
	for expected in [
		"商店 1｜整批刷新（1 情报券）",
		"商店 1｜路线情报（1 情报券）",
		"商店 2｜整批刷新（1 情报券）",
		"商店 2｜庄家情报（1 情报券）",
	]:
		assert_true(expected in transaction_text, "service row should render: %s" % expected)
	assert_equal(
		panel.get_node("%FinalResourceLabel").text,
		"剩余情报券｜3",
		"final balance should use the snapshot value directly"
	)

	var zero_services := summary.duplicate(true)
	zero_services.services = []
	assert_true(
		panel.bind_summary(
			zero_services,
			AreaCatalog.new().gold_corridor(),
			CardCatalog.new(),
			DealerCatalog.new(),
			EngravingCatalog.new()
		),
		"valid zero-service summary should bind"
	)
	assert_true(
		"本区未购买商店服务" in panel.get_node("%PurchaseHistoryLabel").text,
		"zero-service summary should say no services were purchased"
	)

	var invalid_service_cases: Array[Dictionary] = []
	var missing_services := summary.duplicate(true)
	missing_services.erase("services")
	invalid_service_cases.append(missing_services)
	var non_array_services := summary.duplicate(true)
	non_array_services.services = {}
	invalid_service_cases.append(non_array_services)
	for missing_key in ["shop_index", "service_type", "price", "intel_kind"]:
		var missing_field := summary.duplicate(true)
		missing_field.services[0].erase(missing_key)
		invalid_service_cases.append(missing_field)
	for invalid_record in [
		{
			"shop_index": -1,
			"service_type": ShopServiceRecord.ServiceType.REFRESH,
			"price": 1,
			"intel_kind": -1,
		},
		{
			"shop_index": 2,
			"service_type": ShopServiceRecord.ServiceType.REFRESH,
			"price": 1,
			"intel_kind": -1,
		},
		{
			"shop_index": 0,
			"service_type": 99,
			"price": 1,
			"intel_kind": -1,
		},
		{
			"shop_index": 0,
			"service_type": ShopServiceRecord.ServiceType.REFRESH,
			"price": 2,
			"intel_kind": -1,
		},
		{
			"shop_index": 0,
			"service_type": ShopServiceRecord.ServiceType.REFRESH,
			"price": 1,
			"intel_kind": ShopIntelSnapshot.Kind.ROUTE_PAIR,
		},
		{
			"shop_index": 0,
			"service_type": ShopServiceRecord.ServiceType.INTEL,
			"price": 1,
			"intel_kind": 99,
		},
	]:
		var invalid_service := summary.duplicate(true)
		invalid_service.services = [invalid_record]
		invalid_service_cases.append(invalid_service)
	for index in range(invalid_service_cases.size()):
		assert_false(
			panel.bind_summary(
				invalid_service_cases[index],
				AreaCatalog.new().gold_corridor(),
				CardCatalog.new(),
				DealerCatalog.new(),
				EngravingCatalog.new()
			),
			"invalid service summary %d should fail closed" % index
		)

	var emitted := {"restart": false, "return": false}
	panel.restart_requested.connect(func() -> void: emitted.restart = true)
	panel.return_requested.connect(func() -> void: emitted.return = true)
	panel.get_node("%RestartAreaButton").emit_signal("pressed")
	panel.get_node("%ReturnEntryButton").emit_signal("pressed")
	assert_true(emitted.restart, "restart button should emit")
	assert_true(emitted.return, "return button should emit")

	var invalid := summary.duplicate(true)
	invalid.deck_ids = [&"starter_nudge_up_1"]
	assert_false(
		panel.bind_summary(
			invalid,
			AreaCatalog.new().gold_corridor(),
			CardCatalog.new(),
			DealerCatalog.new(),
			EngravingCatalog.new()
		),
		"invalid deck summary should fail closed"
	)
	assert_false(panel.visible, "invalid summary should hide completion")
	assert_equal(
		panel.mouse_filter,
		Control.MOUSE_FILTER_IGNORE,
		"failed summary bind should release input"
	)
	panel.free()

func _summary_deck() -> Array[StringName]:
	var deck := CardCatalog.new().starter_ids()
	deck[0] = &"shop_deep_drop"
	return deck
