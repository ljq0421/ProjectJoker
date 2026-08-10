extends "res://tests/test_case.gd"

func run() -> void:
	_test_second_area_refresh_guarantees_unowned_rare()
	_test_shop_remove_and_engraving_transfer_services()
	_test_paid_transform_survives_ordinary_undo()
	_test_area_emergency_limits_and_costs()

func _test_second_area_refresh_guarantees_unowned_rare() -> void:
	var catalog := CardCatalog.new()
	var priority: Array[StringName] = []
	for card in catalog.shop_pool():
		if card.rarity != CardDefinition.Rarity.RARE:
			priority.append(card.id)
	for card in catalog.shop_pool():
		if card.rarity == CardDefinition.Rarity.RARE:
			priority.append(card.id)
	var shop := ShopSession.new(
		catalog,
		catalog.starter_ids(),
		priority,
		10,
		ShopIntelSnapshot.dealer(&"dealer_iron_abacus", 150),
		1,
		true,
		0,
		true,
		1
	)
	assert_true(shop.refresh_offers().accepted, "second area refresh should succeed")
	var has_rare := false
	for card_id in shop.offer_ids:
		if catalog.find_card(card_id).rarity == CardDefinition.Rarity.RARE:
			has_rare = true
	assert_true(has_rare, "second area refresh should contain an unowned rare")

func _test_shop_remove_and_engraving_transfer_services() -> void:
	var catalog := CardCatalog.new()
	var deck := catalog.starter_ids()
	deck.append(&"shop_precision_map")
	var shop := ShopSession.new(
		catalog,
		deck,
		catalog.shop_ids(),
		6,
		ShopIntelSnapshot.dealer(&"dealer_iron_abacus", 150),
		0,
		true,
		0,
		true
	)
	assert_true(shop.remove_card(&"shop_precision_map").accepted, "thirteen-card deck may remove one")
	assert_equal(shop.deck_ids.size(), 12, "remove service should return to twelve")
	assert_false(shop.remove_card(shop.deck_ids[0]).accepted, "remove service is once per shop")
	assert_true(
		shop.charge_engraving_transfer(&"d1", &"d2", 5).accepted,
		"engraving transfer charge should succeed"
	)
	assert_equal(shop.intel_tickets, 3, "remove and transfer should cost three intel")
	assert_equal(
		shop.service_records[-1].target_face,
		5,
		"service record should preserve target face"
	)

func _test_paid_transform_survives_ordinary_undo() -> void:
	var state := RoundState.new()
	state.dice.append(DieState.new(&"d1", 3))
	var controller := RoundController.new(
		state,
		SingleEncounterFixture.make_encounter(),
		null,
		null,
		[],
		RoundController.UndoMode.SPLIT
	)
	assert_true(controller.adjust_die(&"d1", 1).accepted, "calibration should create history")
	assert_true(controller.apply_paid_reroll(&"d1", 2).accepted, "paid reroll should apply")
	assert_equal(controller.state.find_die(&"d1").value, 3, "reroll keeps calibration delta")
	assert_true(controller.undo(), "ordinary undo should still undo calibration")
	assert_equal(controller.state.find_die(&"d1").rolled_value, 2, "undo must keep paid reroll")
	assert_equal(controller.state.find_die(&"d1").value, 2, "undo restores pre-calibration delta")
	assert_true(controller.apply_paid_calibration().accepted, "paid calibration should apply")
	assert_equal(controller.state.calibration_points, 3, "paid calibration adds one")

func _test_area_emergency_limits_and_costs() -> void:
	var area := AreaRunSession.new(8801, AreaCatalog.new().gold_corridor())
	assert_true(area.start().accepted, "formal area should start")
	area.intel_tickets = 8
	assert_true(area.select_route(area.current_route_ids()[0]).accepted, "room should start")
	assert_true(area.emergency_reroll(&"d1").accepted, "first reroll should succeed")
	assert_equal(area.intel_tickets, 7, "reroll costs one intel")
	assert_false(area.emergency_reroll(&"d2").accepted, "second reroll in round should fail")
	assert_equal(area.intel_tickets, 7, "failed reroll should not charge")
	assert_true(area.emergency_add_calibration().accepted, "first calibration purchase succeeds")
	assert_equal(area.intel_tickets, 5, "calibration purchase costs two")
	assert_true(area.emergency_retry_encounter().accepted, "area retry should restore entrance")
	assert_equal(area.intel_tickets, 2, "retry costs three without refund")
	assert_false(area.emergency_retry_encounter().accepted, "area retry is once per area")
