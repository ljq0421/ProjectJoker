extends "res://tests/test_case.gd"

const ShopScript = preload("res://scripts/run/shop_session.gd")

func run() -> void:
	_test_legacy_purchase_flow()
	_test_formal_shop_prices_and_initial_offers()
	_test_refresh_after_zero_to_three_purchases()
	_test_replaced_card_can_return_on_refresh()
	_test_intel_purchase_is_single_use()
	_test_service_failures_are_atomic()

func _test_legacy_purchase_flow() -> void:
	var catalog := CardCatalog.new()
	var starter := catalog.starter_ids()
	var offers := catalog.shop_ids()
	var shop = ShopScript.new(catalog, starter, offers, 2)

	var bought_id: StringName = offers[0]
	var replaced_id: StringName = starter[0]
	var success: OperationResult = shop.purchase(bought_id, replaced_id)
	assert_true(success.accepted, "valid replacement should succeed")
	assert_equal(shop.deck_ids.size(), 12, "purchase should preserve deck size")
	assert_true(bought_id in shop.deck_ids, "new card should enter deck")
	assert_false(replaced_id in shop.deck_ids, "replaced card should leave deck")
	assert_equal(shop.intel_tickets, 1, "purchase should cost one ticket")
	assert_true(bought_id in shop.sold_offer_ids, "bought offer should be sold")
	assert_equal(shop.purchase_records.size(), 1, "purchase should create one record")
	assert_equal(shop.purchase_records[0].offer_id, bought_id, "record should keep incoming card")
	assert_equal(
		shop.purchase_records[0].replaced_id,
		replaced_id,
		"record should keep outgoing card"
	)
	assert_equal(shop.purchase_records[0].price, ShopSession.CARD_PRICE, "record should keep price")

	_assert_unchanged_after_failure(
		shop,
		func() -> OperationResult: return shop.purchase(bought_id, starter[1]),
		"sold offer should be rejected"
	)
	_assert_unchanged_after_failure(
		shop,
		func() -> OperationResult: return shop.purchase(offers[1], &"missing_card"),
		"unknown replaced card should be rejected"
	)

	var final_success: OperationResult = shop.purchase(offers[1], starter[1])
	assert_true(final_success.accepted, "second affordable purchase should succeed")
	assert_equal(shop.intel_tickets, 0, "two purchases should spend both tickets")
	assert_equal(shop.purchase_records.size(), 2, "second purchase should append one record")
	_assert_unchanged_after_failure(
		shop,
		func() -> OperationResult: return shop.purchase(offers[2], starter[2]),
		"insufficient balance should be rejected"
	)

func _test_formal_shop_prices_and_initial_offers() -> void:
	var catalog := CardCatalog.new()
	var starter := catalog.starter_ids()
	var market := _market_priority(catalog)
	var shop := _formal_shop(catalog, starter, market, 6)
	assert_equal(ShopSession.CARD_PRICE, 1, "card price should stay one")
	assert_equal(ShopSession.REFRESH_PRICE, 1, "refresh should cost one")
	assert_equal(ShopSession.INTEL_PRICE, 1, "intel should cost one")
	assert_equal(
		shop.offer_ids,
		catalog.shop_ids().slice(0, 3),
		"formal shop should expose the first three off-deck market entries"
	)
	assert_equal(shop.shown_offer_ids, shop.offer_ids, "initial offers should be shown")
	assert_true(shop.services_enabled, "formal shop should enable services")

func _test_refresh_after_zero_to_three_purchases() -> void:
	for purchase_count in range(4):
		var catalog := CardCatalog.new()
		var starter := catalog.starter_ids()
		var shop := _formal_shop(catalog, starter, _market_priority(catalog), 10)
		var original_offers: Array[StringName] = shop.offer_ids.duplicate()
		for index in range(purchase_count):
			var result := shop.purchase(original_offers[index], starter[index])
			assert_true(result.accepted, "purchase %d before refresh should succeed" % index)
		var tickets_before := shop.intel_tickets
		var refresh := shop.refresh_offers()
		assert_true(refresh.accepted, "refresh after %d purchases should succeed" % purchase_count)
		assert_equal(shop.offer_ids.size(), 3, "refresh should keep three offers")
		assert_equal(
			_unique_count(shop.offer_ids),
			3,
			"refresh should expose three unique offers"
		)
		for card_id in shop.offer_ids:
			assert_false(card_id in original_offers, "old offers must not return")
			assert_false(card_id in shop.deck_ids, "refreshed offers must stay outside deck")
		assert_equal(
			shop.intel_tickets,
			tickets_before - ShopSession.REFRESH_PRICE,
			"refresh should spend one ticket"
		)
		assert_true(shop.refresh_used, "refresh should become unavailable")
		assert_equal(shop.service_records.size(), 1, "refresh should create one service record")
		assert_equal(
			shop.service_records[0].service_type,
			ShopServiceRecord.ServiceType.REFRESH,
			"refresh record should keep its service type"
		)

func _test_replaced_card_can_return_on_refresh() -> void:
	var catalog := CardCatalog.new()
	var starter := catalog.starter_ids()
	var shop_ids := catalog.shop_ids()
	var priority: Array[StringName] = []
	priority.append_array(shop_ids.slice(0, 3))
	priority.append(starter[0])
	priority.append_array(shop_ids.slice(3))
	priority.append_array(starter.slice(1))
	var shop := _formal_shop(catalog, starter, priority, 5)
	assert_true(
		shop.purchase(shop.offer_ids[0], starter[0]).accepted,
		"fixture purchase should replace the first starter"
	)
	assert_true(shop.refresh_offers().accepted, "buyback refresh should succeed")
	assert_true(starter[0] in shop.offer_ids, "replaced starter should become a buyback offer")

func _test_intel_purchase_is_single_use() -> void:
	var catalog := CardCatalog.new()
	var shop := _formal_shop(
		catalog,
		catalog.starter_ids(),
		_market_priority(catalog),
		3
	)
	var purchase := shop.purchase_intel()
	assert_true(purchase.accepted, "valid intel purchase should succeed")
	assert_true(shop.intel_unlocked, "intel should unlock")
	assert_equal(shop.intel_tickets, 2, "intel should cost one ticket")
	assert_equal(shop.service_records.size(), 1, "intel should create one record")
	assert_equal(
		shop.service_records[0].service_type,
		ShopServiceRecord.ServiceType.INTEL,
		"intel record should keep its service type"
	)
	_assert_unchanged_after_failure(
		shop,
		func() -> OperationResult: return shop.purchase_intel(),
		"duplicate intel purchase should reject"
	)

func _test_service_failures_are_atomic() -> void:
	var catalog := CardCatalog.new()
	var starter := catalog.starter_ids()
	var no_funds := _formal_shop(catalog, starter, _market_priority(catalog), 0)
	_assert_unchanged_after_failure(
		no_funds,
		func() -> OperationResult: return no_funds.refresh_offers(),
		"insufficient refresh funds should reject"
	)
	_assert_unchanged_after_failure(
		no_funds,
		func() -> OperationResult: return no_funds.purchase_intel(),
		"insufficient intel funds should reject"
	)

	var refreshed := _formal_shop(catalog, starter, _market_priority(catalog), 5)
	assert_true(refreshed.refresh_offers().accepted, "first refresh should succeed")
	_assert_unchanged_after_failure(
		refreshed,
		func() -> OperationResult: return refreshed.refresh_offers(),
		"second refresh should reject"
	)

	var short_priority: Array[StringName] = catalog.shop_ids().slice(0, 3)
	var short_shop := _formal_shop(catalog, starter, short_priority, 5)
	_assert_unchanged_after_failure(
		short_shop,
		func() -> OperationResult: return short_shop.refresh_offers(),
		"missing refresh reserve should reject"
	)

	var invalid_snapshot := ShopIntelSnapshot.routes([&"missing_room", &"missing_room"])
	var invalid_shop := ShopSession.new(
		catalog,
		starter,
		_market_priority(catalog),
		5,
		invalid_snapshot,
		0,
		true
	)
	_assert_unchanged_after_failure(
		invalid_shop,
		func() -> OperationResult: return invalid_shop.purchase_intel(),
		"structurally invalid intel should reject"
	)

	var duplicate_priority := _market_priority(catalog)
	duplicate_priority[-1] = duplicate_priority[0]
	var duplicate_shop := _formal_shop(catalog, starter, duplicate_priority, 5)
	_assert_unchanged_after_failure(
		duplicate_shop,
		func() -> OperationResult: return duplicate_shop.refresh_offers(),
		"duplicate market priority should reject services"
	)

	var unknown_priority := _market_priority(catalog)
	unknown_priority[-1] = &"missing_card"
	var unknown_shop := _formal_shop(catalog, starter, unknown_priority, 5)
	_assert_unchanged_after_failure(
		unknown_shop,
		func() -> OperationResult: return unknown_shop.refresh_offers(),
		"unknown market priority should reject services"
	)

func _formal_shop(
	catalog: CardCatalog,
	starter: Array[StringName],
	priority: Array[StringName],
	tickets: int
) -> ShopSession:
	return ShopSession.new(
		catalog,
		starter,
		priority,
		tickets,
		ShopIntelSnapshot.routes([
			&"gold_room_narrow_ledger",
			&"gold_room_parallel_proof",
		]),
		0,
		true
	)

func _market_priority(catalog: CardCatalog) -> Array[StringName]:
	var priority: Array[StringName] = catalog.starter_ids()
	priority.append_array(catalog.shop_ids())
	return priority

func _assert_unchanged_after_failure(
	shop,
	operation: Callable,
	message: String
) -> void:
	var before := _shop_snapshot(shop)
	var result: OperationResult = operation.call()
	assert_false(result.accepted, message)
	assert_equal(
		_shop_snapshot(shop),
		before,
		"%s; complete shop state should be unchanged" % message
	)

func _shop_snapshot(shop: ShopSession) -> Dictionary:
	return {
		"deck": shop.deck_ids.duplicate(),
		"offers": shop.offer_ids.duplicate(),
		"shown": shop.shown_offer_ids.duplicate(),
		"sold": shop.sold_offer_ids.duplicate(),
		"tickets": shop.intel_tickets,
		"refresh_used": shop.refresh_used,
		"intel_unlocked": shop.intel_unlocked,
		"purchase_count": shop.purchase_records.size(),
		"service_count": shop.service_records.size(),
	}

func _unique_count(ids: Array[StringName]) -> int:
	var unique: Dictionary = {}
	for id in ids:
		unique[id] = true
	return unique.size()
