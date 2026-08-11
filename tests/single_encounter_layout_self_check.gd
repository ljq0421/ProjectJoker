extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var screen = load("res://scenes/run/single_encounter_screen.tscn").instantiate()
	screen.tutorial_auto_start = false
	root.add_child(screen)
	await process_frame
	await process_frame

	var dealer: Control = screen.get_node("SafeArea/RootColumn/Body/DealerPanel")
	var left: Control = screen.get_node("%LeftLane")
	var middle: Control = screen.get_node("%MiddleLane")
	var right: Control = screen.get_node("%RightLane")
	var left_gap: Control = screen.get_node("%LeftGap")
	var right_gap: Control = screen.get_node("%RightGap")
	var tray: Control = screen.get_node("%DiceTray")
	var tray_empty_label: Label = screen.get_node_or_null("%DiceTrayEmptyLabel")
	var resolution: Control = screen.get_node("%ResolutionPanel")
	var hand: Control = screen.get_node("%Hand")
	var card_detail: Control = screen.get_node_or_null("%CardDetailPanel")
	var card_detail_text: Label = screen.get_node_or_null("%CardDetailText")
	var replay_tutorial: Control = screen.get_node("%ReplayTutorialButton")
	var replay_advanced: Control = screen.get_node("%ReplayAdvancedGuideButton")
	var replay_gold_corridor: Control = screen.get_node("%ReplayGoldCorridorGuideButton")
	var run_trial: Control = screen.get_node("%RunTrialButton")

	_assert_inside(screen.get_rect(), dealer.get_global_rect(), "dealer")
	_assert_inside(screen.get_rect(), left.get_global_rect(), "left lane")
	_assert_inside(screen.get_rect(), middle.get_global_rect(), "middle lane")
	_assert_inside(screen.get_rect(), right.get_global_rect(), "right lane")
	_assert_inside(screen.get_rect(), left_gap.get_global_rect(), "left gap")
	_assert_inside(screen.get_rect(), right_gap.get_global_rect(), "right gap")
	_assert_inside(screen.get_rect(), tray.get_global_rect(), "dice tray")
	_assert_inside(screen.get_rect(), resolution.get_global_rect(), "resolution")
	_assert_inside(screen.get_rect(), hand.get_global_rect(), "hand")
	_assert_inside(screen.get_rect(), replay_tutorial.get_global_rect(), "base replay button")
	_assert_inside(screen.get_rect(), replay_advanced.get_global_rect(), "Iron Abacus replay button")
	_assert_inside(screen.get_rect(), replay_gold_corridor.get_global_rect(), "region guide replay button")
	_assert_inside(screen.get_rect(), run_trial.get_global_rect(), "three round trial button")
	_assert_true(
		absf(left.size.x - middle.size.x) <= 2.0
		and absf(middle.size.x - right.size.x) <= 2.0,
		"three lanes should have equal widths"
	)
	_assert_true(
		dealer.get_global_rect().end.x < left.get_global_rect().position.x,
		"dealer must not overlap lanes"
	)
	_assert_true(
		right.get_global_rect().end.x < resolution.get_global_rect().position.x,
		"lanes must not overlap resolution"
	)
	_assert_true(
		card_detail != null and card_detail.visible,
		"card detail space should remain reserved before a card is selected"
	)
	_assert_true(
		card_detail_text != null and "选择一张手法牌" in card_detail_text.text,
		"reserved card detail space should explain how to use it"
	)
	_assert_true(
		tray_empty_label != null and not tray_empty_label.visible,
		"dice tray empty state should stay hidden while dice remain unassigned"
	)

	var left_rect_before_selection := left.get_global_rect()
	var detail_rect_before_selection := card_detail.get_global_rect()
	_assert_true(screen.session.activate_card(0), "layout check should select a hand card")
	screen.refresh_from_session()
	await process_frame
	await process_frame
	_assert_rect_approx(
		left.get_global_rect(),
		left_rect_before_selection,
		"selecting a card must not resize or move the rule lanes"
	)
	_assert_rect_approx(
		card_detail.get_global_rect(),
		detail_rect_before_selection,
		"selected-card details must use the already reserved space"
	)
	_assert_true(
		screen.session.hand[0].rule_text in card_detail_text.text,
		"selected-card detail space should show the complete rule"
	)

	screen.session.cancel_selection()
	var assignments := [
		[&"d1", &"left"],
		[&"d6", &"left"],
		[&"d2", &"middle"],
		[&"d3", &"middle"],
		[&"d4", &"middle"],
		[&"d5", &"right"],
	]
	for assignment in assignments:
		_assert_true(
			screen.session.activate_die(assignment[0])
			and screen.session.activate_table(assignment[1]),
			"layout check should assign every die"
		)
	screen.refresh_from_session()
	await process_frame
	await process_frame
	_assert_true(
		tray_empty_label != null
		and tray_empty_label.visible
		and "全部已入台" in tray_empty_label.text,
		"empty dice tray should identify its purpose and completed state"
	)

	var catalog := CardCatalog.new()
	var layout_hand: Array[CardDefinition] = [
		catalog.find_card(&"starter_nudge_up_1"),
		catalog.find_card(&"starter_nudge_down_1"),
		catalog.find_card(&"faceless_swap_values"),
	]
	var layout_session := SingleEncounterSession.new(
		SingleEncounterFixture.make_state(),
		SingleEncounterFixture.make_encounter(),
		layout_hand
	)
	screen.bind_external_session(layout_session, "布局自检", "正式远征卡牌说明")
	screen.get_node("SafeArea").offset_top = 96.0
	screen.set_formal_emergency_context(true, 3)
	await process_frame
	await process_frame
	var safe_area: Control = screen.get_node("SafeArea")
	var root_column: Control = screen.get_node("SafeArea/RootColumn")
	var top_bar: Control = screen.get_node("SafeArea/RootColumn/TopBar")
	var directive_slot: Control = screen.get_node(
		"SafeArea/RootColumn/AreaDirectiveSlot"
	)
	var body: Control = screen.get_node("SafeArea/RootColumn/Body")
	var center: Control = screen.get_node("SafeArea/RootColumn/Body/Center")
	var lanes: Control = screen.get_node(
		"SafeArea/RootColumn/Body/Center/Lanes"
	)
	var dice_row: Control = screen.get_node(
		"SafeArea/RootColumn/Body/Center/DiceRow"
	)
	var hint: Control = screen.get_node("%SelectionHintLabel")
	var action_bar: Control = screen.get_node(
		"SafeArea/RootColumn/Body/Center/ActionBar"
	)
	var emergency_bar: Control = screen.get_node(
		"SafeArea/RootColumn/Body/Center/EmergencyBar"
	)
	var error_label: Control = screen.get_node("SafeArea/RootColumn/ErrorLabel")
	_assert_rect_approx(
		safe_area.get_rect(),
		Rect2(32, 96, 1856, 960),
		"formal SafeArea must use the fixed 1856x960 ledger"
	)
	_assert_size_approx(root_column, Vector2(1856, 960), "formal RootColumn")
	_assert_rect_approx(
		top_bar.get_rect(), Rect2(0, 0, 1856, 32), "fixed top status row"
	)
	_assert_rect_approx(
		directive_slot.get_rect(),
		Rect2(0, 40, 1856, 40),
		"fixed area directive row"
	)
	_assert_rect_approx(
		body.get_rect(), Rect2(0, 88, 1856, 836), "fixed encounter body"
	)
	_assert_rect_approx(
		error_label.get_rect(), Rect2(0, 932, 1856, 28), "fixed error row"
	)
	_assert_rect_approx(dealer.get_rect(), Rect2(0, 0, 230, 836), "dealer column")
	_assert_rect_approx(center.get_rect(), Rect2(248, 0, 1290, 836), "center column")
	_assert_rect_approx(
		resolution.get_rect(), Rect2(1556, 0, 300, 836), "prediction column"
	)
	_assert_rect_approx(lanes.get_rect(), Rect2(0, 0, 1290, 302), "rule lanes row")
	_assert_rect_approx(dice_row.get_rect(), Rect2(0, 310, 1290, 102), "dice row")
	_assert_rect_approx(hint.get_rect(), Rect2(0, 420, 1290, 24), "hint row")
	_assert_rect_approx(hand.get_rect(), Rect2(0, 452, 1290, 126), "hand row")
	_assert_rect_approx(
		card_detail.get_rect(), Rect2(0, 586, 1290, 150), "card detail row"
	)
	_assert_rect_approx(
		action_bar.get_rect(), Rect2(0, 744, 1290, 42), "action row"
	)
	_assert_rect_approx(
		emergency_bar.get_rect(), Rect2(0, 794, 1290, 42), "emergency row"
	)
	for fixed_rect in [
		[screen.get_node("%AreaLabel"), Rect2(0, 0, 570, 32), "area status slot"],
		[screen.get_node("%DirectionBadge"), Rect2(578, 0, 210, 32), "direction slot"],
		[screen.get_node("SafeArea/RootColumn/TopBar/RestrictionSlot"), Rect2(796, 0, 260, 32), "restriction slot"],
		[screen.get_node("%GoalLabel"), Rect2(1064, 0, 560, 32), "goal slot"],
		[screen.get_node("SafeArea/RootColumn/TopBar/UtilityDockSpacer"), Rect2(1632, 0, 224, 32), "utility slot"],
		[left, Rect2(0, 0, 371, 302), "left rule lane"],
		[screen.get_node("SafeArea/RootColumn/Body/Center/Lanes/LeftGapColumn"), Rect2(379, 0, 72, 302), "left gap column"],
		[middle, Rect2(459, 0, 372, 302), "middle rule lane"],
		[screen.get_node("SafeArea/RootColumn/Body/Center/Lanes/RightGapColumn"), Rect2(839, 0, 72, 302), "right gap column"],
		[right, Rect2(919, 0, 371, 302), "right rule lane"],
		[screen.get_node("%CalibrationLabel"), Rect2(0, 0, 838, 42), "calibration copy"],
		[screen.get_node("%MinusButton"), Rect2(846, 0, 100, 42), "minus action"],
		[screen.get_node("%PlusButton"), Rect2(954, 0, 100, 42), "plus action"],
		[screen.get_node("%UndoButton"), Rect2(1062, 0, 88, 42), "undo action"],
		[screen.get_node("%ConfirmButton"), Rect2(1158, 0, 132, 42), "confirm action"],
		[screen.get_node("%EmergencyTicketLabel"), Rect2(0, 0, 796, 42), "emergency copy"],
		[screen.get_node("%PaidRerollButton"), Rect2(804, 0, 150, 42), "reroll action"],
		[screen.get_node("%PaidCalibrationButton"), Rect2(962, 0, 150, 42), "paid calibration action"],
		[screen.get_node("%PaidRetryButton"), Rect2(1120, 0, 170, 42), "retry action"],
	]:
		_assert_rect_approx(fixed_rect[0].get_rect(), fixed_rect[1], fixed_rect[2])
	for lane in [left, middle, right]:
		for slot in lane.get_node("%Slots").get_children():
			if slot is Control:
				_assert_size_approx(slot, Vector2(60, 60), "fixed rule slot")
	for die in tray.get_children():
		if die is Control:
			_assert_size_approx(die, Vector2(60, 60), "fixed die token")
	for card in hand.get_children():
		if card is Control:
			_assert_size_approx(card, Vector2(190, 126), "fixed technique card")
	var restriction_badge: Control = screen.get_node("%ActiveRestrictionBadge")
	var direction_rect_before_restriction: Rect2 = screen.get_node(
		"%DirectionBadge"
	).get_rect()
	var goal_rect_before_restriction: Rect2 = screen.get_node(
		"%GoalLabel"
	).get_rect()
	restriction_badge.visible = not restriction_badge.visible
	await process_frame
	await process_frame
	_assert_rect_approx(
		screen.get_node("%DirectionBadge").get_rect(),
		direction_rect_before_restriction,
		"restriction visibility must not move the direction slot"
	)
	_assert_rect_approx(
		screen.get_node("%GoalLabel").get_rect(),
		goal_rect_before_restriction,
		"restriction visibility must not move the goal slot"
	)
	restriction_badge.visible = not restriction_badge.visible
	var formal_lane_rects: Array[Rect2] = [
		left.get_global_rect(),
		middle.get_global_rect(),
		right.get_global_rect(),
	]
	var formal_detail_rect := card_detail.get_global_rect()
	for card_index in layout_hand.size():
		_assert_true(
			layout_session.activate_card(card_index),
			"layout check should select %s" % layout_hand[card_index].id
		)
		screen.refresh_from_session()
		await process_frame
		await process_frame
		for lane_index in [0, 1, 2]:
			_assert_rect_approx(
				[left, middle, right][lane_index].get_global_rect(),
				formal_lane_rects[lane_index],
				"selecting %s must not resize rule lane %d"
				% [layout_hand[card_index].id, lane_index]
			)
		_assert_rect_approx(
			card_detail.get_global_rect(),
			formal_detail_rect,
			"selecting %s must keep the reserved detail panel size"
			% layout_hand[card_index].id
		)
		_assert_true(
			layout_hand[card_index].rule_text in card_detail_text.text,
			"selected detail should retain the complete %s rule"
			% layout_hand[card_index].id
		)
		layout_session.cancel_selection()
		screen.refresh_from_session()
		await process_frame
		await process_frame

	var stable_center_rects := {
		"lanes": lanes.get_rect(),
		"dice": dice_row.get_rect(),
		"hand": hand.get_rect(),
		"detail": card_detail.get_rect(),
		"action": action_bar.get_rect(),
	}
	emergency_bar.visible = false
	await process_frame
	await process_frame
	_assert_rect_approx(lanes.get_rect(), stable_center_rects["lanes"], "hiding emergency controls must not move lanes")
	_assert_rect_approx(dice_row.get_rect(), stable_center_rects["dice"], "hiding emergency controls must not move dice")
	_assert_rect_approx(hand.get_rect(), stable_center_rects["hand"], "hiding emergency controls must not move hand")
	_assert_rect_approx(card_detail.get_rect(), stable_center_rects["detail"], "hiding emergency controls must not move detail")
	_assert_rect_approx(action_bar.get_rect(), stable_center_rects["action"], "hiding emergency controls must not move actions")
	emergency_bar.visible = true

	var dealer_rect_before_long_copy := dealer.get_rect()
	var dealer_rule: Label = screen.get_node("%DealerRule")
	dealer_rule.text = "庄家长说明\n" + "完整规则说明。\n".repeat(60)
	for lane in [left, middle, right]:
		var condition: Label = lane.get_node("%Condition")
		condition.text = "完整条件\n" + "条件不会撑开规则台。\n".repeat(20)
	card_detail_text.text = "手法牌完整说明\n" + "说明内容保持完整并在框内滚动。\n".repeat(30)
	var long_report := ResolutionReport.new()
	for event_index in range(30):
		long_report.events.append(
			ResolutionEvent.new(
				&"left",
				"预测事件 %02d 的完整说明" % (event_index + 1),
				event_index + 1,
				event_index + 1
			)
		)
	long_report.total = 30
	screen.resolution_panel.bind_report(long_report)
	await process_frame
	await process_frame
	_assert_rect_approx(dealer.get_rect(), dealer_rect_before_long_copy, "long dealer copy must stay inside its fixed frame")
	_assert_rect_approx(resolution.get_rect(), Rect2(1556, 0, 300, 836), "long prediction events must keep the prediction frame")
	_assert_true(
		screen.get_node("SafeArea/RootColumn/Body/DealerPanel/DealerScroll").get_v_scroll_bar().max_value
		> screen.get_node("SafeArea/RootColumn/Body/DealerPanel/DealerScroll").size.y,
		"long dealer copy should scroll vertically"
	)
	for lane in [left, middle, right]:
		var condition_scroll: ScrollContainer = lane.get_node("Content/ConditionScroll")
		_assert_true(
			condition_scroll.get_v_scroll_bar().max_value > condition_scroll.size.y,
			"long lane conditions should scroll vertically"
		)
	var detail_scroll: ScrollContainer = screen.get_node(
		"SafeArea/RootColumn/Body/Center/CardDetailPanel/CardDetailRow/CardDetailTextScroll"
	)
	_assert_true(
		detail_scroll.get_v_scroll_bar().max_value > detail_scroll.size.y,
		"long card details should scroll vertically"
	)
	var event_scroll: ScrollContainer = screen.resolution_panel.get_node("%EventScroll")
	_assert_true(
		event_scroll.get_v_scroll_bar().max_value > event_scroll.size.y,
		"long prediction events should scroll vertically"
	)

	screen.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS single_encounter_layout_self_check")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _assert_inside(parent_rect: Rect2, child_rect: Rect2, label: String) -> void:
	_assert_true(
		parent_rect.encloses(child_rect),
		"%s must remain inside 1920x1080 root" % label
	)

func _assert_rect_approx(actual: Rect2, expected: Rect2, message: String) -> void:
	_assert_true(
		actual.position.is_equal_approx(expected.position)
		and actual.size.is_equal_approx(expected.size),
		"%s (before=%s, after=%s)" % [message, expected, actual]
	)

func _assert_size_approx(control: Control, expected: Vector2, message: String) -> void:
	_assert_true(
		control.size.is_equal_approx(expected),
		"%s (actual=%s, expected=%s)" % [message, control.size, expected]
	)

func _assert_true(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
