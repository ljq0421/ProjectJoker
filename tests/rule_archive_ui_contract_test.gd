extends "res://tests/test_case.gd"

func run() -> void:
	var packed := load("res://scenes/run/rule_archive_screen.tscn")
	assert_true(packed != null, "rule archive scene should load")
	if packed == null:
		return
	var screen: RuleArchiveScreen = packed.instantiate()
	assert_true(
		screen.has_method("open_archive"),
		"rule archive screen should open a selected exercise"
	)
	assert_true(
		screen.has_method("retry_current"),
		"rule archive screen should expose unlimited retry"
	)
	assert_true(
		screen.has_method("show_archive"),
		"rule archive screen should return to its selection page"
	)
	for node_name in [
		"SelectionPanel",
		"EncounterScreen",
		"NavigationBar",
		"HomeButton",
		"BackToArchiveButton",
		"CompletionPanel",
		"RetryArchiveButton",
		"CompletionArchiveButton",
		"CompletionHomeButton",
	]:
		assert_true(
			screen.get_node_or_null("%" + node_name) != null,
			"rule archive should expose %s" % node_name
		)
	for node_name in [
		"Archive01Button",
		"Archive02Button",
		"Archive03Button",
		"Archive04Button",
		"Archive05Button",
		"Archive06Button",
	]:
		assert_true(
			screen.get_node_or_null("%" + node_name) != null,
			"all six archive exercises should be visible"
		)
	screen.free()
