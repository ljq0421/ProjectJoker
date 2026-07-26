extends SceneTree

var failures: Array[String] = []
var pointer_position := Vector2.ZERO
var slice_screen: IronAbacusSliceScreen
var guide_path: String

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	guide_path = OS.get_temp_dir().path_join(
		"project-joker-stage5-guide-input-%d.cfg" % Time.get_ticks_usec()
	)
	DirAccess.remove_absolute(guide_path)

	var teaching: SingleEncounterScreen = load(
		"res://scenes/run/single_encounter_screen.tscn"
	).instantiate()
	teaching.tutorial_auto_start = false
	teaching.tutorial_config_path = guide_path
	root.add_child(teaching)
	current_scene = teaching
	await _settle()
	await _click(teaching.get_node("%RunTrialButton"))
	await _settle()

	slice_screen = current_scene as IronAbacusSliceScreen
	_assert_true(slice_screen != null, "entry should open guided Iron Abacus slice")
	if slice_screen == null:
		await _finish()
		return
	_assert_equal(
		slice_screen.guide_config_path,
		guide_path,
		"entry should pass the configured advanced-guide path"
	)
	_assert_true(slice_screen.guide_auto_start, "guided entry should keep auto-start enabled")
	_assert_false(
		slice_screen.guide_store.is_dismissed(),
		"fresh guide config should not be dismissed"
	)
	_assert_false(
		slice_screen.guide_store.is_seen(&"normal"),
		"fresh guide config should leave normal unseen"
	)
	var overlay: IronAbacusGuideOverlay = slice_screen.get_node("%IronAbacusGuideOverlay")
	_assert_true(
		overlay.size.x > 0.0 and overlay.size.y > 0.0,
		"guide overlay should have a real layout size; actual=%s" % overlay.size
	)
	_assert_false(
		slice_screen.guide_flow.should_present(
			&"normal",
			slice_screen.guide_store.snapshot()
		),
		"normal checkpoint should have been requested in this run"
	)
	_assert_true(overlay.is_open(), "normal checkpoint should open on first entry")
	_assert_true(
		overlay.active_checkpoint_id() == &"normal",
		"first card should be the normal checkpoint"
	)
	var before := _slice_snapshot()
	var encounter: SingleEncounterScreen = slice_screen.get_node("%EncounterScreen")
	await _click_at_point(encounter.get_node("%ConfirmButton").get_global_rect().get_center())
	_assert_false(
		encounter.session.controller.committed,
		"guide overlay should block background confirmation"
	)
	var acknowledge_button: Button = overlay.get_node("%GuideAcknowledgeButton")
	_assert_true(
		Rect2(Vector2.ZERO, Vector2(root.size)).encloses(
			acknowledge_button.get_global_rect()
		),
		"acknowledge button should be on screen; actual=%s card=%s minimum=%s"
			% [
				acknowledge_button.get_global_rect(),
				overlay.get_node("%GuideCard").get_global_rect(),
				overlay.get_node("%GuideCard").get_combined_minimum_size(),
			]
	)
	await _click(acknowledge_button)
	_assert_false(overlay.is_open(), "acknowledgement should close the guide card")
	_assert_equal(_slice_snapshot(), before, "acknowledgement should preserve domain snapshot")
	_assert_true(
		IronAbacusGuideProgressStore.new(guide_path).is_seen(&"normal"),
		"normal acknowledgement should persist"
	)

	slice_screen.slice_session.encounter_session.target_total = 0
	for round_number in range(1, 4):
		await _click(encounter.get_node("%ConfirmButton"))
		var summary: RoundSummaryPanel = slice_screen.get_node("%RoundSummaryPanel")
		_assert_true(summary.visible, "normal commit should show summary")
		if round_number < 3:
			await _click(summary.get_node("%NextRoundButton"))
			_assert_false(overlay.is_open(), "normal retry boundary should not repeat guide")

	var summary: RoundSummaryPanel = slice_screen.get_node("%RoundSummaryPanel")
	await _click(summary.get_node("%EnterShopButton"))
	await _settle()
	await _assert_and_ack_checkpoint(overlay, &"shop", KEY_ENTER)
	await _click(slice_screen.get_node("%ShopScreen").get_node("%LeaveShopButton"))
	slice_screen.slice_session.dealer_target = 0
	await _click(summary.get_node("%ChallengeDealerButton"))
	await _settle()
	await _assert_and_ack_checkpoint(overlay, &"dealer", KEY_ESCAPE)
	slice_screen.bind_current_encounter()
	await _settle()
	_assert_false(overlay.is_open(), "dealer rebind should not repeat acknowledged guide")

	for round_number in range(1, 4):
		encounter = slice_screen.get_node("%EncounterScreen")
		await _click(encounter.get_node("%ConfirmButton"))
		if round_number < 3:
			await _click(summary.get_node("%NextRoundButton"))
			_assert_false(overlay.is_open(), "dealer next round should not repeat guide")

	await _settle()
	await _assert_and_ack_checkpoint(overlay, &"reward", KEY_NONE)
	var reward: EngravingRewardPanel = slice_screen.get_node("%EngravingRewardPanel")
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
	await _settle()
	await _assert_and_ack_checkpoint(overlay, &"verification", KEY_NONE)
	slice_screen.bind_current_encounter()
	await _settle()
	_assert_false(overlay.is_open(), "verification rebind should not repeat guide")

	var verification: SingleEncounterScreen = slice_screen.get_node("%EncounterScreen")
	await _click(_find_die(verification, &"d1"))
	await _click_lane(verification.get_node("%RightLane"))
	await _click(verification.get_node("%ConfirmButton"))
	_assert_true(
		slice_screen.slice_session.phase == IronAbacusSliceSession.Phase.COMPLETE,
		"guided real-input path should complete verification"
	)
	var persisted := IronAbacusGuideProgressStore.new(guide_path)
	for checkpoint_id in [&"normal", &"shop", &"dealer", &"reward", &"verification"]:
		_assert_true(persisted.is_seen(checkpoint_id), "checkpoint should persist: %s" % checkpoint_id)

	_assert_true(
		TutorialProgressStore.new(guide_path).mark_done() == OK,
		"base tutorial fixture should persist before replay"
	)
	slice_screen.queue_free()
	await process_frame
	slice_screen = null
	var replay_entry: SingleEncounterScreen = load(
		"res://scenes/run/single_encounter_screen.tscn"
	).instantiate()
	replay_entry.tutorial_auto_start = false
	replay_entry.tutorial_config_path = guide_path
	root.add_child(replay_entry)
	current_scene = replay_entry
	await _settle()
	await _click(replay_entry.get_node("%ReplayAdvancedGuideButton"))
	await _settle()
	slice_screen = current_scene as IronAbacusSliceScreen
	_assert_true(slice_screen != null, "replay entry should start a fresh guided slice")
	if slice_screen != null:
		overlay = slice_screen.get_node("%IronAbacusGuideOverlay")
		_assert_true(
			overlay.is_open() and overlay.active_checkpoint_id() == &"normal",
			"replay should restore the first checkpoint"
		)
		_assert_true(
			TutorialProgressStore.new(guide_path).is_done(),
			"replay should preserve base tutorial completion"
		)
		var replay_before := _slice_snapshot()
		await _click(overlay.get_node("%GuideDismissButton"))
		_assert_false(overlay.is_open(), "permanent dismissal should close current card")
		_assert_equal(
			_slice_snapshot(),
			replay_before,
			"permanent dismissal should preserve domain snapshot"
		)
		_assert_true(
			IronAbacusGuideProgressStore.new(guide_path).is_dismissed(),
			"permanent dismissal should persist"
		)
		slice_screen._request_guide(&"shop")
		_assert_false(overlay.is_open(), "permanent dismissal should suppress later cards")
	await _finish()

func _assert_and_ack_checkpoint(
	overlay: IronAbacusGuideOverlay,
	checkpoint_id: StringName,
	keycode: Key
) -> void:
	_assert_true(overlay.is_open(), "%s checkpoint should open" % checkpoint_id)
	_assert_true(
		overlay.active_checkpoint_id() == checkpoint_id,
		"expected %s checkpoint" % checkpoint_id
	)
	var before := _slice_snapshot()
	if keycode == KEY_NONE:
		await _click(overlay.get_node("%GuideAcknowledgeButton"))
	else:
		await _press_key(keycode)
	_assert_false(overlay.is_open(), "%s checkpoint should close" % checkpoint_id)
	_assert_equal(
		_slice_snapshot(),
		before,
		"%s acknowledgement should preserve domain snapshot" % checkpoint_id
	)
	_assert_true(
		IronAbacusGuideProgressStore.new(guide_path).is_seen(checkpoint_id),
		"%s acknowledgement should persist" % checkpoint_id
	)

func _slice_snapshot() -> Dictionary:
	var run := slice_screen.slice_session
	return {
		"phase": run.phase,
		"failure_origin": run.failure_origin,
		"rng": run.run_rng.snapshot_state(),
		"deck_ids": run.deck_ids.duplicate(),
		"tickets": run.intel_tickets,
		"offers": run.engraving_offer_ids.duplicate(),
		"selected_engraving": run.selected_engraving_id,
		"installed_die": run.installed_die_id,
		"installed_face": run.installed_face,
		"profiles": _dice_snapshot(run.die_profiles),
		"encounter_run": _three_round_snapshot(run.encounter_session),
		"shop": _shop_snapshot(run.shop_session),
		"verification": _encounter_snapshot(run.verification_session),
	}

func _encounter_snapshot(session: SingleEncounterSession) -> Dictionary:
	if session == null:
		return {}
	var state := session.controller.state
	var played_cards: Array[Dictionary] = []
	for played_card in state.played_cards:
		played_cards.append({
			"id": played_card.definition.id,
			"primary": played_card.primary_target,
			"secondary": played_card.secondary_target,
		})
	var report := session.preview()
	return {
		"dice": _dice_snapshot(state.dice),
		"assignments": state.assignments.duplicate(true),
		"played_cards": played_cards,
		"calibration": state.calibration_points,
		"selection_kind": session.selection.kind,
		"selection_die": session.selection.die_id,
		"selection_card": session.selection.card_index,
		"committed": session.controller.committed,
		"history_size": session.controller._history._states.size(),
		"report_total": report.total,
		"report_events": report.event_signature(),
	}

func _dice_snapshot(dice: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for die in dice:
		result.append({
			"id": die.id,
			"rolled": die.rolled_value,
			"value": die.value,
			"engraving": die.engraving_id,
			"face": die.engraved_face,
		})
	return result

func _three_round_snapshot(run: ThreeRoundEncounterSession) -> Dictionary:
	if run == null:
		return {}
	var committed: Array = []
	for report in run.committed_reports:
		committed.append({
			"total": report.total,
			"events": report.event_signature(),
		})
	return {
		"status": run.status,
		"round": run.current_round,
		"target": run.target_total,
		"cumulative": run.cumulative_total,
		"tickets": run.intel_tickets,
		"hand_ids": run.current_hand_ids.duplicate(),
		"starter_deck": run.starter_deck_ids.duplicate(),
		"shop_offers": run.shop_offer_ids.duplicate(),
		"committed": committed,
		"current": _encounter_snapshot(run.current_session),
	}

func _shop_snapshot(shop: ShopSession) -> Dictionary:
	if shop == null:
		return {}
	return {
		"deck": shop.deck_ids.duplicate(),
		"offers": shop.offer_ids.duplicate(),
		"sold": shop.sold_offer_ids.duplicate(),
		"tickets": shop.intel_tickets,
	}

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

func _click_lane(lane: Control) -> void:
	await _click_at_point(lane.get_global_rect().position + Vector2(18, 18))

func _press_key(keycode: Key) -> void:
	var press := InputEventKey.new()
	press.keycode = keycode
	press.pressed = true
	root.push_input(press, true)
	await process_frame
	var release := InputEventKey.new()
	release.keycode = keycode
	release.pressed = false
	root.push_input(release, true)
	await process_frame

func _settle() -> void:
	await process_frame
	await process_frame
	await process_frame

func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		failures.append("%s; expected=%s actual=%s" % [message, expected, actual])

func _assert_true(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func _assert_false(value: bool, message: String) -> void:
	if value:
		failures.append(message)

func _finish() -> void:
	if slice_screen != null:
		slice_screen.queue_free()
	await process_frame
	DirAccess.remove_absolute(guide_path)
	if failures.is_empty():
		print("PASS stage5_guide_input_self_check")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
