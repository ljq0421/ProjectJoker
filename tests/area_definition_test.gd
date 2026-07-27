extends "res://tests/test_case.gd"

func run() -> void:
	var area := AreaCatalog.new().gold_corridor()
	assert_true(area != null, "gold area definition should load")
	if area == null:
		return
	assert_equal(area.id, &"gold_corridor", "gold area ID should be stable")
	assert_equal(area.display_name, "金线回廊", "gold area name should be stable")
	assert_equal(area.starting_deck_ids.size(), 12, "gold deck stays twelve")
	assert_equal(area.first_route_ids.size(), 2, "first route stays two")
	assert_equal(area.second_route_ids.size(), 2, "second route stays two")
	assert_equal(area.rooms.size(), 4, "gold area keeps four rooms")
	assert_equal(area.dealer_id, &"dealer_iron_abacus", "dealer stays Iron Abacus")
	assert_equal(area.dealer_target, 150, "dealer target stays 150")
	assert_equal(area.starting_intel_tickets, 0, "gold area starts with no tickets")
	assert_equal(area.initial_engraving_id, &"", "gold area starts without engraving")
	assert_true(
		area.dealer_round_schedule == null,
		"legacy gold area should keep its single dealer encounter"
	)
	assert_equal(
		area.validate(CardCatalog.new(), DealerCatalog.new(), EngravingCatalog.new()),
		[],
		"gold area definition should validate"
	)
	assert_true(
		area.find_room(&"gold_room_precise_steps") != null,
		"area should own room lookup"
	)
	assert_true(area.find_room(&"missing_room") == null, "unknown room should return null")

	var first_ids := area.first_route_ids
	first_ids.clear()
	assert_equal(area.first_route_ids.size(), 2, "route getter should be defensive")
