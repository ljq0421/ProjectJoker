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
		for key in [
			"primary",
			"secondary",
			"background",
			"surface",
			"surface_raised",
			"pattern",
			"sigil",
			"eyebrow",
			"route_code",
			"route_instruction",
			"ordinary_eyebrow",
			"ordinary_title",
			"ordinary_rule",
			"directive_title",
		]:
			assert_true(presentation.has(key), "%s should define %s" % [area_id, key])
		signatures[presentation.get("pattern")] = true
		signatures[presentation.get("sigil")] = true
	assert_equal(
		signatures.size(),
		6,
		"all three patterns and dealer sigils should be distinct"
	)
	assert_equal(catalog.find(&"unknown"), {}, "unknown areas should fail closed")
	assert_equal(
		catalog.find(&"gold_corridor").route_code,
		"区域 01",
		"gold route code should identify the first area"
	)
	assert_true(
		"单轮" in catalog.find(&"gold_corridor").route_instruction,
		"gold route copy should disclose its single-round contract"
	)
	assert_equal(
		catalog.find(&"mirror_hall").ordinary_title,
		"镜面监理",
		"mirror ordinary rooms should have a non-dealer identity"
	)
	assert_equal(
		catalog.find(&"faceless_hub").ordinary_title,
		"无名协议",
		"faceless ordinary rooms should have a non-dealer identity"
	)
	var gold_palette: Dictionary = catalog.find(&"gold_corridor")
	assert_equal(gold_palette.primary, Color("#ffd34e"), "gold should use contract yellow")
	assert_equal(gold_palette.secondary, Color("#fff1ad"), "gold should use ivory copy accents")
	assert_equal(gold_palette.background, Color("#151002"), "gold should use a warm near-black")
	var faceless_palette: Dictionary = catalog.find(&"faceless_hub")
	assert_equal(faceless_palette.primary, Color("#52e68c"), "faceless should use terminal green")
	assert_equal(faceless_palette.secondary, Color("#b7f7c9"), "faceless should use pale protocol green")
	assert_equal(faceless_palette.background, Color("#04110b"), "faceless should use ink green-black")
