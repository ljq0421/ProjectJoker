extends SceneTree

var failures: Array[String] = []
var pointer_position := Vector2.ZERO
var run_screen: MirrorHallRunScreen
var guide_path: String

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	guide_path = OS.get_temp_dir().path_join(
		"project-joker-mirror-e2e-%d.cfg" % Time.get_ticks_usec()
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
	await _click(entry.get_node("%MirrorHallRunButton"))
	await _settle()

	run_screen = current_scene as MirrorHallRunScreen
	_assert_true(run_screen != null, "main entry should open Mirror Hall")
	if run_screen == null:
		await _finish()
		return
	run_screen.guide_auto_start = false
	run_screen.get_node("%MirrorHallGuideOverlay").close_card()
	var route_panel: RouteChoicePanel = run_screen.get_node("%RouteChoicePanel")
	await _click(route_panel.get_node("%LeftRouteButton"))
	await _settle()
	await _exercise_mirror_undo_and_replay()
	await _complete_three_rounds()
	await _enter_shop_and_purchase()
	await _click(run_screen.get_node("%ShopScreen").get_node("%LeaveShopButton"))
	await _settle()

	await _click(route_panel.get_node("%RightRouteButton"))
	await _settle()
	await _complete_three_rounds()
	await _enter_shop_and_purchase()
	await _click(run_screen.get_node("%ShopScreen").get_node("%LeaveShopButton"))
	await _settle()

	_assert_equal(
		run_screen.area_session.phase,
		AreaRunSession.Phase.DEALER,
		"second shop should enter Mirror Lady"
	)
	_assert_equal(
		run_screen.area_session.area_definition.dealer_id,
		&"dealer_mirror_lady",
		"dealer should be Mirror Lady"
	)
	_assert_true(
		"镜面夫人" in run_screen.get_node("%EncounterScreen").get_node("%DealerName").text,
		"dealer page should name Mirror Lady"
	)
	await _complete_three_rounds()

	var reward: EngravingRewardPanel = run_screen.get_node("%EngravingRewardPanel")
	_assert_true(reward.visible, "dealer success should open three engraving offers")
	_assert_equal(
		reward.get_node("%OfferRow").get_child_count(),
		3,
		"reward should expose exactly three engravings"
	)
	var engraving_id: StringName = run_screen.area_session.engraving_offer_ids[0]
	await _click(_find_engraving_option(engraving_id))
	await _click(_find_reward_button(&"die_id", &"d1"))
	await _click(_find_reward_button(&"face", 2))
	await _click(reward.get_node("%InstallEngravingButton"))
	await _settle()

	var snapshot := run_screen.area_session.completion_snapshot()
	_assert_equal(snapshot.get("area_id"), &"mirror_hall", "completion should identify Mirror Hall")
	_assert_equal(
		snapshot.get("dealer", {}).get("id"),
		&"dealer_mirror_lady",
		"completion should retain Mirror Lady"
	)
	_assert_equal(snapshot.get("deck_ids", []).size(), 12, "completion should retain twelve cards")
	_assert_true(snapshot.get("intel_tickets") is int, "completion should retain resources")
	_assert_equal(snapshot.get("die_profiles", []).size(), 6, "completion should retain six dice")
	_assert_true(snapshot.get("rng_state") is int, "completion should retain deterministic RNG")
	_assert_equal(snapshot.get("rooms", []).size(), 2, "completion should retain both rooms")
	_assert_equal(snapshot.get("purchases", []).size(), 2, "completion should retain both swaps")
	_assert_true(
		run_screen.get_node("%AreaCompletePanel").visible,
		"completion ledger should be visible"
	)
	_assert_true(
		"反照牌厅" in run_screen.get_node("%AreaCompletePanel").get_node("%CompleteTitle").text,
		"completion ledger should use Mirror Hall copy"
	)
	await _finish()

func _exercise_mirror_undo_and_replay() -> void:
	var encounter: SingleEncounterScreen = run_screen.get_node("%EncounterScreen")
	var card_index := _find_mirror_gap_card_index(encounter)
	_assert_true(card_index >= 0, "fixed first hand should contain a mirror GAP card")
	if card_index < 0:
		return
	await _click(_find_hand_card(encounter, card_index))
	await _click(encounter.get_node("%LeftGap"))
	await _settle()
	var played := encounter.session.controller.state.played_cards
	_assert_equal(played.size(), 2, "real mirror play should create original and one copy")
	_assert_true(played[1].is_mirror_copy, "second played card should be the mirror copy")
	var preview_signature := encounter.session.preview().event_signature()

	await _click(encounter.get_node("%UndoButton"))
	await _settle()
	_assert_true(
		encounter.session.controller.state.played_cards.is_empty(),
		"one undo should remove original and mirror copy atomically"
	)
	await _click(_find_hand_card(encounter, card_index))
	await _click(encounter.get_node("%LeftGap"))
	await _settle()
	_assert_equal(
		encounter.session.preview().event_signature(),
		preview_signature,
		"replaying the same card should restore the same preview events"
	)

func _complete_three_rounds() -> void:
	run_screen.area_session.encounter_session.target_total = 0
	for round_number in range(1, 4):
		var encounter: SingleEncounterScreen = run_screen.get_node("%EncounterScreen")
		await _click(encounter.get_node("%ConfirmButton"))
		await _settle()
		if round_number < 3:
			await _click(
				run_screen.get_node("%RoundSummaryPanel").get_node("%NextRoundButton")
			)
			await _settle()

func _enter_shop_and_purchase() -> void:
	await _click(
		run_screen.get_node("%RoundSummaryPanel").get_node("%EnterShopButton")
	)
	await _settle()
	var shop: ShopScreen = run_screen.get_node("%ShopScreen")
	_assert_true(shop.visible, "successful room should open its shop")
	var offer := _find_shop_card(&"offer")
	var deck_card := _find_shop_card(&"deck")
	_assert_true(offer != null and deck_card != null, "shop should expose both card roles")
	if offer == null or deck_card == null:
		return
	await _click(offer)
	await _settle()
	await _click(_find_shop_card(&"deck"))
	await _click(shop.get_node("%ConfirmReplacementButton"))
	await _settle()
	_assert_equal(
		run_screen.area_session.shop_session.purchase_records.size(),
		1,
		"each shop should record one real replacement"
	)

func _find_mirror_gap_card_index(encounter: SingleEncounterScreen) -> int:
	for index in range(encounter.session.hand.size()):
		var card := encounter.session.hand[index]
		if (
			card.target_type == CardDefinition.TargetType.GAP
			and not card.mirror_effects.is_empty()
		):
			return index
	return -1

func _find_hand_card(encounter: SingleEncounterScreen, index: int) -> CardToken:
	for node in encounter.find_children("*", "Button", true, false):
		if (
			node is CardToken
			and not node.is_queued_for_deletion()
			and node.card_index == index
		):
			return node
	return null

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

func _click(control: Control) -> void:
	_assert_true(control != null, "click target should exist")
	if control == null:
		return
	await _click_at_point(control.get_global_rect().get_center())

func _click_at_point(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.relative = point - pointer_position
	root.push_input(motion, true)
	pointer_position = point
	await process_frame
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
	if is_instance_valid(run_screen):
		run_screen.queue_free()
	await process_frame
	DirAccess.remove_absolute(guide_path)
	if failures.is_empty():
		print("PASS mirror_hall_end_to_end_self_check")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
