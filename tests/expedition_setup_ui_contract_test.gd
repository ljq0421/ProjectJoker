extends "res://tests/test_case.gd"

func run() -> void:
	var packed := load("res://scenes/run/expedition_setup_screen.tscn")
	assert_true(packed != null, "expedition setup scene should load")
	if packed == null:
		return
	var screen: Control = packed.instantiate()
	for node_name in [
		"DeckChoiceRow",
		"ChallengeGrid",
		"ChallengeCountLabel",
		"ChallengeLockLabel",
		"ExpeditionSeedInput",
		"StartConfiguredExpeditionButton",
		"ReturnFromSetupButton",
		"RunHistoryList",
		"SetupErrorLabel",
		"SetupSubtitle",
		"DeckRecommendationLabel",
		"SelectionSummaryLabel",
		"FirstRunJourneyPanel",
		"HistoryPanel",
	]:
		assert_true(
			screen.get_node_or_null("%" + node_name) != null,
			"expedition setup should expose %s" % node_name
		)
	screen.free()
