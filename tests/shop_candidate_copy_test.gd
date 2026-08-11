extends "res://tests/test_case.gd"


func run() -> void:
	var shop: ShopScreen = load(
		"res://scenes/shop/shop_screen.tscn"
	).instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(shop)
	var catalog := CardCatalog.new()
	var deck_ids := catalog.starter_ids()
	var market_ids := catalog.shop_ids()

	var append_session := ShopSession.new(
		catalog,
		deck_ids,
		market_ids,
		10,
		ShopIntelSnapshot.routes([
			&"gold_room_narrow_ledger",
			&"gold_room_parallel_proof",
		]),
		0,
		true,
		0,
		true
	)
	assert_equal(append_session.initialization_error, "", "append shop should initialize")
	shop.bind_session(append_session, catalog)
	assert_equal(
		shop.get_node("%OfferTitle").text,
		"可购入手法牌（加入牌组）",
		"formal shop should name candidate cards as deck additions"
	)
	assert_true(
		"从下一场遭遇起可抽到" in shop.get_node("%OfferHint").text
		and "最多 15 张" in shop.get_node("%OfferHint").text,
		"formal shop should explain timing and the deck cap"
	)
	assert_true(
		"待购入" in shop.get_node("%ShopSelectionLabel").text
		and "远征牌组" in shop.get_node("%ShopSelectionLabel").text,
		"formal shop should explain its pending purchase"
	)
	assert_true(
		"购入并加入牌组" in shop.get_node("%ConfirmReplacementButton").text,
		"formal shop confirmation should name the destination"
	)

	var replacement_session := ShopSession.new(
		catalog,
		deck_ids,
		market_ids,
		10
	)
	assert_equal(
		replacement_session.initialization_error,
		"",
		"replacement shop should initialize"
	)
	shop.bind_session(replacement_session, catalog)
	assert_equal(
		shop.get_node("%OfferTitle").text,
		"可替换手法牌（一换一）",
		"legacy shop should retain replacement semantics"
	)
	assert_true(
		"待换入" in shop.get_node("%ShopSelectionLabel").text
		and "待换出" in shop.get_node("%ShopSelectionLabel").text,
		"replacement shop should name both sides of the exchange"
	)
	assert_true(
		"确认替换" in shop.get_node("%ConfirmReplacementButton").text,
		"replacement shop should retain its confirmation action"
	)
	shop.free()
