extends "res://tests/test_case.gd"

const Catalog = preload("res://scripts/engine_slice/engine_slice_catalog.gd")

func run() -> void:
	var catalog = Catalog.new()
	assert_equal(catalog.validate(), [], "engine content catalog should validate")
	assert_equal(catalog.technique_ids().size(), 12, "slice should ship twelve persistent techniques")
	assert_equal(catalog.tactic_ids().size(), 10, "slice should ship ten temporary tactics")
	assert_equal(catalog.enemy_ids().size(), 5, "slice should ship four route enemies and Iron Abacus")
	for build_id in [Catalog.DICE_CONTROL, Catalog.TABLE_CHAIN]:
		var build := catalog.build_definition(build_id)
		assert_equal(build.get("techniques", []).size(), 4, "each starter should expose four persistent techniques")
		assert_equal(build.get("tactics", []).size(), 6, "each starter should expose six temporary tactics")
	var dealer = catalog.enemy(&"dealer_iron_abacus_engine")
	assert_equal(dealer.max_health, 100, "Iron Abacus should use the configured 100 health")
	assert_equal(dealer.phase_two_intent_ids.size(), 5, "Iron Abacus phase two should expose five public intents")
	assert_true(not dealer.portrait_path.is_empty(), "Iron Abacus should own a formal portrait")

