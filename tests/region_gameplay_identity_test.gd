extends "res://tests/test_case.gd"

func run() -> void:
	_test_gold_corridor_uses_one_round_contracts()
	_test_mirror_hall_always_uses_mirror_play()
	_test_faceless_hub_always_uses_public_restrictions()

func _test_gold_corridor_uses_one_round_contracts() -> void:
	var area := AreaCatalog.new().gold_corridor()
	var expected_targets := {
		&"gold_room_precise_steps": 42,
		&"gold_room_even_split": 46,
		&"gold_room_narrow_ledger": 48,
		&"gold_room_parallel_proof": 52,
	}
	for room in area.rooms:
		assert_equal(
			room.activity_kind,
			RoomDefinition.ActivityKind.SINGLE_ROUND_CONTRACT,
			"%s should express the gold one-round contract identity" % room.id
		)
		assert_equal(room.round_count, 1, "%s should resolve in one round" % room.id)
		assert_equal(
			room.target_total,
			expected_targets[room.id],
			"%s should use its rebalanced one-round target" % room.id
		)

func _test_mirror_hall_always_uses_mirror_play() -> void:
	var area := AreaCatalog.new().mirror_hall()
	for room in area.rooms:
		var profile := room.encounter.rule_profile
		assert_true(profile != null, "%s should expose a public rule profile" % room.id)
		if profile == null:
			continue
		assert_true(
			profile.mirror_first_table_card,
			"%s should create a weakened mirror copy" % room.id
		)
		assert_equal(
			profile.mirror_limit_per_round,
			1,
			"%s should expose one mirror-copy opportunity per round" % room.id
		)

func _test_faceless_hub_always_uses_public_restrictions() -> void:
	var area := AreaCatalog.new().faceless_hub()
	for room in area.rooms:
		assert_true(
			room.restriction != null,
			"%s should apply a visible faceless protocol from round one" % room.id
		)
		if room.restriction != null:
			assert_equal(
				room.restriction.validate(),
				[],
				"%s restriction should validate" % room.id
			)
