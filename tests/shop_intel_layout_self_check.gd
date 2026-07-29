extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.content_scale_size = Vector2i(1920, 1080)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	for viewport_size in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		await _check_size(viewport_size)
	if failures.is_empty():
		print("PASS shop_intel_layout_self_check")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _check_size(viewport_size: Vector2i) -> void:
	root.size = viewport_size
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	var shop: ShopScreen = load(
		"res://scenes/shop/shop_screen.tscn"
	).instantiate()
	var intel: ShopIntelPanel = load(
		"res://scenes/components/shop_intel_panel.tscn"
	).instantiate()
	host.add_child(shop)
	host.add_child(intel)
	await _settle()

	var gold := AreaCatalog.new().gold_corridor()
	var market: Array[StringName] = gold.starting_deck_ids.duplicate()
	market.append_array(gold.shop_offer_ids)
	var session := ShopSession.new(
		CardCatalog.new(),
		gold.starting_deck_ids,
		market,
		10,
		ShopIntelSnapshot.routes(gold.second_route_ids),
		0,
		true
	)
	shop.bind_session(session, CardCatalog.new())
	await _settle()
	var viewport_rect := root.get_visible_rect()
	for node_name in [
		"RefreshOffersButton",
		"PurchaseIntelButton",
		"LeaveShopButton",
	]:
		var button: Control = shop.get_node("%" + node_name)
		_assert_inside(
			viewport_rect,
			button.get_global_rect(),
			"%s at %s" % [node_name, viewport_size]
		)
		_assert_true(
			button.get_global_rect().size.y >= 44.0,
			"%s should remain a readable target at %s" % [
				node_name,
				viewport_size,
			]
		)

	_assert_true(
		intel.bind_snapshot(
			session.intel_snapshot,
			gold,
			session.deck_ids,
			CardCatalog.new(),
			DealerCatalog.new()
		),
		"route mode should bind at %s" % viewport_size
	)
	await _settle()
	var route_mode: Control = intel.get_node("%RouteMode")
	_assert_inside(viewport_rect, route_mode.get_global_rect(), "route mode at %s" % viewport_size)
	var left_page: Control = intel.get_node(
		"SafeArea/IntelLedger/LedgerColumn/RouteMode/RouteIntelPages/LeftPage"
	)
	var right_page: Control = intel.get_node(
		"SafeArea/IntelLedger/LedgerColumn/RouteMode/RouteIntelPages/RightPage"
	)
	_assert_true(
		left_page.get_global_rect().end.x <= right_page.get_global_rect().position.x,
		"route columns should remain side by side at %s" % viewport_size
	)
	_assert_true(
		left_page.get_global_rect().size.x >= 400.0
			and right_page.get_global_rect().size.x >= 400.0,
		"route columns should remain readable at %s" % viewport_size
	)

	var faceless := AreaCatalog.new().faceless_hub()
	_assert_true(
		intel.bind_snapshot(
			ShopIntelSnapshot.dealer(
				faceless.dealer_id,
				faceless.dealer_target
			),
			faceless,
			faceless.starting_deck_ids,
			CardCatalog.new(),
			DealerCatalog.new()
		),
		"dealer mode should bind at %s" % viewport_size
	)
	await _settle()
	var dealer_mode: Control = intel.get_node("%DealerMode")
	_assert_inside(
		viewport_rect,
		dealer_mode.get_global_rect(),
		"dealer mode at %s" % viewport_size
	)
	var scroll: ScrollContainer = intel.get_node("%DealerIntelScroll")
	_assert_true(
		scroll.get_v_scroll_bar().max_value > scroll.get_v_scroll_bar().page,
		"dealer details should scroll at %s" % viewport_size
	)
	_assert_true(
		"独手裁决" in intel.get_node("%DealerIntelRestrictions").text
			and "三席到场" in intel.get_node("%DealerIntelRestrictions").text,
		"both final restrictions should remain reachable at %s" % viewport_size
	)
	var close_button: Button = intel.get_node("%CloseIntelButton")
	_assert_inside(
		viewport_rect,
		close_button.get_global_rect(),
		"close button at %s" % viewport_size
	)
	_assert_true(
		close_button.get_global_rect().size.x >= 120.0,
		"close target should stay at least 120px wide at %s" % viewport_size
	)
	intel.close()
	_assert_true(
		intel.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"close should release input at %s" % viewport_size
	)

	host.free()
	await process_frame

func _assert_inside(parent: Rect2, child: Rect2, label: String) -> void:
	_assert_true(
		parent.encloses(child),
		"%s outside bounds; parent=%s child=%s" % [label, parent, child]
	)

func _settle() -> void:
	await process_frame
	await process_frame
	await process_frame

func _assert_true(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
