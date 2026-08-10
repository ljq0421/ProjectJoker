extends "res://tests/test_case.gd"

const EXPECTED_IDS: Array[StringName] = [
	&"faceless_swap_values",
	&"faceless_copy_value",
	&"faceless_flip_value",
	&"faceless_lock_bonus",
	&"faceless_refund_calibration",
	&"faceless_exact_tolerance",
	&"faceless_even_tolerance",
	&"faceless_sequence_tolerance",
	&"faceless_table_receipt",
	&"faceless_full_allocation",
	&"faceless_three_seats",
	&"faceless_complete_dossier",
	&"faceless_strict_mapping",
	&"faceless_reverse_replay",
	&"faceless_compressed_repeat",
	&"faceless_closed_circuit",
]

func run() -> void:
	var catalog := CardCatalog.new()
	assert_equal(catalog.all_cards().size(), 46, "catalog should expose forty-six cards")
	assert_equal(
		catalog.faceless_hub_card_ids().size(),
		16,
		"faceless group should contain sixteen cards"
	)
	assert_equal(catalog.validate(), [], "all forty-six cards should validate")
	var seen: Dictionary = {}
	for card in catalog.all_cards():
		assert_false(seen.has(card.id), "all card IDs should remain unique")
		seen[card.id] = true
	for card_id in EXPECTED_IDS:
		var card := catalog.find_card(card_id)
		assert_true(card != null, "%s should load" % card_id)
		if card == null:
			continue
		assert_false(card.rule_text.strip_edges().is_empty(), "%s has public rules" % card_id)
		assert_false(card.rank_label.strip_edges().is_empty(), "%s has a rank" % card_id)
		assert_true(card.tags.size() >= 1, "%s has display tags" % card_id)
		assert_true(card.effects.size() >= 1, "%s has structured effects" % card_id)
		assert_false(card_id in catalog.starter_ids(), "%s is not a starter ID" % card_id)
		assert_false(card_id in catalog.shop_ids(), "%s is not a legacy shop ID" % card_id)
		assert_false(
			card_id in catalog.mirror_hall_card_ids(),
			"%s is not a mirror hall ID" % card_id
		)
	_assert_key_effects(catalog)

func _assert_key_effects(catalog: CardCatalog) -> void:
	assert_equal(
		catalog.find_card(&"faceless_swap_values").effects[0].operation,
		EffectSpec.Operation.SWAP_DICE,
		"swap card uses deterministic swap"
	)
	assert_equal(
		catalog.find_card(&"faceless_exact_tolerance").effects[0].condition_modifier,
		EffectSpec.ConditionModifier.EXACT_TOLERANCE,
		"exact tolerance stores its modifier"
	)
	assert_equal(
		catalog.find_card(&"faceless_complete_dossier").effects[0].intel_condition,
		EffectSpec.IntelCondition.ALL_TABLES_PASSED,
		"dossier stores the all-pass trigger"
	)
	var strict := catalog.find_card(&"faceless_strict_mapping")
	assert_equal(strict.effects.size(), 2, "strict mapping has cost and reward")
	assert_equal(
		strict.effects[0].condition_modifier,
		EffectSpec.ConditionModifier.INCREASE_SLOT_COUNT,
		"strict mapping increases required slots"
	)
	assert_equal(strict.effects[1].amount, 2, "strict mapping adds two coefficient")
	var reverse := catalog.find_card(&"faceless_reverse_replay")
	assert_equal(reverse.target_type, CardDefinition.TargetType.GAP, "reverse replay targets a gap")
	assert_equal(reverse.effects.size(), 2, "reverse replay has two effects")
	var closed := catalog.find_card(&"faceless_closed_circuit")
	assert_equal(closed.target_type, CardDefinition.TargetType.GAP, "closed circuit targets a gap")
	assert_equal(closed.effects.size(), 2, "closed circuit has two effects")
