extends "res://tests/test_case.gd"

const Formatter = preload("res://scripts/ui/card_display_formatter.gd")

func run() -> void:
	_test_every_card_has_compact_visible_copy()
	_test_card_tokens_use_semantic_icons()
	_test_rule_lane_pairs_formula_with_plain_language()
	_test_detail_regions_are_scene_owned()

func _test_every_card_has_compact_visible_copy() -> void:
	var formatter := Formatter.new()
	for card in CardCatalog.new().all_cards():
		var copy := formatter.compact_copy(card)
		var lines := copy.split("\n")
		assert_true(
			lines.size() >= 3 and lines.size() <= 4,
			"%s compact copy should use three or four visible lines" % card.id
		)
		assert_true(
			card.display_name in copy,
			"%s compact copy should keep the card name visible" % card.id
		)
		assert_true(
			formatter.target_copy_for(card) in copy,
			"%s compact copy should keep the target visible" % card.id
		)
		assert_true(
			ResourceLoader.exists(formatter.effect_icon_path(card)),
			"%s should resolve an imported semantic effect icon" % card.id
		)
		assert_true(
			ResourceLoader.exists(formatter.target_icon_path(card.target_type)),
			"%s should resolve an imported target icon" % card.id
		)

func _test_card_tokens_use_semantic_icons() -> void:
	var card := CardCatalog.new().find_card(&"starter_nudge_up_1")
	var token: CardToken = load(
		"res://scenes/components/card_token.tscn"
	).instantiate()
	token.bind_card(0, card, false, false)
	assert_true(token.icon != null, "hand card should show its effect icon")
	assert_true(
		"骰值 +1" in token.text and "范围 1–6" in token.text,
		"hand card should expose its action, value, and limit"
	)
	assert_true(
		card.rule_text in token.tooltip_text,
		"hand card tooltip should retain the complete rule"
	)
	token.free()

	var shop_token: ShopCardToken = load(
		"res://scenes/components/shop_card_token.tscn"
	).instantiate()
	shop_token.bind_card(card, false, false, &"offer", 1)
	assert_true(shop_token.icon != null, "shop card should show its effect icon")
	assert_true(
		"1 情报券" in shop_token.text,
		"shop card should keep the price visible before selection"
	)
	shop_token.free()

func _test_rule_lane_pairs_formula_with_plain_language() -> void:
	var lane: RuleLane = load(
		"res://scenes/components/rule_lane.tscn"
	).instantiate()
	var rule := RuleDefinition.new()
	rule.display_name = "精确为 9"
	rule.template = load("res://resources/rules/templates/rule_exact_sum.tres")
	rule.target_value = 9
	assert_equal(
		lane.rule_formula_copy(rule),
		"Σ = 9",
		"exact-sum lane should expose a mathematical scan line"
	)
	assert_true(
		lane.get_node_or_null("%Formula") != null,
		"rule lane should own a separate formula label"
	)
	lane.free()

func _test_detail_regions_are_scene_owned() -> void:
	var encounter = load(
		"res://scenes/run/single_encounter_screen.tscn"
	).instantiate()
	assert_true(
		encounter.get_node_or_null("%CardDetailPanel") != null,
		"encounter scene should own the selected-card detail region"
	)
	encounter.free()

	var shop = load("res://scenes/shop/shop_screen.tscn").instantiate()
	assert_true(
		shop.get_node_or_null("%ShopCardDetailPanel") != null,
		"shop scene should own the selected-card comparison region"
	)
	shop.free()
