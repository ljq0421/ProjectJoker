extends "res://tests/test_case.gd"

func run() -> void:
	var catalog_script := load(
		"res://scripts/ui/area_presentation_catalog.gd"
	)
	assert_true(catalog_script != null, "area presentation catalog should exist")
	if catalog_script == null:
		return
	var catalog = catalog_script.new()
	var signatures: Dictionary = {}
	for area_id in [&"gold_corridor", &"mirror_hall", &"faceless_hub"]:
		var presentation: Dictionary = catalog.find(area_id)
		assert_true(not presentation.is_empty(), "%s should have presentation data" % area_id)
		for key in ["primary", "secondary", "background", "pattern", "sigil", "eyebrow"]:
			assert_true(presentation.has(key), "%s should define %s" % [area_id, key])
		signatures[presentation.get("pattern")] = true
		signatures[presentation.get("sigil")] = true
	assert_equal(
		signatures.size(),
		6,
		"all three patterns and dealer sigils should be distinct"
	)
	assert_equal(catalog.find(&"unknown"), {}, "unknown areas should fail closed")
