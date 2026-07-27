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
		assert_equal(dealer.display_name, "铁算盘", "dealer name should be stable")
		assert_equal(dealer.fixed_reward, 12, "dealer full reward should be twelve")
		assert_equal(
			dealer.penalty_per_unassigned_die,
			2,
			"dealer should lose two per unassigned die"
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
