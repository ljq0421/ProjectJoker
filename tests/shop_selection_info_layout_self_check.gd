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
	var market: Array[StringName] = area.starting_deck_ids.duplicate()
	market.append_array(area.shop_offer_ids)
	var session := ShopSession.new(
		CardCatalog.new(),
		area.starting_deck_ids,
		market,
		10,
		ShopIntelSnapshot.routes(area.second_route_ids),
		0,
		true
	)
	shop.bind_session(session, CardCatalog.new())
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
