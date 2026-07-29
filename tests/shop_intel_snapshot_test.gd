extends "res://tests/test_case.gd"

func run() -> void:
	_test_valid_route_snapshot()
	_test_valid_dealer_snapshot()
	_test_invalid_route_snapshots()
	_test_invalid_dealer_snapshots()

func _test_valid_route_snapshot() -> void:
	var area := AreaCatalog.new().gold_corridor()
	var snapshot := ShopIntelSnapshot.routes(area.second_route_ids)
	assert_equal(
		snapshot.validate(area, DealerCatalog.new()),
		"",
		"valid second-route snapshot should pass"
	)
	assert_equal(snapshot.kind, ShopIntelSnapshot.Kind.ROUTE_PAIR, "route snapshot kind")
	assert_equal(snapshot.route_ids, area.second_route_ids, "route IDs should be retained")

func _test_valid_dealer_snapshot() -> void:
	var area := AreaCatalog.new().faceless_hub()
	var snapshot := ShopIntelSnapshot.dealer(area.dealer_id, area.dealer_target)
	assert_equal(
		snapshot.validate(area, DealerCatalog.new()),
		"",
		"valid dealer snapshot should pass"
	)
	assert_equal(snapshot.kind, ShopIntelSnapshot.Kind.DEALER, "dealer snapshot kind")
	assert_equal(snapshot.dealer_id, area.dealer_id, "dealer ID should be retained")
	assert_equal(snapshot.dealer_target, area.dealer_target, "dealer target should be retained")

func _test_invalid_route_snapshots() -> void:
	var area := AreaCatalog.new().gold_corridor()
	var dealers := DealerCatalog.new()
	var duplicate := ShopIntelSnapshot.routes([
		area.second_route_ids[0],
		area.second_route_ids[0],
	])
	assert_false(duplicate.structural_error().is_empty(), "duplicate routes should be structural")
	assert_false(duplicate.validate(area, dealers).is_empty(), "duplicate routes should reject")

	var missing := ShopIntelSnapshot.routes([&"missing_room", area.second_route_ids[0]])
	assert_false(missing.validate(area, dealers).is_empty(), "unknown route should reject")

	var short := ShopIntelSnapshot.routes([area.second_route_ids[0]])
	assert_false(short.structural_error().is_empty(), "route count should be structural")

	var mixed := ShopIntelSnapshot.routes(area.second_route_ids)
	mixed.dealer_id = area.dealer_id
	assert_false(mixed.structural_error().is_empty(), "route snapshot must not carry dealer")

func _test_invalid_dealer_snapshots() -> void:
	var area := AreaCatalog.new().mirror_hall()
	var dealers := DealerCatalog.new()
	var missing := ShopIntelSnapshot.dealer(&"missing_dealer", area.dealer_target)
	assert_false(missing.validate(area, dealers).is_empty(), "unknown dealer should reject")

	var wrong := ShopIntelSnapshot.dealer(&"dealer_iron_abacus", area.dealer_target)
	assert_false(wrong.validate(area, dealers).is_empty(), "mismatched dealer should reject")

	var no_target := ShopIntelSnapshot.dealer(area.dealer_id, 0)
	assert_false(no_target.structural_error().is_empty(), "nonpositive target should reject")

	var mixed := ShopIntelSnapshot.dealer(area.dealer_id, area.dealer_target)
	mixed.route_ids.assign(area.second_route_ids)
	assert_false(mixed.structural_error().is_empty(), "dealer snapshot must not carry routes")
