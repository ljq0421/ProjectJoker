extends SceneTree

var failures: Array[String] = []
var pointer_position := Vector2.ZERO
var run_screen: GoldCorridorRunScreen
var guide_path: String
var cleanup_paths: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	await _verify_replay_entry_isolation()
	await _verify_replay_entry_reset_failure()
	await _verify_real_checkpoint_path()
	await _verify_dismiss_all_path()
	await _verify_corrupt_config_fails_open()
	await _verify_write_failure_fails_open()
	await _verify_missing_target_fails_open()
	await _finish()

func _verify_replay_entry_isolation() -> void:
	var path := _temporary_config_path("entry-replay")
	var config := ConfigFile.new()
	config.set_value("onboarding", "done", true)
	config.set_value("iron_abacus_guide_v1", "seen_shop", true)
	config.set_value("gold_corridor_guide_v1", "dismissed", true)
	for checkpoint_key in ["seen_route", "seen_shop", "seen_dealer", "seen_engraving"]:
		config.set_value("gold_corridor_guide_v1", checkpoint_key, true)
	_assert_equal(config.save(path), OK, "replay-isolation fixture should persist")
	var entry: SingleEncounterScreen = load(
		"res://scenes/run/single_encounter_screen.tscn"
	).instantiate()
	entry.tutorial_auto_start = false
	entry.tutorial_config_path = path
	root.add_child(entry)
	current_scene = entry
	await _settle()
	var replay_button := entry.get_node_or_null("%ReplayGoldCorridorGuideButton") as Button
	_assert_true(replay_button != null, "region replay entry should expose a button")
	if replay_button == null:
		entry.queue_free()
		await process_frame
		current_scene = null
		return
	await _click(replay_button)
	await _settle()
	run_screen = current_scene as GoldCorridorRunScreen
	_assert_true(run_screen != null, "region replay entry should open Gold Corridor")
	if run_screen == null:
		return
	_assert_equal(
		run_screen.guide_config_path,
		path,
		"region replay should pass its configured guide path"
	)
	var overlay: IronAbacusGuideOverlay = run_screen.get_node("%GoldCorridorGuideOverlay")
	_assert_checkpoint_open(overlay, &"route", "region replay route")
	var reloaded := ConfigFile.new()
	_assert_equal(reloaded.load(path), OK, "replay config should remain readable")
	_assert_true(
		bool(reloaded.get_value("onboarding", "done", false)),
		"region replay should preserve base tutorial completion"
	)
	_assert_true(
		bool(reloaded.get_value("iron_abacus_guide_v1", "seen_shop", false)),
		"region replay should preserve Iron Abacus guide progress"
	)
	await _free_screen()

func _verify_replay_entry_reset_failure() -> void:
	var missing_parent := OS.get_temp_dir().path_join(
		"project-joker-gold-guide-entry-missing-%d" % Time.get_ticks_usec()
	)
	var path := missing_parent.path_join("onboarding.cfg")
	var entry: SingleEncounterScreen = load(
		"res://scenes/run/single_encounter_screen.tscn"
	).instantiate()
	entry.tutorial_auto_start = false
	entry.tutorial_config_path = path
	root.add_child(entry)
	current_scene = entry
	await _settle()
	var replay_button := entry.get_node_or_null("%ReplayGoldCorridorGuideButton") as Button
	_assert_true(replay_button != null, "region replay entry should expose a button on reset failure")
	if replay_button == null:
		entry.queue_free()
		await process_frame
		current_scene = null
		return
	replay_button.emit_signal("pressed")
	await _settle()
	_assert_true(current_scene == entry, "failed region reset should keep the player on entry")
	_assert_true(
		"无法重置区域提示；仍可正常进入六面诡局。" in entry.get_node("%ErrorLabel").text,
		"failed region reset should show the visible normal-entry warning"
	)
	await _free_screen()

func _verify_real_checkpoint_path() -> void:
	guide_path = _temporary_config_path("real")
	await _open_fresh_screen(guide_path)
	var overlay: IronAbacusGuideOverlay = (
		run_screen.get_node("%GoldCorridorGuideOverlay")
	)
	var route_panel: RouteChoicePanel = run_screen.get_node("%RouteChoicePanel")
	_assert_checkpoint_open(overlay, &"route", "first route")
	await _click_at_point(
		route_panel.get_node("%LeftRouteButton").get_global_rect().get_center()
	)
	_assert_true(
		run_screen.area_session.phase == AreaRunSession.Phase.ROUTE_CHOICE,
		"route guide should block the underlying route button"
	)
	await _acknowledge_without_domain_change(overlay, &"route")
	_assert_seen_only(guide_path, [&"route"], "route acknowledgement")

	await _click(route_panel.get_node("%LeftRouteButton"))
	await _settle()
	await _complete_three_rounds()
	await _click(run_screen.get_node("%RoundSummaryPanel").get_node("%EnterShopButton"))
	await _settle()
	_assert_checkpoint_open(overlay, &"shop", "first shop")
	var before_shop := _area_snapshot()
	await _press_key(KEY_ENTER)
	_assert_false(overlay.is_open(), "Enter should close the shop guide")
	_assert_equal(_area_snapshot(), before_shop, "shop guide must preserve area state")
	_assert_seen_only(guide_path, [&"route", &"shop"], "shop acknowledgement")

	await _click(run_screen.get_node("%ShopScreen").get_node("%LeaveShopButton"))
	await _settle()
	_assert_false(overlay.is_open(), "second route should not open a route guide")
	route_panel = run_screen.get_node("%RouteChoicePanel")
	await _click(route_panel.get_node("%RightRouteButton"))
	await _settle()
	await _complete_three_rounds()
	await _click(run_screen.get_node("%RoundSummaryPanel").get_node("%EnterShopButton"))
	await _settle()
	_assert_false(overlay.is_open(), "second shop should not open a shop guide")
	await _click(run_screen.get_node("%ShopScreen").get_node("%LeaveShopButton"))
	await _settle()
	_assert_checkpoint_open(overlay, &"dealer", "dealer")
	var before_dealer := _area_snapshot()
	await _press_key(KEY_ESCAPE)
	_assert_false(overlay.is_open(), "Escape should close the dealer guide")
	_assert_equal(_area_snapshot(), before_dealer, "dealer guide must preserve area state")
	_assert_seen_only(
		guide_path,
		[&"route", &"shop", &"dealer"],
		"dealer acknowledgement"
	)

	await _complete_three_rounds()
	await _settle()
	_assert_checkpoint_open(overlay, &"engraving", "engraving reward")
	await _acknowledge_without_domain_change(overlay, &"engraving")
	_assert_seen_only(
		guide_path,
		[&"route", &"shop", &"dealer", &"engraving"],
		"engraving acknowledgement"
	)

	var reward: EngravingRewardPanel = run_screen.get_node("%EngravingRewardPanel")
	var engraving_id: StringName = run_screen.area_session.engraving_offer_ids[0]
	await _click(_find_engraving_option(engraving_id))
	await _click(_find_reward_button(&"die_id", &"d1"))
	await _click(_find_reward_button(&"face", 2))
	await _click(reward.get_node("%InstallEngravingButton"))
	await _settle()
	_assert_true(
		run_screen.area_session.phase == AreaRunSession.Phase.COMPLETE,
		"formal engraving should complete the area directly"
	)
	_assert_false(
		overlay.is_open(),
		"completion should not open a verification checkpoint"
	)
	await _free_screen()

func _verify_dismiss_all_path() -> void:
	var path := _temporary_config_path("dismiss")
	await _open_fresh_screen(path)
	var overlay: IronAbacusGuideOverlay = (
		run_screen.get_node("%GoldCorridorGuideOverlay")
	)
	_assert_checkpoint_open(overlay, &"route", "dismiss route")
	var before := _area_snapshot()
	await _click(overlay.get_node("%GuideDismissButton"))
	_assert_equal(_area_snapshot(), before, "dismiss all must preserve area state")
	_assert_false(overlay.is_open(), "dismiss all should close the overlay")
	var persisted := GoldCorridorGuideProgressStore.new(path)
	_assert_true(persisted.is_dismissed(), "dismiss all should persist dismissed=true")
	for checkpoint_id in [&"route", &"shop", &"dealer", &"engraving"]:
		_assert_false(
			persisted.is_seen(checkpoint_id),
			"dismiss all should not mark %s seen" % checkpoint_id
		)

	var room_id: StringName = run_screen.area_session.current_route_ids()[0]
	run_screen._on_route_selected(room_id)
	await _settle()
	await _complete_three_rounds_direct()
	run_screen._on_shop_requested()
	await _settle()
	_assert_true(
		run_screen.area_session.phase == AreaRunSession.Phase.SHOP,
		"dismiss fixture should reach the first shop"
	)
	_assert_false(overlay.is_open(), "dismiss all should suppress the first shop prompt")
	await _free_screen()

func _verify_corrupt_config_fails_open() -> void:
	var path := _temporary_config_path("corrupt")
	var file := FileAccess.open(path, FileAccess.WRITE)
	_assert_true(file != null, "corrupt guide fixture should be writable")
	if file != null:
		file.store_string("[broken\nvalue")
		file.close()
	await _open_fresh_screen(path)
	var overlay: IronAbacusGuideOverlay = (
		run_screen.get_node("%GoldCorridorGuideOverlay")
	)
	_assert_checkpoint_open(overlay, &"route", "corrupt config route")
	_assert_true(
		"无法读取区域提示状态" in (
			run_screen.get_node("%RouteChoicePanel").get_node("%RouteErrorLabel").text
		),
		"corrupt config should show a visible load warning"
	)
	await _click(overlay.get_node("%GuideAcknowledgeButton"))
	_assert_false(overlay.is_open(), "corrupt config acknowledgement should close overlay")
	var bytes := FileAccess.get_file_as_string(path)
	_assert_equal(bytes, "[broken\nvalue", "corrupt config bytes must remain unchanged")
	await _free_screen()

func _verify_write_failure_fails_open() -> void:
	var missing_parent := OS.get_temp_dir().path_join(
		"project-joker-gold-guide-missing-%d" % Time.get_ticks_usec()
	)
	var path := missing_parent.path_join("onboarding.cfg")
	await _open_fresh_screen(path)
	var overlay: IronAbacusGuideOverlay = (
		run_screen.get_node("%GoldCorridorGuideOverlay")
	)
	_assert_checkpoint_open(overlay, &"route", "write failure route")
	await _click(overlay.get_node("%GuideAcknowledgeButton"))
	_assert_false(overlay.is_open(), "write failure acknowledgement should close overlay")
	var route_panel: RouteChoicePanel = run_screen.get_node("%RouteChoicePanel")
	_assert_true(
		"无法保存区域提示状态" in route_panel.get_node("%RouteErrorLabel").text,
		"write failure should show a visible save warning"
	)
	await _click(route_panel.get_node("%LeftRouteButton"))
	await _settle()
	_assert_true(
		run_screen.area_session.phase == AreaRunSession.Phase.NORMAL_ROOM,
		"write failure must leave the route selectable"
	)
	await _free_screen()

func _verify_missing_target_fails_open() -> void:
	var path := _temporary_config_path("missing-target")
	var screen: GoldCorridorRunScreen = load(
		"res://scenes/run/gold_corridor_run_screen.tscn"
	).instantiate()
	screen.guide_auto_start = false
	screen.guide_config_path = path
	root.add_child(screen)
	current_scene = screen
	run_screen = screen
	await _settle()
	var route_page: Control = (
		run_screen.get_node("%RouteChoicePanel").get_node(
			"SafeArea/RouteLedger/LedgerColumn/RoutePages/LeftRoutePage"
		)
	)
	route_page.free()
	run_screen.guide_auto_start = true
	run_screen._request_guide(&"route")
	var overlay: IronAbacusGuideOverlay = (
		run_screen.get_node("%GoldCorridorGuideOverlay")
	)
	_assert_false(overlay.is_open(), "missing target should fail open without a card")
	_assert_true(
		run_screen.area_session.phase == AreaRunSession.Phase.ROUTE_CHOICE,
		"missing target should preserve route choice"
	)
	await _free_screen()

func _open_fresh_screen(path: String) -> void:
	var screen: GoldCorridorRunScreen = load(
		"res://scenes/run/gold_corridor_run_screen.tscn"
	).instantiate()
	screen.guide_config_path = path
	root.add_child(screen)
	current_scene = screen
	run_screen = screen
	await _settle()

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

func _complete_three_rounds_direct() -> void:
	run_screen.area_session.encounter_session.target_total = 0
	for round_number in range(1, 4):
		var report := (
			run_screen.area_session.encounter_session.current_session.commit()
		)
		run_screen._on_round_committed(report)
		await _settle()
		if round_number < 3:
			run_screen._on_next_round_requested()
			await _settle()

func _area_snapshot() -> Dictionary:
	return {
		"phase": run_screen.area_session.phase,
		"route_ids": run_screen.area_session.route_ids.duplicate(),
		"selected_room_ids": run_screen.area_session.selected_room_ids.duplicate(),
		"completed_rooms": run_screen.area_session.completed_rooms.duplicate(true),
		"deck_ids": run_screen.area_session.deck_ids.duplicate(),
		"intel_tickets": run_screen.area_session.intel_tickets,
		"die_profiles": _profile_signatures(),
		"rng_state": run_screen.area_session.run_rng.snapshot_state(),
		"room_index": run_screen.area_session.room_index,
		"encounter": _encounter_snapshot(),
		"shop": _shop_snapshot(),
		"engraving_offer_ids": (
			run_screen.area_session.engraving_offer_ids.duplicate()
		),
		"selected_engraving_id": (
			run_screen.area_session.selected_engraving_id
		),
		"installed_die_id": run_screen.area_session.installed_die_id,
		"installed_face": run_screen.area_session.installed_face,
	}

func _profile_signatures() -> Array[String]:
	var signatures: Array[String] = []
	for profile in run_screen.area_session.die_profiles:
		signatures.append("%s|%d|%d|%s|%d" % [
			profile.id,
			profile.rolled_value,
			profile.value,
			profile.engraving_id,
			profile.engraved_face,
		])
	return signatures

func _encounter_snapshot() -> Dictionary:
	var encounter := run_screen.area_session.encounter_session
	if encounter == null:
		return {}
	var round_state := encounter.current_session.controller.state
	var dice: Array[String] = []
	for die in round_state.dice:
		dice.append("%s|%d|%d|%s|%d" % [
			die.id,
			die.rolled_value,
			die.value,
			die.engraving_id,
			die.engraved_face,
		])
	var reports: Array = []
	for report in encounter.committed_reports:
		reports.append({
			"total": report.total,
			"events": report.event_signature(),
		})
	return {
		"status": encounter.status,
		"current_round": encounter.current_round,
		"target_total": encounter.target_total,
		"cumulative_total": encounter.cumulative_total,
		"intel_tickets": encounter.intel_tickets,
		"hand_ids": encounter.current_hand_ids.duplicate(),
		"reports": reports,
		"dice": dice,
		"assignments": round_state.assignments.duplicate(true),
		"calibration_points": round_state.calibration_points,
		"played_card_count": round_state.played_cards.size(),
	}

func _shop_snapshot() -> Dictionary:
	var shop := run_screen.area_session.shop_session
	if shop == null:
		return {}
	var records: Array[String] = []
	for record in shop.purchase_records:
		records.append("%s|%s|%d" % [
			record.offer_id,
			record.replaced_id,
			record.price,
		])
	return {
		"deck_ids": shop.deck_ids.duplicate(),
		"offer_ids": shop.offer_ids.duplicate(),
		"sold_offer_ids": shop.sold_offer_ids.duplicate(),
		"intel_tickets": shop.intel_tickets,
		"records": records,
	}

func _acknowledge_without_domain_change(
	overlay: IronAbacusGuideOverlay,
	checkpoint_id: StringName
) -> void:
	var before := _area_snapshot()
	_assert_true(overlay.active_checkpoint_id() == checkpoint_id)
	await _click(overlay.get_node("%GuideAcknowledgeButton"))
	_assert_equal(_area_snapshot(), before, "%s guide must preserve area state" % checkpoint_id)

func _assert_seen_only(
	path: String,
	seen_ids: Array,
	label: String
) -> void:
	var persisted := GoldCorridorGuideProgressStore.new(path)
	_assert_false(persisted.is_dismissed(), "%s should not dismiss all" % label)
	for checkpoint_id in [&"route", &"shop", &"dealer", &"engraving"]:
		_assert_equal(
			persisted.is_seen(checkpoint_id),
			checkpoint_id in seen_ids,
			"%s seen state for %s" % [label, checkpoint_id]
		)

func _assert_checkpoint_open(
	overlay: IronAbacusGuideOverlay,
	checkpoint_id: StringName,
	label: String
) -> void:
	_assert_true(overlay.is_open(), "%s checkpoint should open" % label)
	_assert_true(
		overlay.active_checkpoint_id() == checkpoint_id,
		"%s should open checkpoint %s" % [label, checkpoint_id]
	)

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

func _temporary_config_path(label: String) -> String:
	var path := OS.get_temp_dir().path_join(
		"project-joker-gold-guide-%s-%d.cfg" % [label, Time.get_ticks_usec()]
	)
	DirAccess.remove_absolute(path)
	cleanup_paths.append(path)
	return path

func _free_screen() -> void:
	if run_screen != null:
		run_screen.queue_free()
	await process_frame
	run_screen = null
	current_scene = null

func _settle() -> void:
	await process_frame
	await process_frame
	await process_frame

func _assert_true(value: bool, message: String = "assertion should be true") -> void:
	if not value:
		failures.append(message)

func _assert_false(value: bool, message: String) -> void:
	if value:
		failures.append(message)

func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		failures.append("%s; expected=%s actual=%s" % [message, expected, actual])

func _finish() -> void:
	await _free_screen()
	for path in cleanup_paths:
		DirAccess.remove_absolute(path)
	if failures.is_empty():
		print("PASS gold_corridor_guide_input_self_check")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
