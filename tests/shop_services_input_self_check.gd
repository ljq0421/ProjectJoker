extends SceneTree

var failures: Array[String] = []
var pointer_position := Vector2.ZERO
var screen: GoldCorridorRunScreen

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.content_scale_size = Vector2i(1920, 1080)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.size = Vector2i(1920, 1080)
	var fixture := _find_buyback_fixture()
	_assert_true(not fixture.is_empty(), "a deterministic buyback fixture should exist")
	if fixture.is_empty():
		await _finish()
		return

	screen = load(
		"res://scenes/run/gold_corridor_run_screen.tscn"
	).instantiate()
	screen.guide_auto_start = false
	screen.configure(AreaCatalog.new().gold_corridor(), fixture["seed"])
	root.add_child(screen)
	current_scene = screen
	await _settle()
	screen.get_node("%GoldCorridorGuideOverlay").close_card()

	await _click(_route_button_at(0))
	await _settle()
	await _complete_three_rounds()
	screen.area_session.intel_tickets = 10
	await _click(screen.get_node("%RoundSummaryPanel").get_node("%EnterShopButton"))
	await _settle()

	var shop: ShopScreen = screen.get_node("%ShopScreen")
	var first_session := screen.area_session.shop_session
	var initial_offers: Array[StringName] = first_session.offer_ids.duplicate()
	var initial_tickets := first_session.intel_tickets
	await _click(shop.get_node("%RefreshOffersButton"))
	await _settle()
	var dialog: ConfirmationDialog = shop.get_node("%RefreshConfirmationDialog")
	_assert_true(dialog.visible, "refresh click should open confirmation")
	_assert_equal(
		first_session.intel_tickets,
		initial_tickets,
		"opening refresh confirmation should not spend"
	)
	await _click(dialog.get_cancel_button())
	await _settle()
	_assert_false(dialog.visible, "cancel should close refresh confirmation")
	_assert_equal(first_session.offer_ids, initial_offers, "cancel should preserve offers")
	_assert_equal(first_session.intel_tickets, initial_tickets, "cancel should preserve balance")

	await _click(shop.get_node("%RefreshOffersButton"))
	await _settle()
	await _click(dialog.get_ok_button())
	await _settle()
	_assert_true(first_session.refresh_used, "confirmed refresh should be recorded")
	_assert_equal(
		first_session.intel_tickets,
		initial_tickets - ShopSession.REFRESH_PRICE,
		"confirmed refresh should spend one ticket"
	)
	for card_id in first_session.offer_ids:
		_assert_false(card_id in initial_offers, "refreshed offers should all be new")
	_assert_equal(shop.selected_offer_id, &"", "refresh should clear offer selection")
	_assert_equal(shop.selected_deck_id, &"", "refresh should clear deck selection")

	var preview_routes: Array[StringName] = (
		first_session.intel_snapshot.route_ids.duplicate()
	)
	var before_route_intel := first_session.intel_tickets
	await _click(shop.get_node("%PurchaseIntelButton"))
	await _settle()
	var intel: ShopIntelPanel = screen.get_node("%ShopIntelPanel")
	_assert_true(intel.visible, "route intel click should open overlay")
	_assert_true(intel.get_node("%RouteMode").visible, "route mode should be visible")
	_assert_equal(
		first_session.intel_tickets,
		before_route_intel - ShopSession.INTEL_PRICE,
		"route intel should spend once"
	)
	var offer_before_block := shop.selected_offer_id
	var blocked_offer := _find_shop_card(&"offer")
	await _click_at_point(blocked_offer.get_global_rect().get_center())
	_assert_equal(
		shop.selected_offer_id,
		offer_before_block,
		"intel overlay should block the shop behind it"
	)
	await _click(intel.get_node("%CloseIntelButton"))
	await _settle()
	var after_first_view := first_session.intel_tickets
	await _click(shop.get_node("%PurchaseIntelButton"))
	await _settle()
	_assert_true(intel.visible, "purchased route intel should reopen")
	_assert_equal(
		first_session.intel_tickets,
		after_first_view,
		"reopening route intel should be free"
	)
	await _click(intel.get_node("%CloseIntelButton"))
	await _settle()

	var outgoing_id: StringName = fixture["outgoing_id"]
	var purchased_id: StringName = fixture["purchased_id"]
	await _click(_find_shop_card(&"offer", purchased_id))
	await _settle()
	await _click(_find_shop_card(&"deck", outgoing_id))
	await _click(shop.get_node("%ConfirmReplacementButton"))
	await _settle()
	_assert_true(purchased_id in first_session.deck_ids, "first purchase should enter deck")
	await _click(shop.get_node("%LeaveShopButton"))
	await _settle()
	_assert_equal(
		screen.area_session.current_route_ids(),
		preview_routes,
		"actual second routes should equal the purchased preview"
	)

	await _click(_route_button_at(0))
	await _settle()
	await _complete_three_rounds()
	await _click(screen.get_node("%RoundSummaryPanel").get_node("%EnterShopButton"))
	await _settle()
	var second_session := screen.area_session.shop_session
	_assert_true(
		outgoing_id in second_session.offer_ids,
		"second shop should expose the outgoing first-shop card"
	)
	var dealer_preview: ShopIntelSnapshot = second_session.intel_snapshot
	var before_dealer_intel := second_session.intel_tickets
	await _click(shop.get_node("%PurchaseIntelButton"))
	await _settle()
	_assert_true(intel.visible, "dealer intel click should open overlay")
	_assert_true(intel.get_node("%DealerMode").visible, "dealer mode should be visible")
	_assert_equal(
		intel.get_node("%DealerIntelName").text,
		"铁算盘",
		"dealer intel should name Iron Abacus"
	)
	_assert_true(
		"150" in intel.get_node("%DealerIntelTarget").text,
		"dealer intel should expose target"
	)
	_assert_true(
		"固定奖励" in intel.get_node("%DealerIntelMechanism").text,
		"dealer intel should expose mechanism"
	)
	_assert_true(
		"固定规则" in intel.get_node("%DealerRoundThreeTitle").text,
		"dealer intel should expose all three rounds"
	)
	_assert_equal(
		second_session.intel_tickets,
		before_dealer_intel - ShopSession.INTEL_PRICE,
		"dealer intel should spend once"
	)
	await _click(intel.get_node("%CloseIntelButton"))
	await _settle()

	await _click(_find_shop_card(&"offer", outgoing_id))
	await _settle()
	var second_replaced := _first_deck_id_except(outgoing_id)
	await _click(_find_shop_card(&"deck", second_replaced))
	await _click(shop.get_node("%ConfirmReplacementButton"))
	await _settle()
	_assert_true(outgoing_id in second_session.deck_ids, "old card should be bought back")
	await _click(shop.get_node("%LeaveShopButton"))
	await _settle()
	_assert_equal(
		screen.area_session.phase,
		AreaRunSession.Phase.DEALER,
		"second shop should enter dealer; shop_error=%s" % (
			shop.get_node("%ShopErrorLabel").text
		)
	)
	if (
		screen.area_session.phase == AreaRunSession.Phase.DEALER
		and screen.area_session.encounter_session != null
		and (
			screen.area_session.encounter_session.setup
			.resolution_context.dealer
		) != null
	):
		_assert_equal(
			screen.area_session.encounter_session.setup.resolution_context.dealer.id,
			dealer_preview.dealer_id,
			"actual dealer should match the preview"
		)
		_assert_equal(
			screen.area_session.encounter_session.target_total,
			dealer_preview.dealer_target,
			"actual dealer target should match the preview"
		)
	_assert_true(outgoing_id in screen.area_session.deck_ids, "buyback should reach dealer deck")
	await _finish()

func _find_buyback_fixture() -> Dictionary:
	for seed in range(20260729, 20260749):
		for outgoing_id in AreaCatalog.new().gold_corridor().starting_deck_ids:
			var area := AreaRunSession.new(seed)
			if not area.start().accepted:
				continue
			if not area.select_route(area.current_route_ids()[0]).accepted:
				continue
			_complete_domain_encounter(area)
			area.intel_tickets = 10
			if not area.open_shop().accepted:
				continue
			if not area.shop_session.refresh_offers().accepted:
				continue
			var purchased_id: StringName = area.shop_session.offer_ids[0]
			if not area.shop_session.purchase(purchased_id, outgoing_id).accepted:
				continue
			if not area.leave_shop().accepted:
				continue
			if not area.select_route(area.current_route_ids()[0]).accepted:
				continue
			_complete_domain_encounter(area)
			if not area.open_shop().accepted:
				continue
			if outgoing_id in area.shop_session.offer_ids:
				return {
					"seed": seed,
					"outgoing_id": outgoing_id,
					"purchased_id": purchased_id,
				}
	return {}

func _complete_domain_encounter(area: AreaRunSession) -> void:
	area.encounter_session.target_total = 0
	for round_index in range(3):
		var report := area.encounter_session.current_session.commit()
		area.accept_encounter_report(report)
		if round_index < 2:
			area.advance_encounter_round()

func _complete_three_rounds() -> void:
	screen.area_session.encounter_session.target_total = 0
	for round_index in range(3):
		var encounter: SingleEncounterScreen = screen.get_node(
			"%EncounterScreen"
		)
		await _click(encounter.get_node("%ConfirmButton"))
		encounter.resolution_panel.finish_playback()
		await _settle()
		if round_index < 2:
			await _click(
				screen.get_node("%RoundSummaryPanel").get_node("%NextRoundButton")
			)
			await _settle()

func _route_button_at(index: int) -> Button:
	var panel: RouteChoicePanel = screen.get_node("%RouteChoicePanel")
	return (
		panel.get_node("%LeftRouteButton")
		if index == 0
		else panel.get_node("%RightRouteButton")
	)

func _find_shop_card(
	role: StringName,
	card_id: StringName = &""
) -> ShopCardToken:
	for node in screen.find_children("*", "Button", true, false):
		if (
			node is ShopCardToken
			and not node.is_queued_for_deletion()
			and not node.disabled
			and node.role == role
			and (card_id == &"" or node.card_id == card_id)
		):
			return node
	return null

func _first_deck_id_except(excluded_id: StringName) -> StringName:
	for card_id in screen.area_session.shop_session.deck_ids:
		if card_id != excluded_id:
			return card_id
	return &""

func _click(control: Control) -> void:
	_assert_true(control != null, "click target should exist")
	if control == null:
		return
	var viewport := control.get_viewport()
	var point := control.get_global_rect().get_center()
	if viewport is Window and viewport != root:
		point += Vector2((viewport as Window).position)
		viewport = root
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.relative = Vector2.ZERO
	viewport.push_input(motion, true)
	await process_frame
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = point
	viewport.push_input(press, true)
	await process_frame
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = point
	viewport.push_input(release, true)
	await process_frame

func _click_at_point(point: Vector2) -> void:
	await _move_pointer(point)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = point
	root.push_input(press, true)
	await process_frame
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = point
	root.push_input(release, true)
	await process_frame

func _move_pointer(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.relative = point - pointer_position
	root.push_input(motion, true)
	pointer_position = point
	await process_frame

func _settle() -> void:
	await process_frame
	await process_frame
	await process_frame

func _assert_true(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func _assert_false(value: bool, message: String) -> void:
	if value:
		failures.append(message)

func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		failures.append("%s; expected=%s actual=%s" % [message, expected, actual])

func _finish() -> void:
	if screen != null:
		screen.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS shop_services_input_self_check")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
