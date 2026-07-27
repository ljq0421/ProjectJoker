extends "res://tests/test_case.gd"

const ROUTE_NODES := [
	"RouteDimmer",
	"RouteLedger",
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
		"purchases": [{
			"offer_id": &"shop_deep_drop",
			"replaced_id": &"starter_nudge_up_1",
			"price": 1,
		}],
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
