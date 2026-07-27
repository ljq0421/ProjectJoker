extends "res://tests/test_case.gd"

func run() -> void:
	var scene: SingleEncounterScreen = load(
		"res://scenes/run/single_encounter_screen.tscn"
	).instantiate()
	assert_true(scene.has_signal("card_selected"), "screen should expose card selection")
	for node_name in [
		"DirectionBadge",
		"LeftGap",
		"RightGap",
		"LeftMirrorLayer",
		"RightMirrorLayer",
	]:
		assert_true(
			scene.get_node_or_null("%" + node_name) != null,
			"mirror encounter UI requires %s" % node_name
		)
	var left_layer := scene.get_node("%LeftMirrorLayer") as Control
	var right_layer := scene.get_node("%RightMirrorLayer") as Control
	assert_equal(left_layer.mouse_filter, Control.MOUSE_FILTER_IGNORE, "left mirror ignores input")
	assert_equal(right_layer.mouse_filter, Control.MOUSE_FILTER_IGNORE, "right mirror ignores input")
	assert_false(left_layer.visible, "left mirror begins hidden")
	assert_false(right_layer.visible, "right mirror begins hidden")
	scene.free()

	var panel: ResolutionPanel = load(
		"res://scenes/components/resolution_panel.tscn"
	).instantiate()
	Engine.get_main_loop().root.add_child(panel)
	var report := ResolutionReport.new()
	report.events = [
		ResolutionEvent.new(
			&"mirror_folded_map",
			"镜像副本：折光映射｜right → middle｜系数 +1",
			0,
			0,
			true,
			true,
			&"mirror_folded_map",
			&"left_gap",
			&"right_gap"
		),
	]
	panel.bind_report(report)
	var row := panel.get_node("%EventList").get_child(0) as Label
	assert_true(row.text.contains("镜像副本"), "mirror event must use a text label")
	assert_true(row.text.contains("right → middle"), "mirror event must show endpoints")
	assert_true(row.text.contains("系数 +1"), "mirror event must show weakened effect")
	assert_true(row.get_meta("is_mirror_copy"), "mirror row keeps source metadata")
	panel.free()
