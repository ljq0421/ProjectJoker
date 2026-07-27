extends "res://tests/test_case.gd"

func run() -> void:
	var packed := load("res://scenes/run/faceless_hub_run_screen.tscn")
	assert_true(packed != null, "faceless hub run scene should load")
	if packed == null:
		return
	var screen: FacelessHubRunScreen = packed.instantiate()
	assert_true(
		screen is FacelessHubRunScreen,
		"faceless hub scene should use its area screen subclass"
	)
	for node_name in ["RoundScheduleStrip", "FinalRestrictionPanel"]:
		assert_true(
			screen.get_node_or_null("%" + node_name) != null,
			"faceless hub scene should own %s" % node_name
		)
	var strip: RoundScheduleStrip = screen.get_node("%RoundScheduleStrip")
	for node_name in ["RoundOneCard", "RoundTwoCard", "RoundThreeCard"]:
		assert_true(
			strip.get_node_or_null("%" + node_name) != null,
			"schedule strip should own %s" % node_name
		)
	var panel: FinalRestrictionPanel = screen.get_node("%FinalRestrictionPanel")
	for node_name in [
		"OperationRestrictionButton",
		"DistributionRestrictionButton",
		"RestrictionConfirmButton",
	]:
		assert_true(
			panel.get_node_or_null("%" + node_name) != null,
			"restriction panel should own %s" % node_name
		)
	var encounter: SingleEncounterScreen = screen.get_node_or_null(
		"%EncounterScreen"
	)
	assert_true(encounter != null, "faceless hub should own encounter screen")
	if encounter != null:
		for node_name in [
			"ActiveRestrictionBadge",
			"RunStatusSlot",
			"SelectionHintLabel",
		]:
			assert_true(
				encounter.get_node_or_null("%" + node_name) != null,
				"encounter scene should own %s" % node_name
			)
	screen.free()

	var schedule_scene_text := FileAccess.get_file_as_string(
		"res://scenes/components/round_schedule_strip.tscn"
	)
	var restriction_scene_text := FileAccess.get_file_as_string(
		"res://scenes/components/final_restriction_panel.tscn"
	)
	assert_true(
		schedule_scene_text.contains("RoundOneCard")
		and schedule_scene_text.contains("RoundThreeCard"),
		"schedule cards should be scene-authored"
	)
	assert_true(
		restriction_scene_text.contains("OperationRestrictionButton")
		and restriction_scene_text.contains("RestrictionConfirmButton"),
		"restriction candidates should be scene-authored"
	)
