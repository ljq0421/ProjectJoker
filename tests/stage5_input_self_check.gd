extends SceneTree

var failures: Array[String] = []
var pointer_position := Vector2.ZERO
var slice_screen: IronAbacusSliceScreen

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	await _verify_anchor_feedback()

	var teaching: SingleEncounterScreen = load(
		"res://scenes/run/single_encounter_screen.tscn"
	).instantiate()
	teaching.tutorial_auto_start = false
	root.add_child(teaching)
	current_scene = teaching
	await _settle()
	await _click(teaching.get_node("%RunTrialButton"))
	await _settle()
	slice_screen = current_scene as IronAbacusSliceScreen
	_assert_true(slice_screen != null, "real teaching entry should open Iron Abacus slice")
	if slice_screen == null:
		await _finish()
		return
	slice_screen.slice_session.encounter_session.target_total = 0

	for round_number in range(1, 4):
		var encounter: SingleEncounterScreen = slice_screen.get_node("%EncounterScreen")
		await _click(encounter.get_node("%ConfirmButton"))
		var summary: RoundSummaryPanel = slice_screen.get_node("%RoundSummaryPanel")
		_assert_true(summary.visible, "normal commit should show summary")
		if round_number < 3:
			await _click(summary.get_node("%NextRoundButton"))

	var summary: RoundSummaryPanel = slice_screen.get_node("%RoundSummaryPanel")
	await _click(summary.get_node("%EnterShopButton"))
	var shop: ShopScreen = slice_screen.get_node("%ShopScreen")
	_assert_true(shop.visible, "shop should open from real summary click")
	var offer := _find_shop_card(&"offer")
	var deck_card := _find_shop_card(&"deck")
	_assert_true(offer != null and deck_card != null, "shop should expose real offer and deck")
	if offer != null and deck_card != null:
		var bought_id: StringName = offer.card_id
		await _click(offer)
		deck_card = _find_shop_card(&"deck")
		var replaced_id: StringName = deck_card.card_id
		await _click(deck_card)
		await _click(shop.get_node("%ConfirmReplacementButton"))
		_assert_true(
			bought_id in slice_screen.slice_session.shop_session.deck_ids,
			"real purchase should enter inherited deck"
		)
		_assert_true(
			replaced_id not in slice_screen.slice_session.shop_session.deck_ids,
			"real purchase should remove replaced card"
		)
	await _click(shop.get_node("%LeaveShopButton"))
	_assert_true(summary.visible, "leaving shop should show dealer-ready summary")
	slice_screen.slice_session.dealer_target = 0
	await _click(summary.get_node("%ChallengeDealerButton"))

	for round_number in range(1, 4):
		var encounter: SingleEncounterScreen = slice_screen.get_node("%EncounterScreen")
		if round_number == 3:
			await _click(_find_die(encounter, &"d1"))
		await _click(encounter.get_node("%ConfirmButton"))
		if round_number < 3:
			await _click(summary.get_node("%NextRoundButton"))

	var reward: EngravingRewardPanel = slice_screen.get_node("%EngravingRewardPanel")
	_assert_true(reward.visible, "dealer success should open engraving reward")
	var dealer_encounter: SingleEncounterScreen = slice_screen.get_node("%EncounterScreen")
	var selected_die_before := (
		slice_screen.slice_session.encounter_session.current_session.controller.state
		.find_die(&"d1")
	)
	var value_before := selected_die_before.value
	var points_before := (
		slice_screen.slice_session.encounter_session.current_session.controller.state
		.calibration_points
	)
	await _click_at_point(dealer_encounter.get_node("%PlusButton").get_global_rect().get_center())
	_assert_true(
		slice_screen.slice_session.encounter_session.current_session.controller.state
		.find_die(&"d1").value == value_before,
		"reward overlay should block die changes"
	)
	_assert_true(
		slice_screen.slice_session.encounter_session.current_session.controller.state
		.calibration_points == points_before,
		"reward overlay should block calibration spending"
	)

	var engraving_id := (
		&"engraving_prism"
		if &"engraving_prism" in slice_screen.slice_session.engraving_offer_ids
		else &"engraving_anchor"
	)
	var face := 1 if engraving_id == &"engraving_prism" else 2
	await _click(_find_engraving_option(engraving_id))
	await _click(_find_reward_button(&"die_id", &"d1"))
	await _click(_find_reward_button(&"face", face))
	await _click(reward.get_node("%InstallEngravingButton"))
	_assert_true(
		slice_screen.slice_session.phase == IronAbacusSliceSession.Phase.VERIFICATION,
		"real install should enter verification"
	)

	var verification: SingleEncounterScreen = slice_screen.get_node("%EncounterScreen")
	await _click(_find_die(verification, &"d1"))
	await _click_lane(verification.get_node("%RightLane"))
	await _click(verification.get_node("%ConfirmButton"))
	_assert_true(
		slice_screen.slice_session.phase == IronAbacusSliceSession.Phase.COMPLETE,
		"applied engraving should complete the slice"
	)
	var report := slice_screen.slice_session.verification_session.commit()
	_assert_true(
		report.events.any(
			func(event: ResolutionEvent) -> bool: return (
				event.source_id == engraving_id and event.effect_applied
			)
		),
		"complete verification should expose matching applied event"
	)
	_assert_true(summary.visible, "completion should show summary")
	_assert_true(
		"刻印验证完成" in summary.get_node("%SummaryTitle").text,
		"completion summary should use concrete Chinese copy"
	)
	await _finish()

func _verify_anchor_feedback() -> void:
	var screen: SingleEncounterScreen = load(
		"res://scenes/run/single_encounter_screen.tscn"
	).instantiate()
	screen.tutorial_auto_start = false
	root.add_child(screen)
	await _settle()
	var state := SingleEncounterFixture.make_state()
	var d1 := state.find_die(&"d1")
	d1.engraving_id = &"engraving_anchor"
	d1.engraved_face = d1.rolled_value
	var session := SingleEncounterSession.new(
		state,
		SingleEncounterFixture.make_encounter(),
		SingleEncounterFixture.make_hand(),
		ResolutionContext.new(null, EngravingCatalog.new())
	)
	screen.bind_dealer(null)
	screen.bind_external_session(session, "锚定反馈检查", "拒绝必须可见且原子")
	await _settle()

	await _click(_find_die(screen, &"d1"))
	await _click(screen.get_node("%PlusButton"))
	_assert_true(session.controller.state.find_die(&"d1").value == 1, "anchor blocks calibration")
	_assert_true(session.controller.state.calibration_points == 2, "anchor preserves points")
	_assert_true("锚定" in screen.get_node("%ErrorLabel").text, "anchor reason should be visible")

	await _click(_find_card(screen, 0))
	await _click(_find_die(screen, &"d1"))
	_assert_true(session.controller.state.played_cards.is_empty(), "anchor blocks adjust card")
	_assert_true("锚定" in screen.get_node("%ErrorLabel").text, "card rejection should be visible")
	_assert_true(not session.controller.undo(), "anchor rejection should not create undo history")
	screen.queue_free()
	await process_frame

func _find_shop_card(role: StringName) -> ShopCardToken:
	for node in slice_screen.find_children("*", "Button", true, false):
		if (
			node is ShopCardToken
			and not node.is_queued_for_deletion()
			and not node.disabled
			and node.role == role
		):
			return node
	return null

func _find_engraving_option(engraving_id: StringName) -> EngravingOptionToken:
	for node in slice_screen.find_children("*", "Button", true, false):
		if (
			node is EngravingOptionToken
			and not node.is_queued_for_deletion()
			and node.engraving_id == engraving_id
		):
			return node
	return null

func _find_reward_button(meta_name: StringName, value: Variant) -> Button:
	for node in slice_screen.find_children("*", "Button", true, false):
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

func _find_die(parent: Node, die_id: StringName) -> DieToken:
	for node in parent.find_children("*", "Button", true, false):
		if (
			node is DieToken
			and not node.is_queued_for_deletion()
			and node.die_id == die_id
		):
			return node
	return null

func _find_card(parent: Node, card_index: int) -> CardToken:
	for node in parent.find_children("*", "Button", true, false):
		if (
			node is CardToken
			and not node.is_queued_for_deletion()
			and node.card_index == card_index
		):
			return node
	return null

func _click(control: Control) -> void:
	_assert_true(control != null, "click target should exist")
	if control == null:
		return
	await _click_at_point(control.get_global_rect().get_center())

func _click_lane(lane: Control) -> void:
	await _click_at_point(lane.get_global_rect().position + Vector2(18, 18))

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

func _finish() -> void:
	if slice_screen != null:
		slice_screen.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS stage5_input_self_check")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
