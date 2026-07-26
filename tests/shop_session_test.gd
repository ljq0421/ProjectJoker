extends "res://tests/test_case.gd"

const ShopScript = preload("res://scripts/run/shop_session.gd")

func run() -> void:
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

func _assert_unchanged_after_failure(
	shop,
	operation: Callable,
	message: String
) -> void:
	var before_deck: Array[StringName] = shop.deck_ids.duplicate()
	var before_sold: Array[StringName] = shop.sold_offer_ids.duplicate()
	var before_tickets: int = shop.intel_tickets
	var before_records: int = shop.purchase_records.size()
	var result: OperationResult = operation.call()
	assert_false(result.accepted, message)
	assert_equal(shop.deck_ids, before_deck, "%s; deck should be unchanged" % message)
	assert_equal(shop.sold_offer_ids, before_sold, "%s; offers should be unchanged" % message)
	assert_equal(shop.intel_tickets, before_tickets, "%s; tickets should be unchanged" % message)
	assert_equal(
		shop.purchase_records.size(),
		before_records,
		"%s; purchase records should be unchanged" % message
	)
