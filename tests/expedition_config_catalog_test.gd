extends "res://tests/test_case.gd"

const ExpeditionConfigs = preload("res://scripts/run/expedition_config_catalog.gd")
const ChallengeRules = preload("res://scripts/run/expedition_challenge_rules.gd")
const BuildIdentities = preload("res://scripts/run/build_identity_catalog.gd")

func run() -> void:
	var catalog := ExpeditionConfigs.new()
	var cards := CardCatalog.new()
	var identities := BuildIdentities.new()
	assert_equal(catalog.validate(cards), [], "expedition configs should be valid")
	assert_equal(catalog.all_decks().size(), 3, "three starting decks should be public")
	assert_equal(catalog.all_challenges().size(), 6, "six challenges should be public")

	for deck in catalog.all_decks():
		assert_equal(deck["card_ids"].size(), 12, "%s should contain twelve cards" % deck["id"])
		var unique: Dictionary = {}
		var identity_count := 0
		for card_id in deck["card_ids"]:
			unique[card_id] = true
			var card := cards.find_card(card_id)
			assert_true(card != null, "%s should reference a formal card" % card_id)
			if identities.identity_for_card(card) == deck["identity_id"]:
				identity_count += 1
		assert_equal(unique.size(), 12, "%s should not repeat cards" % deck["id"])
		assert_true(identity_count >= 5, "%s should express its identity" % deck["id"])

	assert_equal(
		catalog.selection_error(&"dice_control", [], false),
		"",
		"all starting decks should be immediately available"
	)
	assert_true(
		not catalog.selection_error(&"dice_control", [&"high_pressure"], false).is_empty(),
		"challenges should remain locked before a complete expedition"
	)

	var valid_config_count := 1
	var challenge_ids := catalog.challenge_ids()
	for challenge_id in challenge_ids:
		assert_equal(
			catalog.selection_error(&"table_chain", [challenge_id], true),
			"",
			"each single challenge should be legal"
		)
		valid_config_count += 1
	for left_index in challenge_ids.size():
		for right_index in range(left_index + 1, challenge_ids.size()):
			assert_equal(
				catalog.selection_error(
					&"intel_economy",
					[challenge_ids[left_index], challenge_ids[right_index]],
					true
				),
				"",
				"each two-challenge pair should be legal"
			)
			valid_config_count += 1
	assert_equal(valid_config_count, 22, "zero, singles and pairs should make 22 configs")
	assert_true(
		not catalog.selection_error(
			&"dice_control",
			[&"high_pressure", &"short_hand", &"no_undo"],
			true
		).is_empty(),
		"more than two challenges should be rejected"
	)

	var rules := ChallengeRules.new([
		&"high_pressure",
		&"market_surge",
	])
	assert_equal(rules.target_total(100), 115, "high pressure should add fifteen percent")
	assert_equal(rules.shop_price(1), 2, "market surge should add one ticket")
	assert_equal(rules.hand_size(false), 4, "inactive short hand should keep four cards")

	rules = ChallengeRules.new([
		&"short_hand",
		&"intel_squeeze",
	])
	assert_equal(rules.hand_size(false), 3, "short hand should draw three cards")
	assert_equal(rules.hand_size(true), 4, "fixed puzzles should retain four cards")
	assert_equal(rules.intel_reward(2), 1, "intel squeeze should reduce room reward")

	rules = ChallengeRules.new([
		&"no_undo",
		&"full_table_rule",
	])
	assert_true(not rules.undo_allowed(), "no undo should disable undo")
	assert_true(rules.full_table_required(), "full table should add a public restriction")
