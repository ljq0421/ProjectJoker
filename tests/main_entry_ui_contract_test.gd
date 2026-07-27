extends "res://tests/test_case.gd"

func run() -> void:
	var packed := load("res://scenes/run/single_encounter_screen.tscn")
	assert_true(packed != null, "main entry scene should load")
	if packed == null:
		return
	var screen: SingleEncounterScreen = packed.instantiate()
	assert_true(
		screen.get_node_or_null("%PracticeEntryGroup") != null,
		"practice group is required"
	)
	assert_true(
		screen.get_node_or_null("%AreaTrialEntryGroup") != null,
		"area trial group is required"
	)
	var expected_copy := {
		"ReplayTutorialButton": "重看引导",
		"ReplayAdvancedGuideButton": "重看铁算盘原型引导",
		"RunTrialButton": "进入金线回廊",
		"ReplayGoldCorridorGuideButton": "重看金线回廊提示",
		"MirrorHallRunButton": "进入反照牌厅",
		"ReplayMirrorHallGuideButton": "重看反照牌厅提示",
	}
	for node_name in expected_copy:
		var button := screen.get_node_or_null("%" + node_name) as Button
		assert_true(button != null, "entry should expose %s" % node_name)
		if button != null:
			assert_equal(
				button.text,
				expected_copy[node_name],
				"%s copy should be exact" % node_name
			)
	assert_true(
		screen.get_node("%PracticeEntryGroup").is_ancestor_of(
			screen.get_node("%ReplayTutorialButton")
		),
		"base tutorial replay belongs to practice"
	)
	assert_true(
		screen.get_node("%AreaTrialEntryGroup").is_ancestor_of(
			screen.get_node("%MirrorHallRunButton")
		),
		"mirror entry belongs to area trials"
	)
	screen.free()
