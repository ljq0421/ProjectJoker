extends SceneTree

const LOGICAL_SIZE := Vector2i(1920, 1080)

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = LOGICAL_SIZE
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)

	var shop: ShopScreen = load(
		"res://scenes/shop/shop_screen.tscn"
	).instantiate()
	host.add_child(shop)
	await _settle()

	var area := AreaCatalog.new().gold_corridor()
	var catalog := CardCatalog.new()
	var full_deck: Array[StringName] = area.starting_deck_ids.duplicate()
	for card_id in area.shop_offer_ids:
		if card_id not in full_deck:
			full_deck.append(card_id)
		if full_deck.size() == CardDeck.MAX_DECK_SIZE:
			break
	var market: Array[StringName] = []
	for card_id in area.shop_offer_ids:
		if card_id not in full_deck:
			market.append(card_id)
	var session := ShopSession.new(
		catalog,
		full_deck,
		market,
		10,
		ShopIntelSnapshot.routes(area.second_route_ids),
		0,
		true,
		0,
		true
	)
	shop.bind_session(session, catalog)
	var profiles: Array[DieState] = []
	for die_index in range(1, 7):
		profiles.append(DieState.new(StringName("d%d" % die_index), die_index))
	profiles[0].engraving_id = &"engraving_echo"
	profiles[0].engraved_face = 1
	shop.bind_formal_context(profiles, EngravingCatalog.new())
	await _settle()

	var body: Control = shop.get_node("SafeArea/RootColumn/Body")
	var body_height_before := body.size.y
	shop._on_card_selected(session.deck_ids[0], &"deck")
	await _settle()

	var info_column := shop.get_node_or_null("%ShopSelectionInfoColumn") as Control
	_assert_true(
		info_column != null,
		"shop should own a dedicated selection-information column"
	)
	if info_column != null:
		var deck_grid: Control = shop.get_node("%DeckGrid")
		_assert_true(
			deck_grid.get_global_rect().end.x <= info_column.get_global_rect().position.x,
			"selection information should sit to the right of the deck grid"
		)
		for node_path in [
			"%ShopSelectionLabel",
			"%ShopCardDetailPanel",
			"%ShopServiceStatusLabel",
		]:
			var info_node: Control = shop.get_node(node_path)
			_assert_true(
				info_column.is_ancestor_of(info_node),
				"%s should belong to the right-side information column" % node_path
			)

	_assert_true(
		shop.get_node("%ShopCardDetailPanel").visible,
		"selecting a card should reveal its comparison copy"
	)
	_assert_true(
		shop.get_node("%DeckGrid").get_child_count() == CardDeck.MAX_DECK_SIZE,
		"formal shop should render all fifteen deck cards"
	)
	_assert_true(
		shop.get_node("%FormalServicePanel").visible,
		"formal services should remain visible beside a fifteen-card deck"
	)
	for node_path in [
		"%OfferTitle",
		"%OfferHint",
		"%OfferColumn",
		"%FormalServicePanel",
		"%RemoveCardButton",
		"%EngravingSourceChoice",
		"%EngravingTargetChoice",
		"%EngravingFaceChoice",
		"%TransferEngravingButton",
		"%LeaveShopButton",
	]:
		var control: Control = shop.get_node(node_path)
		_assert_true(
			Rect2(Vector2.ZERO, LOGICAL_SIZE).encloses(control.get_global_rect()),
			"%s should stay inside the logical viewport" % node_path
		)
	_assert_true(
		is_equal_approx(body.size.y, body_height_before),
		"selecting a card should not resize the main shop body"
	)

	host.free()
	await process_frame
	if failures.is_empty():
		print("PASS shop_selection_info_layout_self_check")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _settle() -> void:
	await process_frame
	await process_frame
	await process_frame


func _assert_true(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
