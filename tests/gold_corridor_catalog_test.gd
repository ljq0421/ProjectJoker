extends "res://tests/test_case.gd"

func run() -> void:
	var catalog := GoldCorridorCatalog.new()
	var expected_rooms := _expected_rooms()
	assert_equal(catalog.validate(), [], "Gold Corridor content should validate")
	assert_equal(
		catalog.first_route_ids(),
		[&"gold_room_precise_steps", &"gold_room_even_split"],
		"first route group should be fixed"
	)
	assert_equal(
		catalog.second_route_ids(),
		[&"gold_room_narrow_ledger", &"gold_room_parallel_proof"],
		"second route group should be fixed"
	)
	assert_equal(catalog.all_rooms().size(), 4, "catalog should contain four rooms")

	for room_id in expected_rooms:
		var room := catalog.find_room(room_id)
		assert_true(room != null, "%s should load" % room_id)
		if room == null:
			continue
		var expected: Dictionary = expected_rooms[room_id]
		assert_false(room.display_name.strip_edges().is_empty(), "%s should have a name" % room_id)
		assert_false(room.description.strip_edges().is_empty(), "%s should have a description" % room_id)
		assert_true(not room.tags.is_empty(), "%s should have display tags" % room_id)
		assert_equal(room.target_total, expected.target, "%s target should match" % room_id)
		assert_equal(
			room.success_intel_reward,
			expected.reward,
			"%s reward should match" % room_id
		)
		assert_equal(
			room.synergy_tags,
			expected.synergy_tags,
			"%s synergy tags should match" % room_id
		)
		assert_equal(room.encounter.rules.size(), 3, "%s should have three lanes" % room_id)
		var slot_total := 0
		for index in range(room.encounter.rules.size()):
			var rule := room.encounter.rules[index]
			slot_total += rule.slot_count
			assert_equal(
				rule.condition_type,
				expected.conditions[index],
				"%s lane %d condition should match" % [room_id, index]
			)
			assert_equal(
				rule.slot_count,
				expected.slots[index],
				"%s lane %d slots should match" % [room_id, index]
			)
			assert_equal(
				rule.coefficient,
				expected.coefficients[index],
				"%s lane %d coefficient should match" % [room_id, index]
			)
			assert_equal(
				rule.target_value,
				expected.targets[index],
				"%s lane %d target should match" % [room_id, index]
			)
		assert_equal(slot_total, 6, "%s should expose six slots" % room_id)

	assert_true(catalog.find_room(&"missing_room") == null, "unknown room should return null")

func _expected_rooms() -> Dictionary:
	return {
		&"gold_room_precise_steps": {
			"target": 100,
			"reward": 2,
			"conditions": [
				RuleDefinition.ConditionType.EXACT_SUM,
				RuleDefinition.ConditionType.CONSECUTIVE,
				RuleDefinition.ConditionType.ALL_EVEN,
			],
			"slots": [2, 3, 1],
			"coefficients": [2, 2, 3],
			"targets": [7, 0, 0],
			"synergy_tags": PackedStringArray(["骰值", "校准", "重复"]),
		},
		&"gold_room_even_split": {
			"target": 110,
			"reward": 3,
			"conditions": [
				RuleDefinition.ConditionType.ALL_EVEN,
				RuleDefinition.ConditionType.EXACT_SUM,
				RuleDefinition.ConditionType.CONSECUTIVE,
			],
			"slots": [2, 2, 2],
			"coefficients": [3, 2, 2],
			"targets": [0, 9, 0],
			"synergy_tags": PackedStringArray(["骰值", "校准", "系数"]),
		},
		&"gold_room_narrow_ledger": {
			"target": 120,
			"reward": 2,
			"conditions": [
				RuleDefinition.ConditionType.EXACT_SUM,
				RuleDefinition.ConditionType.CONSECUTIVE,
				RuleDefinition.ConditionType.ALL_EVEN,
			],
			"slots": [2, 3, 1],
			"coefficients": [3, 2, 3],
			"targets": [10, 0, 0],
			"synergy_tags": PackedStringArray(["骰值", "校准", "重复"]),
		},
		&"gold_room_parallel_proof": {
			"target": 135,
			"reward": 3,
			"conditions": [
				RuleDefinition.ConditionType.ALL_EVEN,
				RuleDefinition.ConditionType.EXACT_SUM,
				RuleDefinition.ConditionType.CONSECUTIVE,
			],
			"slots": [2, 2, 2],
			"coefficients": [3, 3, 3],
			"targets": [0, 8, 0],
			"synergy_tags": PackedStringArray(["骰值", "校准", "系数"]),
		},
	}
