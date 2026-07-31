extends "res://tests/test_case.gd"

func run() -> void:
	var encounter: Control = load(
		"res://scenes/run/single_encounter_screen.tscn"
	).instantiate()
	for node_name in ["AreaAtmosphere", "AreaIdentityBar", "DealerSigil"]:
		assert_true(
			encounter.get_node_or_null("%%%s" % node_name) != null,
			"encounter should expose %s" % node_name
		)
	encounter.free()

	var shop: Control = load("res://scenes/shop/shop_screen.tscn").instantiate()
	for node_name in ["AreaAtmosphere", "AreaIdentityBar", "AreaStageLabel"]:
		assert_true(
			shop.get_node_or_null("%%%s" % node_name) != null,
			"shop should expose %s" % node_name
		)
	shop.free()

	var summary: Control = load(
		"res://scenes/components/round_summary_panel.tscn"
	).instantiate()
	for node_name in [
		"FailureResultLabel",
		"FailureLossLabel",
		"FailureSuggestionLabel",
	]:
		assert_true(
			summary.get_node_or_null("%%%s" % node_name) != null,
			"failure summary should expose %s" % node_name
		)
	summary.free()
