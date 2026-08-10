extends "res://tests/test_case.gd"

const CatalogScript = preload("res://scripts/cards/card_catalog.gd")

func run() -> void:
	var catalog = CatalogScript.new()
	assert_equal(catalog.validate(), [], "stage 4 card content should validate")
	assert_equal(catalog.starter_deck().size(), 12, "starter deck should contain twelve cards")
	assert_equal(catalog.shop_pool().size(), 8, "shop pool should contain eight cards")

	var all_ids: Dictionary = {}
	for card in catalog.all_cards():
		assert_false(all_ids.has(card.id), "card IDs should be unique")
		all_ids[card.id] = true
		assert_false(card.rule_text.strip_edges().is_empty(), "rule text should be present")
		assert_true(card.tags.size() >= 1, "every card should expose at least one display tag")
	assert_equal(all_ids.size(), 42, "catalog should expose forty-two cards")
	assert_equal(catalog.mirror_hall_card_ids().size(), 6, "mirror card group should stay separate")

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

	var deep_drop := catalog.find_card(&"shop_deep_drop")
	assert_true(deep_drop != null, "deep drop shop card should load")
	if deep_drop != null:
		assert_equal(deep_drop.target_type, CardDefinition.TargetType.DIE, "deep drop targets a die")
		assert_equal(deep_drop.effects.size(), 1, "deep drop should contain one effect")
		assert_equal(
			deep_drop.effects[0].operation,
			EffectSpec.Operation.ADJUST_DIE,
			"deep drop should adjust a die"
		)
		assert_equal(deep_drop.effects[0].amount, -3, "deep drop should subtract three")

	var amplified := catalog.find_card(&"shop_amplified_chain")
	assert_true(amplified != null, "amplified chain shop card should load")
	if amplified != null:
		assert_equal(
			amplified.target_type,
			CardDefinition.TargetType.TABLE,
			"amplified chain targets a table"
		)
		assert_equal(amplified.effects.size(), 2, "amplified chain should contain two effects")
		assert_equal(
			amplified.effects[0].operation,
			EffectSpec.Operation.MODIFY_COEFFICIENT,
			"amplified chain modifies coefficient first"
		)
		assert_equal(amplified.effects[0].amount, 2, "amplified chain adds two coefficient")
		assert_equal(
			amplified.effects[1].operation,
			EffectSpec.Operation.REPEAT_TABLE,
			"amplified chain repeats second"
		)
		assert_equal(amplified.effects[1].amount, 1, "amplified chain repeats once")

	var reverse_backup := catalog.find_card(&"shop_reverse_backup")
	assert_true(reverse_backup != null, "reverse backup shop card should load")
	if reverse_backup != null:
		assert_equal(
			reverse_backup.target_type,
			CardDefinition.TargetType.GLOBAL,
			"reverse backup targets the resolution"
		)
		assert_equal(reverse_backup.effects.size(), 1, "reverse backup should contain one effect")
		assert_equal(
			reverse_backup.effects[0].operation,
			EffectSpec.Operation.REVERSE_RESOLUTION,
			"reverse backup should reverse resolution"
		)

	var missing = catalog.find_card(&"missing_card")
	assert_true(missing == null, "unknown card IDs should return null")
