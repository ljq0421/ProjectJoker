extends "res://tests/test_case.gd"

const CatalogScript = preload("res://scripts/cards/card_catalog.gd")

func run() -> void:
	var catalog = CatalogScript.new()
	assert_equal(catalog.validate(), [], "stage 4 card content should validate")
	assert_equal(catalog.starter_deck().size(), 12, "starter deck should contain twelve cards")
	assert_equal(catalog.shop_pool().size(), 3, "shop pool should contain three cards")

	var all_ids: Dictionary = {}
	for card in catalog.all_cards():
		assert_false(all_ids.has(card.id), "card IDs should be unique")
		all_ids[card.id] = true
		assert_false(card.rule_text.strip_edges().is_empty(), "rule text should be present")
		assert_true(card.tags.size() >= 1, "every card should expose at least one display tag")
	assert_equal(all_ids.size(), 15, "catalog should expose fifteen cards")

	for card_id in catalog.starter_ids():
		assert_false(card_id in catalog.shop_ids(), "starter and shop IDs should not overlap")

	var stable := catalog.find_card(&"starter_stable_repeat")
	assert_true(stable != null, "combined starter card should load")
	if stable != null:
		assert_equal(stable.effects.size(), 2, "stable repeat should contain two effects")
		assert_equal(
			stable.effects[0].operation,
			EffectSpec.Operation.MODIFY_COEFFICIENT,
			"stable repeat should modify the coefficient first"
		)
		assert_equal(stable.effects[0].amount, -1, "stable repeat should lower coefficient by one")
		assert_equal(
			stable.effects[1].operation,
			EffectSpec.Operation.REPEAT_TABLE,
			"stable repeat should repeat the table second"
		)

	var missing = catalog.find_card(&"missing_card")
	assert_true(missing == null, "unknown card IDs should return null")
