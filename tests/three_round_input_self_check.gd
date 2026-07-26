extends SceneTree

var failures: Array[String] = []
var pointer_position := Vector2.ZERO
var run_screen: ThreeRoundRunScreen

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var teaching: SingleEncounterScreen = load(
		"res://scenes/run/single_encounter_screen.tscn"
	).instantiate()
	teaching.tutorial_auto_start = false
	root.add_child(teaching)
	current_scene = teaching
	await process_frame
	await process_frame

	await _click(teaching.get_node("%RunTrialButton"))
	await process_frame
	await process_frame
	await process_frame
	run_screen = current_scene as ThreeRoundRunScreen
	_assert_true(run_screen != null, "real entry click should open three round scene")
	if run_screen == null:
		await _finish()
		return
	run_screen.run_session.target_total = 0

	for round_number in range(1, 4):
		var encounter: SingleEncounterScreen = run_screen.get_node("%EncounterScreen")
		await _click(encounter.get_node("%ConfirmButton"))
		var summary: RoundSummaryPanel = run_screen.get_node("%RoundSummaryPanel")
		_assert_true(summary.visible, "commit should open the round summary")
		if round_number < 3:
			_assert_true(
				run_screen.run_session.status == ThreeRoundEncounterSession.Status.ROUND_SUMMARY,
				"early commit should stop at summary"
			)
			await _click(summary.get_node("%NextRoundButton"))
			_assert_true(
				run_screen.run_session.current_round == round_number + 1,
				"next-round click should advance exactly once"
			)

	var summary: RoundSummaryPanel = run_screen.get_node("%RoundSummaryPanel")
	_assert_true(
		run_screen.run_session.status == ThreeRoundEncounterSession.Status.SUCCEEDED,
		"zero target should succeed after round three"
	)
	await _click(summary.get_node("%EnterShopButton"))
	var shop: ShopScreen = run_screen.get_node("%ShopScreen")
	_assert_true(shop.visible, "shop entry click should display shop")

	var offer := _find_shop_card(&"offer")
	_assert_true(offer != null, "shop offer target should exist")
	if offer != null:
		var bought_id: StringName = offer.card_id
		await _click(offer)
		var deck_card := _find_shop_card(&"deck")
		_assert_true(deck_card != null, "shop deck target should exist")
		if deck_card != null:
			var replaced_id: StringName = deck_card.card_id
			await _click(deck_card)
			await _click(shop.get_node("%ConfirmReplacementButton"))
			_assert_true(bought_id in run_screen.shop_session.deck_ids, "bought card should enter deck")
			_assert_true(replaced_id not in run_screen.shop_session.deck_ids, "old card should leave deck")
			_assert_true(run_screen.shop_session.deck_ids.size() == 12, "deck should stay at twelve")
			_assert_true(run_screen.shop_session.intel_tickets == 1, "purchase should cost one ticket")

	await _click(shop.get_node("%LeaveShopButton"))
	_assert_true(summary.visible, "leaving shop should show stage completion")
	_assert_true(
		summary.get_node("%SummaryTitle").text == "阶段试局完成",
		"completion summary should use concrete Chinese copy"
	)
	await _finish()

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

func _click(control: Control) -> void:
	_assert_true(control != null, "click target should exist")
	if control == null:
		return
	await _click_at_point(control.get_global_rect().get_center())

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

func _assert_true(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func _finish() -> void:
	if run_screen != null:
		run_screen.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS three_round_input_self_check")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
