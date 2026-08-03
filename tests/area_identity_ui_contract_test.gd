extends "res://tests/test_case.gd"

func run() -> void:
	var encounter: Control = load(
		"res://scenes/run/single_encounter_screen.tscn"
	).instantiate()
	for node_name in [
		"AreaAtmosphere",
		"AreaIdentityBar",
		"DealerSigil",
		"AreaDirectivePanel",
		"AreaDirectiveTitle",
		"AreaDirectiveStatus",
	]:
		assert_true(
			encounter.get_node_or_null("%%%s" % node_name) != null,
			"encounter should expose %s" % node_name
		)
	assert_true(
		encounter.has_method("bind_area_brief"),
		"ordinary encounters should bind area-specific identity copy"
	)
	for entry in [
		[&"gold_corridor", "金线监理"],
		[&"mirror_hall", "镜面监理"],
		[&"faceless_hub", "无名协议"],
	]:
		encounter.bind_area_brief(entry[0])
		assert_equal(
			encounter.get_node("%DealerName").text,
			entry[1],
			"%s ordinary-room identity should not leak another dealer"
			% entry[0]
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
