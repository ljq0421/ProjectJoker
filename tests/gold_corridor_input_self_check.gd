extends SceneTree

var failures: Array[String] = []
var pointer_position := Vector2.ZERO
var run_screen: GoldCorridorRunScreen
var guide_path: String

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	guide_path = OS.get_temp_dir().path_join(
		"project-joker-gold-corridor-entry-%d.cfg" % Time.get_ticks_usec()
	)
	DirAccess.remove_absolute(guide_path)
	var entry: SingleEncounterScreen = load(
		"res://scenes/run/single_encounter_screen.tscn"
	).instantiate()
	entry.tutorial_auto_start = false
	entry.tutorial_config_path = guide_path
	root.add_child(entry)
	current_scene = entry
	await _settle()
	await _click(entry.get_node("%RunTrialButton"))
	await _settle()

	run_screen = current_scene as GoldCorridorRunScreen
	_assert_true(run_screen != null, "normal entry should open complete Gold Corridor")
	if run_screen == null:
		await _finish()
		return
	_assert_equal(
		run_screen.guide_config_path,
		guide_path,
		"normal entry should propagate its configured guide path"
	)
	run_screen.guide_auto_start = false
	run_screen.get_node("%GoldCorridorGuideOverlay").close_card()

	var route_panel: RouteChoicePanel = run_screen.get_node("%RouteChoicePanel")
	var encounter: SingleEncounterScreen = run_screen.get_node("%EncounterScreen")
	var narrative := run_screen.get_node("%NarrativeCard")
	_assert_true(
		narrative.is_open(),
		"standalone entry should reveal the randomly locked area mutation"
	)
	_assert_true(
		"随机锁定" in narrative.get_node("%NarrativeBody").text,
		"mutation reveal should explain that it is random rather than player-picked"
	)
	await _click(narrative.get_node("%NarrativeContinueButton"))
	await _settle()
	_assert_true(route_panel.visible, "route choice should open after mutation reveal confirmation")
	var route_order := run_screen.area_session.current_route_ids()
	var phase_before_block := run_screen.area_session.phase
	await _click_at_point(encounter.get_node("%ConfirmButton").get_global_rect().get_center())
	_assert_true(
		run_screen.area_session.phase == phase_before_block,
		"route overlay should block encounter confirmation"
	)
	_assert_true(
		not encounter.session.controller.committed,
		"route overlay should block the encounter behind it"
	)

	var first_route_button: Button = route_panel.get_node("%LeftRouteButton")
	var first_room_id: StringName = first_route_button.get_meta("room_id")
	await _click(first_route_button)
	await _settle()
	run_screen.area_session.encounter_session.target_total = 0
	var first_dice := _rolled_values(run_screen.area_session.encounter_session)
	await _complete_encounter()
	await _enter_shop_and_purchase()
	await _click(run_screen.get_node("%ShopScreen").get_node("%LeaveShopButton"))
	await _settle()

	_assert_true(route_panel.visible, "first shop should open second route choice")
	await _click(route_panel.get_node("%RightRouteButton"))
	await _settle()
	run_screen.area_session.encounter_session.target_total = 0
	await _complete_encounter()
	await _enter_shop_and_purchase()
	run_screen.guide_auto_start = true
	await _click(run_screen.get_node("%ShopScreen").get_node("%LeaveShopButton"))
	await _settle()

	_assert_true(
		run_screen.area_session.phase == AreaRunSession.Phase.DEALER,
		"second shop should enter Iron Abacus"
	)
	var dealer_guide := run_screen.get_node("%GoldCorridorGuideOverlay")
	_assert_true(narrative.is_open(), "dealer entry should show Iron Abacus opening")
	_assert_true(
		not dealer_guide.is_open(),
		"dealer guide should wait until the opening is confirmed"
	)
	await _click_at_point(
		encounter.get_node("%ConfirmButton").get_global_rect().get_center()
	)
	_assert_true(
		not encounter.session.controller.committed,
		"dealer opening should block the encounter behind it"
	)
	_assert_true(
		"六颗骰子" in narrative.get_node("%NarrativeBody").text,
		"dealer opening should expose the confirmed Iron Abacus line"
	)
	await _click(narrative.get_node("%NarrativeContinueButton"))
	await _settle()
	_assert_true(
		not narrative.is_open(),
		"real confirmation should close the dealer opening"
	)
	_assert_true(
		dealer_guide.is_open(),
		"dealer guide should open after the narrative confirmation"
	)
	dealer_guide.close_card()
	run_screen.guide_auto_start = false
	run_screen.area_session.encounter_session.target_total = 0
	await _complete_encounter()
	var reward: EngravingRewardPanel = run_screen.get_node("%EngravingRewardPanel")
	_assert_true(reward.visible, "dealer success should open engraving reward")

	await _click(reward.get_node("%EngravingRewardModeButton"))
	var engraving_id: StringName = run_screen.area_session.engraving_offer_ids[0]
	await _click(_find_engraving_option(engraving_id))
	await _click(_find_reward_button(&"die_id", &"d1"))
	await _click(_find_reward_button(&"face", 2))
	await _click(reward.get_node("%InstallEngravingButton"))
	await _settle()

	var complete: AreaCompletePanel = run_screen.get_node("%AreaCompletePanel")
	_assert_true(
		run_screen.area_session.phase == AreaRunSession.Phase.COMPLETE,
		"formal engraving install should complete area"
	)
	_assert_true(complete.visible, "area completion should show final ledger")
	_assert_true(
		complete.get_node("%RouteHistoryLabel").text.count("\n") == 1,
		"completion should show two route rows"
	)
	_assert_true(
		complete.get_node("%PurchaseHistoryLabel").text.count("→") == 2,
		"completion should show two purchases; got: %s" % (
			complete.get_node("%PurchaseHistoryLabel").text
		)
	)
	var transaction_text: String = complete.get_node("%PurchaseHistoryLabel").text
	_assert_true(
		transaction_text.count("整批刷新") == 2,
		"completion should show both paid refreshes"
	)
	_assert_true(
		"路线情报" in transaction_text and "庄家情报" in transaction_text,
		"completion should show both purchased intel services"
	)
	_assert_equal(
		complete.get_node("%FinalResourceLabel").text,
		"剩余情报券｜%d" % int(
			run_screen.area_session.completion_snapshot()["intel_tickets"]
		),
		"completion balance should equal the domain snapshot"
	)
	_assert_true(
		complete.get_node("%FinalDeckLabel").text.split("　").size() >= 10,
		"completion should show the twelve-card deck"
	)
	var complete_phase := run_screen.area_session.phase
	await _click_at_point(Vector2(8, 8))
	_assert_true(
		run_screen.area_session.phase == complete_phase,
		"completion overlay should block encounter input"
	)

	await _click(complete.get_node("%RestartAreaButton"))
	await _settle()
	_assert_true(route_panel.visible, "restart should return to first route")
	_assert_equal(
		run_screen.area_session.current_route_ids(),
		route_order,
		"restart should replay first route order"
	)
	await _click(_route_button_for(first_room_id))
	await _settle()
	_assert_equal(
		_rolled_values(run_screen.area_session.encounter_session),
		first_dice,
		"restart should replay first-room dice"
	)

	await _fail_encounter_direct()
	var summary: RoundSummaryPanel = run_screen.get_node("%RoundSummaryPanel")
	_assert_true(
		run_screen.area_session.phase == AreaRunSession.Phase.FAILED,
		"normal-room failure should end area"
	)
	_assert_true(summary.visible, "failure should show summary")
	_assert_true(
		not summary.get_node("%RetryDealerButton").visible,
		"formal area failure should hide dealer boundary retry"
	)
	_assert_true(
		not summary.get_node("%RetryVerificationButton").visible,
		"formal area failure should hide verification boundary retry"
	)
	_assert_true(summary.get_node("%RetryRunButton").visible, "failure should offer full restart")
	await _click(summary.get_node("%RetryRunButton"))
	await _settle()
	_assert_true(
		run_screen.area_session.phase == AreaRunSession.Phase.ROUTE_CHOICE,
		"failure retry should restart the whole area"
	)
	_assert_true(run_screen.area_session.selected_room_ids.is_empty(), "retry clears route history")
	await _finish()

func _complete_encounter() -> void:
	run_screen.area_session.encounter_session.target_total = 0
	var round_count := run_screen.area_session.encounter_session.round_count
	for round_index in range(round_count):
		var encounter: SingleEncounterScreen = run_screen.get_node("%EncounterScreen")
		await _click(encounter.get_node("%ConfirmButton"))
		encounter.resolution_panel.finish_playback()
		await _settle()
		if round_index < round_count - 1:
			await _click(run_screen.get_node("%RoundSummaryPanel").get_node("%NextRoundButton"))
			await _settle()

func _fail_encounter_direct() -> void:
	run_screen.area_session.encounter_session.target_total = 999999
	var round_count := run_screen.area_session.encounter_session.round_count
	for round_index in range(round_count):
		var report := run_screen.area_session.encounter_session.current_session.commit()
		run_screen._on_round_committed(report)
		await _settle()
		if round_index < round_count - 1:
			run_screen._on_next_round_requested()
			await _settle()

func _enter_shop_and_purchase() -> void:
	var summary: RoundSummaryPanel = run_screen.get_node("%RoundSummaryPanel")
	run_screen.area_session.intel_tickets = maxi(
		run_screen.area_session.intel_tickets,
		10
	)
	await _click(summary.get_node("%EnterShopButton"))
	await _settle()
	var shop: ShopScreen = run_screen.get_node("%ShopScreen")
	_assert_true(shop.visible, "successful room should open shop")
	await _click(shop.get_node("%RefreshOffersButton"))
	await _settle()
	await _click(
		shop.get_node("%RefreshConfirmationDialog").get_ok_button()
	)
	await _settle()
	_assert_true(
		run_screen.area_session.shop_session.refresh_used,
		"formal shop refresh should accept a real confirmation click"
	)
	await _click(shop.get_node("%PurchaseIntelButton"))
	await _settle()
	_assert_true(
		run_screen.get_node("%ShopIntelPanel").visible,
		"paid intel should open its blocking overlay"
	)
	await _click(
		run_screen.get_node("%ShopIntelPanel").get_node("%CloseIntelButton")
	)
	await _settle()
	var offer := _find_shop_offer_not_in_deck()
	var deck_card := _find_shop_card(&"deck")
	_assert_true(offer != null and deck_card != null, "shop should expose offer and deck")
	if offer == null or deck_card == null:
		return
	await _click(offer)
	await _settle()
	deck_card = _find_shop_card(&"deck")
	await _click(deck_card)
	await _click(shop.get_node("%ConfirmReplacementButton"))
	await _settle()
	_assert_equal(
		shop.shop_session.purchase_records.size(),
		1,
		"real shop replacement should be recorded; shop error=%s" % (
			shop.get_node("%ShopErrorLabel").text
		)
	)

func _find_shop_card(role: StringName) -> ShopCardToken:
	for node in run_screen.find_children("*", "Button", true, false):
		if (
			node is ShopCardToken
			and not node.is_queued_for_deletion()
			and not node.disabled
			and node.role == role
		):
			return node
	return null

func _find_shop_offer_not_in_deck() -> ShopCardToken:
	for node in run_screen.find_children("*", "Button", true, false):
		if (
			node is ShopCardToken
			and not node.is_queued_for_deletion()
			and not node.disabled
			and node.role == &"offer"
			and node.card_id not in run_screen.area_session.deck_ids
		):
			return node
	return null

func _find_engraving_option(engraving_id: StringName) -> EngravingOptionToken:
	for node in run_screen.find_children("*", "Button", true, false):
		if (
			node is EngravingOptionToken
			and not node.is_queued_for_deletion()
			and node.engraving_id == engraving_id
		):
			return node
	return null

func _find_reward_button(meta_name: StringName, value: Variant) -> Button:
	for node in run_screen.find_children("*", "Button", true, false):
		if (
			node is Button
			and not node is EngravingOptionToken
			and not node.is_queued_for_deletion()
			and not node.disabled
			and node.has_meta(meta_name)
			and node.get_meta(meta_name) == value
		):
			return node
	return null

func _route_button_for(room_id: StringName) -> Button:
	var route_panel: RouteChoicePanel = run_screen.get_node("%RouteChoicePanel")
	for button in [
		route_panel.get_node("%LeftRouteButton"),
		route_panel.get_node("%RightRouteButton"),
	]:
		if button.get_meta("room_id", &"") == room_id:
			return button
	return null

func _rolled_values(session: ThreeRoundEncounterSession) -> Array[int]:
	var values: Array[int] = []
	for die in session.current_session.controller.state.dice:
		values.append(die.rolled_value)
	return values

func _click(control: Control) -> void:
	_assert_true(control != null, "click target should exist")
	if control == null:
		return
	var viewport := control.get_viewport()
	var point := control.get_global_rect().get_center()
	if viewport is Window and viewport != root:
		point += Vector2((viewport as Window).position)
		viewport = root
	await _move_pointer(point)
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

func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		failures.append("%s; expected=%s actual=%s" % [message, expected, actual])

func _finish() -> void:
	if run_screen != null:
		run_screen.queue_free()
	await process_frame
	DirAccess.remove_absolute(guide_path)
	if failures.is_empty():
		print("PASS gold_corridor_input_self_check")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
