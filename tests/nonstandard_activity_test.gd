extends "res://tests/test_case.gd"

func run() -> void:
	_test_formal_room_configuration()
	_test_dynamic_round_count_and_fixed_hand()
	_test_area_session_uses_room_activity_setup()

func _test_formal_room_configuration() -> void:
	var areas := AreaCatalog.new()
	var gold := areas.gold_corridor().find_room(&"gold_room_narrow_ledger")
	var mirror := areas.mirror_hall().find_room(&"mirror_room_symmetric_page")
	var faceless := areas.faceless_hub().find_room(
		&"faceless_room_single_hand_agenda"
	)
	assert_equal(
		gold.activity_kind,
		RoomDefinition.ActivityKind.SINGLE_ROUND_CONTRACT,
		"narrow ledger should be the single-round contract"
	)
	assert_equal(gold.round_count, 1, "single-round contract should use one round")
	assert_equal(gold.target_total, 48, "single-round target should be rebalanced")
	assert_equal(
		mirror.activity_kind,
		RoomDefinition.ActivityKind.FIXED_HAND_PUZZLE,
		"symmetric page should be the fixed-hand puzzle"
	)
	assert_equal(mirror.round_count, 2, "fixed-hand puzzle should use two rounds")
	assert_equal(mirror.fixed_hand_ids.size(), 4, "fixed hand should expose four cards")
	assert_equal(
		faceless.activity_kind,
		RoomDefinition.ActivityKind.RULE_MUTATION,
		"single-hand agenda should be the rule mutation"
	)
	assert_equal(faceless.round_count, 2, "rule mutation should use two rounds")
	assert_equal(faceless.round_plans.size(), 2, "two mutation plans should be public")
	assert_false(
		_template_ids(faceless.round_plans[0].encounter)
			== _template_ids(faceless.round_plans[1].encounter),
		"the mutation should change the formal rule set"
	)

func _test_dynamic_round_count_and_fixed_hand() -> void:
	var setup := EncounterRunSetup.new()
	setup.round_count = 1
	setup.fixed_hand_ids.assign([
		&"starter_nudge_up_1",
		&"starter_nudge_down_1",
		&"starter_map_1",
		&"starter_repeat_1",
	])
	var session := ThreeRoundEncounterSession.new(
		CardCatalog.new(),
		20260731,
		0,
		setup
	)
	assert_true(session.start().accepted, "single-round session should start")
	assert_equal(session.round_count, 1, "session should expose its actual round count")
	assert_equal(
		session.current_hand_ids,
		setup.fixed_hand_ids,
		"fixed hand should replace the shuffled draw"
	)
	var report := session.current_session.commit()
	assert_true(
		session.accept_committed_report(report).accepted,
		"single committed report should be accepted"
	)
	assert_equal(
		session.status,
		ThreeRoundEncounterSession.Status.SUCCEEDED,
		"one-round session should finish after one report"
	)

func _test_area_session_uses_room_activity_setup() -> void:
	var cases := [
		[
			AreaCatalog.new().gold_corridor(),
			&"gold_room_narrow_ledger",
			1,
		],
		[
			AreaCatalog.new().mirror_hall(),
			&"mirror_room_symmetric_page",
			2,
		],
		[
			AreaCatalog.new().faceless_hub(),
			&"faceless_room_single_hand_agenda",
			2,
		],
	]
	for entry in cases:
		var area: AreaDefinition = entry[0]
		var room := area.find_room(entry[1])
		var run := AreaRunSession.new(20260731, area)
		assert_true(run.start().accepted, "%s should start" % area.id)
		assert_true(
			run._create_normal_room(room).accepted,
			"%s activity should open" % room.id
		)
		assert_equal(
			run.encounter_session.round_count,
			entry[2],
			"%s should pass its round count into the session" % room.id
		)
		if room.activity_kind == RoomDefinition.ActivityKind.FIXED_HAND_PUZZLE:
			assert_equal(
				run.encounter_session.current_hand_ids,
				room.fixed_hand_ids,
				"fixed-hand room should bind the public hand"
			)
		if room.activity_kind == RoomDefinition.ActivityKind.RULE_MUTATION:
			assert_equal(
				run.encounter_session.current_round_plan(),
				room.round_plans[0],
				"mutation room should start with its first public plan"
			)

func _template_ids(encounter: EncounterDefinition) -> PackedStringArray:
	var ids := PackedStringArray()
	for rule in encounter.rules:
		ids.append(String(rule.template.id))
	return ids
