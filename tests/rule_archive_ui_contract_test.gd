extends "res://tests/test_case.gd"

func run() -> void:
	var packed := load("res://scenes/run/rule_archive_screen.tscn")
	assert_true(packed != null, "rule handbook scene should load")
	if packed == null:
		return
	var screen: RuleArchiveScreen = packed.instantiate()
	assert_true(
		screen.has_method("start_practice"),
		"rule handbook should start a selected exercise"
	)
	assert_true(
		screen.has_method("retry_current"),
		"rule handbook practice should expose unlimited retry"
	)
	assert_true(
		screen.has_method("show_handbook"),
		"rule exercise should return to the shared handbook"
	)
	for node_name in [
		"HandbookPanel",
		"EncounterScreen",
		"NavigationBar",
		"HomeButton",
		"BackToHandbookButton",
		"CompletionPanel",
		"RetryPracticeButton",
		"CompletionHandbookButton",
		"CompletionHomeButton",
	]:
		assert_true(
			screen.get_node_or_null("%" + node_name) != null,
			"rule handbook should expose %s" % node_name
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
			screen.get_node("HandbookPanel").get_node_or_null("%" + node_name) != null,
			"the shared handbook should expose all six rule categories"
		)
	screen.free()
