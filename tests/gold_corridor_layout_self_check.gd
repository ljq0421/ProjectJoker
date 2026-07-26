extends SceneTree

const LOGICAL_SIZE := Vector2i(1920, 1080)
const RENDERED_SIZES := [
	Vector2i(1280, 720),
	Vector2i(1920, 1080),
]
const SAMPLE_SEEDS := [20260726, 20260727, 20260728, 20260729]

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.content_scale_size = LOGICAL_SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	for rendered_size in RENDERED_SIZES:
		await _verify_complete_layout(rendered_size)
	_verify_room_playability()
	if failures.is_empty():
		print("PASS gold_corridor_layout_self_check")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _verify_complete_layout(rendered_size: Vector2i) -> void:
	root.size = rendered_size
	var screen: GoldCorridorRunScreen = load(
		"res://scenes/run/gold_corridor_run_screen.tscn"
	).instantiate()
	screen.guide_auto_start = false
	root.add_child(screen)
	await _settle()
	var size_label := "%dx%d" % [rendered_size.x, rendered_size.y]
	_assert_equal(
		Vector2i(screen.size),
		LOGICAL_SIZE,
		"%s should preserve the logical canvas" % size_label
	)

	var route: RouteChoicePanel = screen.get_node("%RouteChoicePanel")
	_assert_overlay(screen, route, "%s first route" % size_label)
	_assert_route_contents(screen, route, "%s first route" % size_label)
	var encounter: SingleEncounterScreen = screen.get_node("%EncounterScreen")
	for node_path in [
		"%DealerPanel",
		"%LeftLane",
		"%MiddleLane",
		"%RightLane",
		"%DiceTray",
		"%Hand",
		"%ResolutionPanel",
	]:
		_assert_inside(
			screen.get_global_rect(),
			encounter.get_node(node_path).get_global_rect(),
			"%s encounter %s" % [size_label, node_path]
		)

	screen._on_route_selected(route.get_node("%LeftRouteButton").get_meta("room_id"))
	await _settle()
	await _complete_active_encounter(screen)
	var summary: RoundSummaryPanel = screen.get_node("%RoundSummaryPanel")
	_assert_overlay(screen, summary, "%s first room summary" % size_label)
	screen._on_shop_requested()
	await _settle()
	_assert_shop(screen, "%s first shop" % size_label)
	_purchase_first_offer(screen)
	screen._on_shop_leave_requested()
	await _settle()

	_assert_overlay(screen, route, "%s second route" % size_label)
	_assert_route_contents(screen, route, "%s second route" % size_label)
	screen._on_route_selected(route.get_node("%RightRouteButton").get_meta("room_id"))
	await _settle()
	await _complete_active_encounter(screen)
	screen._on_shop_requested()
	await _settle()
	_assert_shop(screen, "%s second shop" % size_label)
	_purchase_first_offer(screen)
	screen._on_shop_leave_requested()
	await _settle()

	_assert_true(
		screen.area_session.phase == AreaRunSession.Phase.DEALER,
		"%s should enter Iron Abacus after the second shop" % size_label
	)
	_assert_inside(
		screen.get_global_rect(),
		encounter.get_node("%DealerPanel").get_global_rect(),
		"%s Iron Abacus dealer panel" % size_label
	)
	_assert_true(
		"铁算盘" in encounter.get_node("%DealerName").text,
		"%s should expose the Iron Abacus name" % size_label
	)
	await _complete_active_encounter(screen)

	var reward: EngravingRewardPanel = screen.get_node("%EngravingRewardPanel")
	_assert_overlay(screen, reward, "%s engraving reward" % size_label)
	for node_path in ["%OfferRow", "%DieRow", "%FaceGrid", "%InstallEngravingButton"]:
		_assert_inside(
			screen.get_global_rect(),
			reward.get_node(node_path).get_global_rect(),
			"%s reward %s" % [size_label, node_path]
		)
	_assert_equal(
		reward.get_node("%OfferRow").get_child_count(),
		3,
		"%s reward should show three engravings" % size_label
	)
	_assert_equal(
		reward.get_node("%DieRow").get_child_count(),
		6,
		"%s reward should show six dice" % size_label
	)
	_assert_equal(
		reward.get_node("%FaceGrid").get_child_count(),
		6,
		"%s reward should show six faces" % size_label
	)

	var engraving_id: StringName = screen.area_session.engraving_offer_ids[0]
	screen._on_engraving_selected(engraving_id)
	screen._on_install_requested(engraving_id, &"d1", 2)
	await _settle()
	var complete: AreaCompletePanel = screen.get_node("%AreaCompletePanel")
	_assert_overlay(screen, complete, "%s completion" % size_label)
	for node_path in [
		"%RouteHistoryLabel",
		"%ScoreHistoryLabel",
		"%PurchaseHistoryLabel",
		"%FinalDeckLabel",
		"%FinalResourceLabel",
		"%FinalEngravingLabel",
		"%CompleteErrorLabel",
		"%RestartAreaButton",
		"%ReturnEntryButton",
	]:
		_assert_inside(
			screen.get_global_rect(),
			complete.get_node(node_path).get_global_rect(),
			"%s completion %s" % [size_label, node_path]
		)
	for card_id in screen.area_session.deck_ids:
		var card := screen.area_session.card_catalog.find_card(card_id)
		_assert_true(
			card.display_name in complete.get_node("%FinalDeckLabel").text,
			"%s completion should list %s" % [size_label, card.display_name]
		)
	_assert_equal(
		complete.get_node("%PurchaseHistoryLabel").text.count("→"),
		2,
		"%s completion should list both replacements" % size_label
	)
	_assert_true(
		complete.get_node("%RestartAreaButton").visible
		and complete.get_node("%ReturnEntryButton").visible,
		"%s completion should expose both exit actions" % size_label
	)
	screen.queue_free()
	await process_frame

func _complete_active_encounter(screen: GoldCorridorRunScreen) -> void:
	screen.area_session.encounter_session.target_total = 0
	for round_index in range(ThreeRoundEncounterSession.ROUND_COUNT):
		var report := screen.area_session.encounter_session.current_session.commit()
		screen._on_round_committed(report)
		await _settle()
		if round_index < ThreeRoundEncounterSession.ROUND_COUNT - 1:
			screen._on_next_round_requested()
			await _settle()

func _purchase_first_offer(screen: GoldCorridorRunScreen) -> void:
	var shop: ShopScreen = screen.get_node("%ShopScreen")
	var session := screen.area_session.shop_session
	var result := session.purchase(session.offer_ids[0], session.deck_ids[0])
	_assert_true(result.accepted, "layout path shop replacement should succeed")
	shop.bind_session(session, screen.area_session.card_catalog)

func _assert_route_contents(
	screen: GoldCorridorRunScreen,
	route: RouteChoicePanel,
	label: String
) -> void:
	for prefix in ["Left", "Right"]:
		for suffix in [
			"RouteName",
			"RouteDescription",
			"RouteGoal",
			"RouteReward",
			"RouteTags",
			"RouteSynergy",
			"LaneOne",
			"LaneTwo",
			"LaneThree",
			"RouteButton",
		]:
			var node: Control = route.get_node("%" + prefix + suffix)
			_assert_inside(
				screen.get_global_rect(),
				node.get_global_rect(),
				"%s %s%s" % [label, prefix, suffix]
			)
			if node is Label:
				_assert_true(
					not node.text.strip_edges().is_empty(),
					"%s %s%s should contain public copy" % [label, prefix, suffix]
				)
	_assert_inside(
		screen.get_global_rect(),
		route.get_node("%RouteErrorLabel").get_global_rect(),
		"%s error copy" % label
	)

func _assert_shop(screen: GoldCorridorRunScreen, label: String) -> void:
	var shop: ShopScreen = screen.get_node("%ShopScreen")
	_assert_true(shop.visible, "%s should be visible" % label)
	_assert_inside(screen.get_global_rect(), shop.get_global_rect(), label)
	for node_path in [
		"%DeckGrid",
		"%OfferColumn",
		"%ShopSelectionLabel",
		"%ShopErrorLabel",
		"%ConfirmReplacementButton",
		"%LeaveShopButton",
	]:
		_assert_inside(
			screen.get_global_rect(),
			shop.get_node(node_path).get_global_rect(),
			"%s %s" % [label, node_path]
		)
	_assert_equal(
		shop.get_node("%DeckGrid").get_child_count(),
		12,
		"%s should show twelve owned cards" % label
	)
	_assert_equal(
		shop.get_node("%OfferColumn").get_child_count(),
		3,
		"%s should show three candidates" % label
	)
	for offer_id in screen.area_session.shop_session.offer_ids:
		_assert_true(
			offer_id not in screen.area_session.shop_session.deck_ids,
			"%s candidates should be unowned" % label
		)

func _verify_room_playability() -> void:
	var catalog := GoldCorridorCatalog.new()
	for room in catalog.all_rooms():
		var qualifying_signatures: Dictionary = {}
		var legal_assignment_count := 0
		var calibration_alternatives := 0
		var starter_card_alternatives := 0
		var best_preview_total := -1
		var best_unassigned_dice := 6
		var hidden_bonus_seen := false
		for seed_value in SAMPLE_SEEDS:
			var rng := RunRng.new(seed_value + String(room.id).hash())
			var values: Array[int] = []
			for die_index in range(6):
				values.append(rng.roll_die())
			var sample := _enumerate_assignments(room, values)
			legal_assignment_count += sample["legal_assignment_count"]
			calibration_alternatives += _calibration_alternative_count(values)
			starter_card_alternatives += _starter_card_alternative_count(room, values)
			best_preview_total = maxi(best_preview_total, sample["best_preview_total"])
			best_unassigned_dice = mini(
				best_unassigned_dice,
				sample["best_unassigned_dice"]
			)
			hidden_bonus_seen = hidden_bonus_seen or sample["hidden_bonus_seen"]
			for signature in sample["qualifying_signatures"]:
				qualifying_signatures[signature] = true
		var target_difference := room.target_total - best_preview_total * 3
		print(
			(
				"PLAYABILITY %s legal=%d calibration=%d card_alternatives=%d "
				+ "unassigned=%d best=%d target_difference=%d signatures=%d"
			) % [
				room.id,
				legal_assignment_count,
				calibration_alternatives,
				starter_card_alternatives,
				best_unassigned_dice,
				best_preview_total,
				target_difference,
				qualifying_signatures.size(),
			]
		)
		_assert_true(
			qualifying_signatures.size() >= 2,
			"%s should have at least two no-card solution signatures" % room.id
		)
		_assert_true(
			best_preview_total * 3 >= room.target_total,
			"%s should be playable without a shop-only card" % room.id
		)
		_assert_true(
			calibration_alternatives > 0,
			"%s should expose deterministic calibration alternatives" % room.id
		)
		_assert_true(
			starter_card_alternatives > 0,
			"%s should expose starter-card-created alternatives" % room.id
		)
		_assert_true(
			not hidden_bonus_seen,
			"%s should not use dealer, hidden, or probabilistic bonuses" % room.id
		)

func _enumerate_assignments(room: RoomDefinition, values: Array[int]) -> Dictionary:
	var table_ids: Array[StringName] = [&"", &"left", &"middle", &"right"]
	var limits := {
		&"left": room.encounter.rules[0].slot_count,
		&"middle": room.encounter.rules[1].slot_count,
		&"right": room.encounter.rules[2].slot_count,
	}
	var legal_assignment_count := 0
	var best_preview_total := -1
	var best_unassigned_dice := 6
	var qualifying_signatures: Dictionary = {}
	var hidden_bonus_seen := false
	for encoded in range(4096):
		var cursor := encoded
		var assignments := {&"left": [], &"middle": [], &"right": []}
		var signature_parts: Array[String] = []
		var legal := true
		for die_index in range(6):
			var table_id: StringName = table_ids[cursor % 4]
			cursor /= 4
			signature_parts.append(String(table_id))
			if table_id != &"":
				assignments[table_id].append(StringName("d%d" % (die_index + 1)))
				if assignments[table_id].size() > limits[table_id]:
					legal = false
					break
		if not legal:
			continue
		legal_assignment_count += 1
		var state := RoundState.new()
		for die_index in range(6):
			state.dice.append(DieState.new(
				StringName("d%d" % (die_index + 1)),
				values[die_index]
			))
		state.assignments = assignments
		var report := RoundResolver.new().resolve(
			state,
			room.encounter,
			ResolutionContext.empty()
		)
		if not report.valid:
			continue
		if report.total > best_preview_total:
			best_preview_total = report.total
			best_unassigned_dice = report.unassigned_dice
		if report.total * 3 >= room.target_total:
			qualifying_signatures["/".join(signature_parts)] = true
		hidden_bonus_seen = hidden_bonus_seen or (
			report.dealer_reward != 0 or report.dealer_reward_lost != 0
		)
	return {
		"legal_assignment_count": legal_assignment_count,
		"best_preview_total": best_preview_total,
		"best_unassigned_dice": best_unassigned_dice,
		"qualifying_signatures": qualifying_signatures.keys(),
		"hidden_bonus_seen": hidden_bonus_seen,
	}

func _calibration_alternative_count(values: Array[int]) -> int:
	var count := 0
	for value in values:
		if value > 1:
			count += 1
		if value < 6:
			count += 1
	return count

func _starter_card_alternative_count(
	room: RoomDefinition,
	values: Array[int]
) -> int:
	var state := RoundState.new()
	for die_index in range(6):
		state.dice.append(DieState.new(
			StringName("d%d" % (die_index + 1)),
			values[die_index]
		))
	var context := ResolutionContext.empty()
	var alternatives := 0
	for card in CardCatalog.new().starter_deck():
		var targets: Array[Array] = []
		match card.target_type:
			CardDefinition.TargetType.DIE:
				for die_index in range(6):
					targets.append([StringName("d%d" % (die_index + 1)), &""])
			CardDefinition.TargetType.TABLE:
				for rule in room.encounter.rules:
					targets.append([rule.id, &""])
			CardDefinition.TargetType.GAP:
				targets.append([room.encounter.rules[0].id, room.encounter.rules[1].id])
				targets.append([room.encounter.rules[1].id, room.encounter.rules[2].id])
			CardDefinition.TargetType.GLOBAL:
				targets.append([&"", &""])
		for target in targets:
			if CardRules.play_card(
				state,
				PlayedCard.new(card, target[0], target[1]),
				context
			).accepted:
				alternatives += 1
	return alternatives

func _assert_overlay(
	screen: GoldCorridorRunScreen,
	panel: Control,
	label: String
) -> void:
	var root_bounds := Rect2(Vector2.ZERO, screen.size)
	_assert_true(panel.visible, "%s should be visible" % label)
	_assert_true(
		root_bounds.encloses(panel.get_rect()),
		"%s should remain inside the logical root" % label
	)
	_assert_equal(
		panel.mouse_filter,
		Control.MOUSE_FILTER_STOP,
		"%s should block input behind it" % label
	)
	_assert_true(
		panel.z_index > screen.get_node("%EncounterScreen").z_index,
		"%s should render above the encounter" % label
	)

func _assert_inside(parent_rect: Rect2, child_rect: Rect2, label: String) -> void:
	_assert_true(
		parent_rect.encloses(child_rect),
		"%s outside root; root=%s child=%s" % [label, parent_rect, child_rect]
	)

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
