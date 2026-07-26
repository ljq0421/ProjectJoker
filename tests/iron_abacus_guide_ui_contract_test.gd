extends "res://tests/test_case.gd"

func run() -> void:
	var packed = load("res://scenes/components/iron_abacus_guide_overlay.tscn")
	assert_true(packed != null, "contextual guide overlay scene should load")
	if packed == null:
		return
	var overlay = packed.instantiate()
	assert_true(overlay.has_signal("acknowledged"), "overlay should emit acknowledgement")
	assert_true(
		overlay.has_signal("dismiss_all_requested"),
		"overlay should emit permanent-dismiss request"
	)
	for method_name in [
		"open_card",
		"close_card",
		"is_open",
		"acknowledge_current",
		"dismiss_all",
		"show_persistence_warning",
	]:
		assert_true(overlay.has_method(method_name), "overlay should expose %s" % method_name)
	for node_name in [
		"GuideDimmer",
		"GuideFocusFrames",
		"GuideCard",
		"GuideProgress",
		"GuideTitle",
		"GuideInstruction",
		"GuideWarning",
		"GuideDismissButton",
		"GuideAcknowledgeButton",
	]:
		assert_true(
			overlay.get_node_or_null("%" + node_name) != null,
			"overlay should expose %s" % node_name
		)

	var tree := Engine.get_main_loop() as SceneTree
	var target := Control.new()
	target.position = Vector2(760, 120)
	target.size = Vector2(300, 220)
	tree.root.add_child(target)
	overlay.position = Vector2.ZERO
	overlay.size = Vector2(1280, 720)
	tree.root.add_child(overlay)

	var spec := {
		"id": &"dealer",
		"progress_index": 3,
		"progress_total": 5,
		"title": "分配完整度影响固定奖励",
		"instruction": "固定奖励会随未分配骰子减少。",
	}
	assert_true(overlay.open_card(spec, [target]), "valid card should open")
	assert_true(overlay.is_open(), "open_card should expose active state")
	assert_equal(
		overlay.mouse_filter,
		Control.MOUSE_FILTER_STOP,
		"open overlay should block background input"
	)
	assert_true(
		overlay.get_node("%GuideFocusFrames").get_child_count() > 0,
		"open card should build focus frames"
	)
	var card: Control = overlay.get_node("%GuideCard")
	assert_true(
		Rect2(Vector2.ZERO, overlay.size).encloses(card.get_rect()),
		"guide card should remain inside overlay bounds"
	)

	overlay.close_card()
	assert_false(overlay.is_open(), "close_card should clear active state")
	assert_equal(
		overlay.mouse_filter,
		Control.MOUSE_FILTER_IGNORE,
		"closed overlay should release background input"
	)
	assert_equal(
		overlay.get_node("%GuideFocusFrames").get_child_count(),
		0,
		"close_card should remove focus frames"
	)
	assert_false(overlay.open_card({}, [target]), "invalid spec should fail open")
	assert_false(overlay.is_open(), "invalid spec should not leave a blocker")
	assert_false(overlay.open_card(spec, []), "missing targets should fail open")
	assert_false(overlay.is_open(), "missing targets should not leave a blocker")

	overlay.free()
	target.free()
