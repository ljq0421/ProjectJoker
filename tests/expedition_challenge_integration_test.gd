extends "res://tests/test_case.gd"

func run() -> void:
	var gold := AreaCatalog.new().gold_corridor()
	var baseline := AreaRunSession.new(778899, gold)
	assert_true(baseline.start().accepted, "baseline area should start")
	var baseline_routes := baseline.current_route_ids()
	var room_id := baseline_routes[0]
	var room := gold.find_room(room_id)
	assert_true(baseline.select_route(room_id).accepted, "baseline room should start")

	var challenged := AreaRunSession.new(778899, gold)
	assert_true(
		challenged.configure_challenges([
			&"high_pressure",
			&"no_undo",
		]).accepted,
		"area should accept two public challenges"
	)
	assert_true(challenged.start().accepted, "challenged area should start")
	assert_equal(
		challenged.current_route_ids(),
		baseline_routes,
		"challenges should not change route RNG"
	)
	assert_true(challenged.select_route(room_id).accepted, "challenged room should start")
	assert_equal(
		challenged.encounter_session.target_total,
		int(ceili(float(room.target_total) * 1.15)),
		"high pressure should modify the domain target"
	)
	assert_true(
		challenged.encounter_session.current_session.undo_allowed,
		"no-undo challenge should still expose its one global undo"
	)
	assert_equal(
		challenged.encounter_session.current_session.controller.undo_mode,
		RoundController.UndoMode.GLOBAL_ONE,
		"no-undo challenge should reach the active encounter as a shared quota"
	)

	var mirror := AreaRunSession.new(112233, AreaCatalog.new().mirror_hall())
	assert_true(mirror.configure_challenges([&"short_hand"]).accepted, "short hand should configure")
	assert_true(mirror.start().accepted, "mirror area should start")
	var fixed_room_id := &"symmetric_page"
	if fixed_room_id not in mirror.current_route_ids():
		fixed_room_id = mirror.current_route_ids()[0]
	assert_true(mirror.select_route(fixed_room_id).accepted, "mirror room should start")
	if AreaCatalog.new().mirror_hall().find_room(fixed_room_id).fixed_hand_ids.is_empty():
		assert_equal(
			mirror.encounter_session.current_hand_ids.size(),
			3,
			"non-fixed room should draw three cards"
		)
	else:
		assert_equal(
			mirror.encounter_session.current_hand_ids.size(),
			4,
			"fixed puzzle should keep its public four-card hand"
		)

	var full_table := AreaRunSession.new(778899, gold)
	assert_true(full_table.configure_challenges([&"full_table_rule"]).accepted, "rule should configure")
	assert_true(full_table.start().accepted, "full-table area should start")
	var full_table_room_id := full_table.current_route_ids()[0]
	assert_true(full_table.select_route(full_table_room_id).accepted, "full-table room should start")
	assert_true(
		full_table.encounter_session.current_session.controller.active_restrictions.any(
			func(restriction: FinalRestrictionDefinition) -> bool: return (
				restriction.id == &"challenge_full_table"
			)
		),
		"full-table challenge should be a public domain restriction"
	)
