extends "res://tests/test_case.gd"

const Formatter = preload("res://scripts/ui/card_display_formatter.gd")

func run() -> void:
	_test_every_card_has_compact_visible_copy()
	_test_card_tokens_use_scene_owned_hierarchy()
	_test_complete_shop_card_uses_plain_price_footer()
	_test_rarity_track_is_explicit()
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

func _test_card_tokens_use_scene_owned_hierarchy() -> void:
	var card := CardCatalog.new().find_card(&"faceless_swap_values")
	var token: CardToken = load(
		"res://scenes/components/card_token.tscn"
	).instantiate()
	token.bind_card(0, card, false, false)
	var face := token.get_node("CardFaceContent")
	assert_true(face != null, "hand card should own a structured card face")
	assert_true(
		"交换两颗骰值" in face.visible_copy() and "当前有效点数" in face.visible_copy(),
		"hand card should expose its action, value, and limit"
	)
	assert_true(
		face.is_complete_card_face(),
		"hand card should show its complete deterministic card face"
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
	var shop_face := shop_token.get_node("CardFaceContent")
	assert_true(shop_face != null, "shop card should own a structured card face")
	assert_true(
		shop_face.get_node("%DynamicPriceCopy").text == "1 情报券",
		"shop card should keep the price visible before selection"
	)
	shop_token.free()

func _test_complete_shop_card_uses_plain_price_footer() -> void:
	var card := CardCatalog.new().find_card(&"shop_precision_map")
	var shop_token: ShopCardToken = load(
		"res://scenes/components/shop_card_token.tscn"
	).instantiate()
	shop_token.bind_card(card, false, false, &"offer", 1)
	var face := shop_token.get_node("CardFaceContent")
	var price_footer := face.get_node("%DynamicPriceBadge")
	assert_true(
		price_footer is MarginContainer,
		"complete shop card price should be a plain footer without a panel frame"
	)
	assert_equal(
		face.get_node("%DynamicPriceCopy").text,
		"1 情报券",
		"complete shop card should show its price directly below the SVG"
	)
	assert_equal(
		face.get_node("%FullCardArtwork").offset_bottom,
		-23.0,
		"complete shop card should reserve a dedicated footer below the SVG"
	)
	assert_true(
		shop_token.get_theme_stylebox("normal") is StyleBoxEmpty,
		"shop card button should not draw an extra frame around SVG and price"
	)
	shop_token.free()

func _test_rarity_track_is_explicit() -> void:
	var catalog := CardCatalog.new()
	var cases := {
		&"starter_nudge_down_1": ["骰值 -1", "范围 1–6", "◆◇◇"],
		&"shop_precision_map": ["系数 +3", "", "◆◆◇"],
		&"starter_link": ["连接相邻台", "传递已解析结果", "◆◆◇"],
		&"starter_reverse": ["反转顺序", "本轮生效", "◆◆◇"],
		&"faceless_copy_value": ["复制第一颗", "当前有效点数", "◆◆◇"],
		&"faceless_lock_bonus": ["锁定骰值", "规则台通过 +4", "◆◆◆"],
		&"starter_nudge_up_1": ["骰值 +1", "范围 1–6", "◆◇◇"],
		&"starter_nudge_down_2": ["骰值 -2", "范围 1–6", "◆◆◇"],
		&"starter_nudge_up_2": ["骰值 +2", "范围 1–6", "◆◆◇"],
		&"starter_map_1": ["系数 +1", "", "◆◇◇"],
		&"starter_map_2": ["系数 +2", "", "◆◇◇"],
		&"starter_repeat_1": ["额外结算 1 次", "本轮生效", "◆◇◇"],
		&"starter_repeat_2": ["额外结算 2 次", "本轮生效", "◆◇◇"],
		&"starter_stable_repeat": ["系数 -1 · 结算 +1 次", "最低 1 · 本轮生效", "◆◇◇"],
		&"starter_amplified_repeat": ["系数 +1 · 结算 +1 次", "本轮生效", "◆◇◇"],
		&"shop_triple_repeat": ["额外结算 3 次", "本轮生效", "◆◆◆"],
		&"shop_long_push": ["骰值 +3", "范围 1–6", "◆◆◆"],
		&"shop_deep_drop": ["骰值 -3", "范围 1–6", "◆◆◆"],
		&"mirror_folded_map": ["系数 +2", "镜像：系数 +1", "◆◆◆"],
		&"mirror_soft_echo": ["额外结算 2 次", "镜像：额外结算 1 次", "◆◆◇"],
		&"mirror_hinged_bridge": ["连接 · 系数 +1", "镜像：连接相邻规则台", "◆◆◇"],
		&"mirror_double_exposure": ["系数 +2 · 结算 +1 次", "镜像：系数 +1", "◆◆◆"],
		&"mirror_deep_echo": ["系数 +1 · 结算 +2 次", "镜像：额外结算 1 次", "◆◆◆"],
		&"mirror_silver_bridge": ["连接 · 结算 +1 次", "镜像：连接相邻规则台", "◆◆◆"],
		&"shop_amplified_chain": ["系数 +2 · 结算 +1 次", "本轮生效", "◆◆◇"],
		&"shop_reverse_backup": ["反转顺序", "本轮生效", "◆◆◆"],
		&"faceless_swap_values": ["交换两颗骰值", "当前有效点数", "◆◆◇"],
		&"faceless_flip_value": ["骰值翻面", "7 - 当前值", "◆◆◆"],
		&"faceless_refund_calibration": ["返还 1 校准点", "校准点上限 2", "◆◆◇"],
		&"faceless_exact_tolerance": ["精确条件放宽", "允许 ±1", "◆◆◇"],
		&"faceless_even_tolerance": ["全偶条件放宽", "允许 1 颗奇数", "◆◆◆"],
		&"faceless_sequence_tolerance": ["连续条件放宽", "允许 1 个差2缺口", "◆◆◆"],
		&"faceless_table_receipt": ["情报券 +1", "目标台通过时", "◆◆◇"],
		&"faceless_full_allocation": ["情报券 +2", "分配全部骰子时", "◆◆◇"],
		&"faceless_three_seats": ["情报券 +2", "三台均有骰时", "◆◆◆"],
		&"faceless_complete_dossier": ["情报券 +3", "三台均通过时", "◆◆◆"],
		&"faceless_strict_mapping": ["所需骰位 +1 · 系数 +2", "骰位上限 6", "◆◆◇"],
		&"faceless_reverse_replay": ["反转顺序 · 结算 +1 次", "本轮生效", "◆◆◇"],
		&"faceless_compressed_repeat": ["系数 -1 · 结算 +2 次", "最低 1 · 本轮生效", "◆◆◆"],
		&"faceless_closed_circuit": ["连接 · 结算 +1 次", "传递结果 · 本轮生效", "◆◆◆"],
	}
	for card_id in cases:
		var token: CardToken = load(
			"res://scenes/components/card_token.tscn"
		).instantiate()
		var card := catalog.find_card(card_id)
		token.bind_card(0, card, false, false)
		var face := token.get_node("CardFaceContent")
		assert_equal(
			face.rarity_track_copy(),
			cases[card_id][2],
			"%s should expose a three-slot rarity track" % card_id
		)
		assert_equal(
			face.get_node("%EffectSummary").text,
			cases[card_id][0],
			"%s should expose its concise action" % card_id
		)
		assert_equal(
			face.get_node("%EffectDetail").text,
			cases[card_id][1],
			"%s should expose its decision-critical detail" % card_id
		)
		assert_equal(
			face.get_node("%FullCardArtwork").texture.resource_path,
			Formatter.new().card_art_path(card),
			"%s should fill the card with its deterministic SVG" % card_id
		)
		assert_true(
			face.is_complete_card_face(),
			"%s should render as one complete card face" % card_id
		)
		token.free()

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
