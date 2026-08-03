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

func _assert_true(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
