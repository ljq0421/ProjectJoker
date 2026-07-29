extends "res://tests/test_case.gd"

func run() -> void:
	var shared := load("res://scenes/run/area_run_screen.tscn")
	assert_true(shared != null, "shared area run scene should load")
	for path in [
		"res://scenes/run/gold_corridor_run_screen.tscn",
		"res://scenes/run/mirror_hall_run_screen.tscn",
		"res://scenes/run/faceless_hub_run_screen.tscn",
	]:
		var packed := load(path)
		assert_true(packed != null, "%s should load" % path)
		if packed == null:
			continue
		var screen: AreaRunScreen = packed.instantiate()
		assert_true(screen is AreaRunScreen, "%s should inherit AreaRunScreen" % path)
		assert_true(screen.has_method("configure"), "%s should be configurable" % path)
		assert_true(screen.has_method("_after_encounter_bound"), "%s exposes encounter hook" % path)
		assert_true(screen.has_method("_after_card_selected"), "%s exposes card hook" % path)
		assert_true(screen.has_method("_after_dealer_bound"), "%s exposes dealer hook" % path)
		assert_true(
			screen.has_method("_after_round_report_accepted"),
			"%s exposes post-report hook" % path
		)
		assert_true(
			screen.has_method("_show_restriction_choice_if_needed"),
			"%s exposes restriction-choice hook" % path
		)
		assert_true(
			screen.has_method("_after_restriction_confirmed"),
			"%s exposes restriction-confirmed hook" % path
		)
		for node_name in [
			"EncounterScreen",
			"RouteChoicePanel",
			"ShopScreen",
			"RoundSummaryPanel",
			"EngravingRewardPanel",
			"AreaCompletePanel",
			"SettingsLayer",
			"HomeButton",
			]:
			assert_true(
				screen.get_node_or_null("%" + node_name) != null,
				"%s should own %s" % [path, node_name]
			)
		var shop := screen.get_node("%ShopScreen")
		for node_name in [
			"ShopServiceStatusLabel",
			"RefreshOffersButton",
			"PurchaseIntelButton",
			"RefreshConfirmationDialog",
		]:
			assert_true(
				shop.get_node_or_null("%" + node_name) != null,
				"%s shop should own %s" % [path, node_name]
			)
		screen.free()
