extends "res://tests/test_case.gd"

func run() -> void:
	var dealers := DealerCatalog.new()
	var engravings := EngravingCatalog.new()
	assert_equal(dealers.validate(), [], "dealer content should validate")
	assert_equal(engravings.validate(), [], "engraving content should validate")

	var dealer := dealers.iron_abacus()
	assert_true(dealer != null, "Iron Abacus should load")
	if dealer != null:
		assert_equal(dealer.id, &"dealer_iron_abacus", "dealer ID should be stable")
		assert_equal(
			dealer.opening_text,
			"六颗骰子，三张规则台，一笔不能含糊的账。把每颗骰子放到你愿意负责的位置——空着的，照样记在账上。",
			"Iron Abacus opening should match the narrative contract"
		)
		assert_equal(dealer.display_name, "铁算盘", "dealer name should be stable")
		assert_equal(dealer.fixed_reward, 12, "dealer full reward should be twelve")
		assert_equal(
			dealer.penalty_per_unassigned_die,
			2,
			"dealer should lose two per unassigned die"
		)

	var expected_openings := {
		&"dealer_iron_abacus": "六颗骰子，三张规则台，一笔不能含糊的账。把每颗骰子放到你愿意负责的位置——空着的，照样记在账上。",
		&"dealer_mirror_lady": "你在右边落下的答案，会从左边看回来。别问哪一面是真的；先证明你看得懂它们为何相同。",
		&"dealer_faceless_master": "名字会变，次序会变，限制也会在你选择后才有意义。但没有一条规则藏在面具后面——三轮都在这里。",
	}
	for dealer_definition in dealers.all_dealers():
		assert_equal(
			dealer_definition.opening_text,
			expected_openings[dealer_definition.id],
			"each dealer should expose the confirmed opening"
		)

	var expected_area_narratives := {
		&"gold_corridor": [
			"第一梦层 · 金线回廊",
			"梦层入口合拢，金线把地面分成可核验的路径。这里不收下注，只承认你能解释的选择。",
		],
		&"mirror_hall": [
			"第二梦层 · 反照牌厅",
			"铁算盘的账页封存，直线在出口处折回。你带走的牌、情报券与刻印穿过镜面，没有一项被重置。",
		],
		&"faceless_hub": [
			"第三梦层 · 无面中枢",
			"镜面碎成无名的索引，倒影失去主人。你保留全部构筑，下一位庄家则把三轮规则提前摊开。",
		],
	}
	for area in AreaCatalog.new().all_areas():
		assert_equal(
			area.expedition_entry_title,
			expected_area_narratives[area.id][0],
			"area transition title should match the narrative contract"
		)
		assert_equal(
			area.expedition_entry_text,
			expected_area_narratives[area.id][1],
			"area transition text should match the narrative contract"
		)

	var expected := PackedStringArray([
		"engraving_echo",
		"engraving_anchor",
		"engraving_bridge",
		"engraving_prism",
		"engraving_afterimage",
		"engraving_silver_anchor",
		"engraving_backflow_bridge",
		"engraving_mirror_prism",
		"engraving_low_murmur",
		"engraving_terminal_anchor",
		"engraving_two_way_bridge",
		"engraving_sequence_prism",
	])
	var actual := PackedStringArray()
	for engraving_id in engravings.all_ids():
		actual.append(String(engraving_id))
	actual.sort()
	expected.sort()
	assert_equal(actual, expected, "catalog should expose exactly twelve engravings")

	var expected_operations := {
		&"engraving_echo": [EngravingDefinition.Operation.ECHO_ADJACENT, 2],
		&"engraving_anchor": [EngravingDefinition.Operation.ANCHOR_DIE, 4],
		&"engraving_bridge": [EngravingDefinition.Operation.BRIDGE_FORWARD, 1],
		&"engraving_prism": [EngravingDefinition.Operation.PRISM_PARITY, 0],
		&"engraving_afterimage": [EngravingDefinition.Operation.ECHO_ADJACENT, 1],
		&"engraving_silver_anchor": [EngravingDefinition.Operation.ANCHOR_DIE, 3],
		&"engraving_backflow_bridge": [EngravingDefinition.Operation.BRIDGE_BACKWARD, 1],
		&"engraving_mirror_prism": [EngravingDefinition.Operation.MIRROR_PRISM, 0],
		&"engraving_low_murmur": [EngravingDefinition.Operation.ECHO_LOWER_ADJACENT, 0],
		&"engraving_terminal_anchor": [EngravingDefinition.Operation.ANCHOR_LAST_TABLE, 5],
		&"engraving_two_way_bridge": [EngravingDefinition.Operation.BRIDGE_BIDIRECTIONAL, 2],
		&"engraving_sequence_prism": [EngravingDefinition.Operation.PRISM_SEQUENCE, 0],
	}
	for engraving in engravings.all_engravings():
		assert_false(engraving.rule_text.strip_edges().is_empty(), "rule text should exist")
		assert_true(engraving.tags.size() >= 1, "display tags should exist")
		assert_equal(
			engraving.operation,
			expected_operations[engraving.id][0],
			"engraving operation should match its stable ID"
		)
		assert_equal(
			engraving.amount,
			expected_operations[engraving.id][1],
			"engraving amount should match its stable ID"
		)
	assert_true(
		engravings.find_engraving(&"missing_engraving") == null,
		"unknown engraving IDs should return null"
	)
