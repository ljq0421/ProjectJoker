extends SceneTree

const LOGICAL_SIZE := Vector2i(1920, 1080)
const RENDERED_SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080)]

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.content_scale_size = LOGICAL_SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	for rendered_size in RENDERED_SIZES:
		await _verify_entry(rendered_size)
		await _verify_area(rendered_size)
	if failures.is_empty():
		print("PASS mirror_hall_layout_self_check")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _verify_entry(rendered_size: Vector2i) -> void:
	root.size = rendered_size
	var label := _size_label(rendered_size)
	var entry: SingleEncounterScreen = load(
		"res://scenes/run/single_encounter_screen.tscn"
	).instantiate()
	entry.tutorial_auto_start = false
	root.add_child(entry)
	await _settle()
	var bounds := entry.get_global_rect()
	for node_path in [
		"%PracticeEntryGroup",
		"%AreaTrialEntryGroup",
		"%ReplayTutorialButton",
		"%ReplayAdvancedGuideButton",
		"%RunTrialButton",
		"%ReplayGoldCorridorGuideButton",
		"%MirrorHallRunButton",
		"%ReplayMirrorHallGuideButton",
	]:
		_assert_inside(
			bounds,
			entry.get_node(node_path).get_global_rect(),
			"%s entry %s" % [label, node_path]
		)
	entry.queue_free()
	await process_frame

func _verify_area(rendered_size: Vector2i) -> void:
	root.size = rendered_size
	var label := _size_label(rendered_size)
	var screen: MirrorHallRunScreen = load(
		"res://scenes/run/mirror_hall_run_screen.tscn"
	).instantiate()
	screen.guide_auto_start = false
	root.add_child(screen)
	await _settle()
	_assert_equal(
		Vector2i(screen.size),
		LOGICAL_SIZE,
		"%s should preserve the logical canvas" % label
	)
	var route: RouteChoicePanel = screen.get_node("%RouteChoicePanel")
	_assert_modal(screen, route, "%s route" % label)
	var room_id: StringName = route.get_node("%LeftRouteButton").get_meta("room_id")
	screen._on_route_selected(room_id)
	await _settle()
	var encounter: SingleEncounterScreen = screen.get_node("%EncounterScreen")
	for node_path in [
		"%DirectionBadge",
		"%LeftLane",
		"%LeftGap",
		"%MiddleLane",
		"%RightGap",
		"%RightLane",
		"%DiceTray",
		"%Hand",
		"%ResolutionPanel",
	]:
		_assert_inside(
			screen.get_global_rect(),
			encounter.get_node(node_path).get_global_rect(),
			"%s encounter %s" % [label, node_path]
		)
	_play_first_mirror_card(encounter)
	await _settle()
	var mirror_layer: Control = (
		encounter.get_node("%LeftMirrorLayer")
		if encounter.get_node("%LeftMirrorLayer").visible
		else encounter.get_node("%RightMirrorLayer")
	)
	_assert_true(mirror_layer.visible, "%s should show a mirror layer" % label)
	_assert_inside(
		screen.get_global_rect(),
		mirror_layer.get_global_rect(),
		"%s mirror layer" % label
	)
	_assert_true(
		not mirror_layer.get_global_rect().intersects(
			encounter.get_node("%Hand").get_global_rect()
		),
		"%s mirror layer must not cover the hand" % label
	)
	var mirror_event_found := false
	for row in encounter.get_node("%ResolutionPanel").get_node("%EventList").get_children():
		if row.get_meta("is_mirror_copy", false):
			mirror_event_found = (
				not String(row.get_meta("source_card_id", "")).is_empty()
				and not String(row.get_meta("source_slot_id", "")).is_empty()
				and not String(row.get_meta("mirror_slot_id", "")).is_empty()
			)
	_assert_true(
		mirror_event_found,
		"%s resolution trace should retain mirror source and endpoints" % label
	)
	_assert_true(
		screen.get_node("%RoundSummaryPanel").z_index
			< screen.get_node("%RouteChoicePanel").z_index
			and screen.get_node("%RouteChoicePanel").z_index
				< screen.get_node("%EngravingRewardPanel").z_index
			and screen.get_node("%EngravingRewardPanel").z_index
				< screen.get_node("%AreaCompletePanel").z_index
			and screen.get_node("%AreaCompletePanel").z_index
				< screen.get_node("%MirrorHallGuideOverlay").z_index,
		"%s modal z-order should be summary < route < reward < complete < guide"
			% label
	)
	await _force_failure(screen)
	_assert_true(
		"反照牌厅" in screen.get_node("%RoundSummaryPanel").get_node("%SummaryTitle").text,
		"%s failure title should name Mirror Hall" % label
	)
	_assert_equal(
		screen.get_node("%RoundSummaryPanel").get_node("%RetryRunButton").text,
		"重新开始反照牌厅",
		"%s failure retry should name Mirror Hall" % label
	)
	_assert_modal(
		screen,
		screen.get_node("%RoundSummaryPanel"),
		"%s failure summary" % label
	)
	screen._on_restart_requested()
	await _settle()
	await _force_completion(screen)
	_assert_true(
		"反照牌厅" in screen.get_node("%AreaCompletePanel").get_node("%CompleteTitle").text,
		"%s completion title should name Mirror Hall" % label
	)
	_assert_modal(
		screen,
		screen.get_node("%AreaCompletePanel"),
		"%s completion" % label
	)
	for node_path in [
		"%RouteHistoryLabel",
		"%ScoreHistoryLabel",
		"%PurchaseHistoryLabel",
		"%FinalDeckLabel",
		"%FinalResourceLabel",
		"%FinalEngravingLabel",
		"%RestartAreaButton",
		"%ReturnEntryButton",
	]:
		_assert_inside(
			screen.get_global_rect(),
			screen.get_node("%AreaCompletePanel").get_node(node_path).get_global_rect(),
			"%s completion %s" % [label, node_path]
		)
	screen.queue_free()
	await process_frame

func _play_first_mirror_card(encounter: SingleEncounterScreen) -> void:
	for index in range(encounter.session.hand.size()):
		var card := encounter.session.hand[index]
		if (
			card.target_type == CardDefinition.TargetType.GAP
			and not card.mirror_effects.is_empty()
		):
			encounter.session.activate_card(index)
			encounter.session.activate_gap(&"left", &"middle")
			encounter.refresh_from_session()
			return
	_assert_true(false, "layout fixture should contain a mirror GAP card")

func _force_failure(screen: MirrorHallRunScreen) -> void:
	await _complete_active_encounter(screen, false)
	_assert_equal(
		screen.area_session.phase,
		AreaRunSession.Phase.FAILED,
		"forced failure should reach failure phase"
	)

func _force_completion(screen: MirrorHallRunScreen) -> void:
	var route: RouteChoicePanel = screen.get_node("%RouteChoicePanel")
	screen._on_route_selected(route.get_node("%LeftRouteButton").get_meta("room_id"))
	await _settle()
	await _complete_active_encounter(screen)
	screen._on_shop_requested()
	await _settle()
	_purchase_first_offer(screen)
	screen._on_shop_leave_requested()
	await _settle()
	screen._on_route_selected(route.get_node("%RightRouteButton").get_meta("room_id"))
	await _settle()
	await _complete_active_encounter(screen)
	screen._on_shop_requested()
	await _settle()
	_purchase_first_offer(screen)
	screen._on_shop_leave_requested()
	await _settle()
	await _complete_active_encounter(screen)
	var engraving_id: StringName = screen.area_session.engraving_offer_ids[0]
	screen._on_engraving_selected(engraving_id)
	screen._on_install_requested(engraving_id, &"d1", 2)
	await _settle()

func _complete_active_encounter(
	screen: MirrorHallRunScreen,
	force_success: bool = true
) -> void:
	screen.area_session.encounter_session.target_total = 0 if force_success else 999999
	for round_index in range(ThreeRoundEncounterSession.ROUND_COUNT):
		var report := screen.area_session.encounter_session.current_session.commit()
		screen._on_round_committed(report)
		await _settle()
		if round_index < ThreeRoundEncounterSession.ROUND_COUNT - 1:
			screen._on_next_round_requested()
			await _settle()

func _purchase_first_offer(screen: MirrorHallRunScreen) -> void:
	var session := screen.area_session.shop_session
	var result := session.purchase(session.offer_ids[0], session.deck_ids[0])
	_assert_true(result.accepted, "layout path shop replacement should succeed")

func _assert_modal(screen: Control, panel: Control, label: String) -> void:
	_assert_true(panel.visible, "%s should be visible" % label)
	_assert_inside(screen.get_global_rect(), panel.get_global_rect(), label)
	_assert_equal(
		panel.mouse_filter,
		Control.MOUSE_FILTER_STOP,
		"%s should block background input" % label
	)

func _assert_inside(parent_rect: Rect2, child_rect: Rect2, label: String) -> void:
	_assert_true(
		parent_rect.encloses(child_rect),
		"%s outside bounds; parent=%s child=%s" % [label, parent_rect, child_rect]
	)

func _size_label(size: Vector2i) -> String:
	return "%dx%d" % [size.x, size.y]

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
