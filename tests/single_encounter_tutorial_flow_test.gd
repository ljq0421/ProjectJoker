extends "res://tests/test_case.gd"

const FlowScript = preload("res://scripts/ui/tutorial/single_encounter_tutorial_flow.gd")

func run() -> void:
	var flow = FlowScript.new()
	var session := SingleEncounterSession.new(
		SingleEncounterFixture.make_state(),
		SingleEncounterFixture.make_encounter(),
		SingleEncounterFixture.make_hand()
	)
	flow.start()
	assert_equal(flow.step_index, 0, "tutorial should start at welcome")
	assert_false(
		flow.allows(&"select_die", {"die_id": &"d6"}, session),
		"welcome should block gameplay"
	)
	assert_true(flow.continue_step(session), "welcome continue should advance")

	_accept(
		flow,
		session,
		&"drag_assign",
		{"die_id": &"d1", "table_id": &"left"},
		func() -> bool: return session.assign_dropped_die(&"d1", &"left")
	)
	_accept(
		flow,
		session,
		&"select_die",
		{"die_id": &"d6"},
		func() -> bool: return session.activate_die(&"d6")
	)
	_accept(
		flow,
		session,
		&"click_assign",
		{"die_id": &"d6", "table_id": &"left"},
		func() -> bool: return session.activate_table(&"left")
	)

	for die_id in [&"d2", &"d3", &"d4"]:
		_accept(
			flow,
			session,
			&"select_die",
			{"die_id": die_id},
			func() -> bool: return session.activate_die(die_id)
		)
		_accept(
			flow,
			session,
			&"click_assign",
			{"die_id": die_id, "table_id": &"middle"},
			func() -> bool: return session.activate_table(&"middle")
		)

	_accept(
		flow,
		session,
		&"select_die",
		{"die_id": &"d5"},
		func() -> bool: return session.activate_die(&"d5")
	)
	_accept(
		flow,
		session,
		&"calibrate",
		{"die_id": &"d5", "delta": -1},
		func() -> bool: return session.calibrate_die(&"d5", -1)
	)
	_accept(
		flow,
		session,
		&"click_assign",
		{"die_id": &"d5", "table_id": &"right"},
		func() -> bool: return session.activate_table(&"right")
	)
	assert_equal(session.preview().total, 44, "completed base placement should be 44")

	_play_mapping(flow, session)
	assert_equal(session.preview().total, 51, "mapping lesson should reach 51")
	assert_equal(flow.step_index, 6, "prediction lesson should follow card play")
	assert_true(flow.continue_step(session), "prediction continue should advance")

	_accept(
		flow,
		session,
		&"undo",
		{},
		func() -> bool: return session.undo()
	)
	assert_equal(session.preview().total, 44, "undo lesson should restore 44")

	_play_mapping(flow, session)
	assert_equal(session.preview().total, 51, "reapply lesson should return to 51")
	_accept(
		flow,
		session,
		&"commit",
		{},
		func() -> bool: return session.commit().valid
	)
	assert_equal(flow.step_index, 10, "valid 51 commit should reach completion")
	assert_true(flow.can_finish(session), "completion should be finishable")

func _play_mapping(flow, session) -> void:
	_accept(
		flow,
		session,
		&"select_card",
		{"card_index": 1},
		func() -> bool: return session.activate_card(1)
	)
	_accept(
		flow,
		session,
		&"card_table",
		{"card_index": 1, "table_id": &"left"},
		func() -> bool: return session.activate_table(&"left")
	)

func _accept(flow, session, action: StringName, payload: Dictionary, operation: Callable) -> void:
	assert_true(flow.allows(action, payload, session), "tutorial should allow %s" % action)
	assert_true(operation.call(), "session should accept %s" % action)
	flow.record_accepted_action(action, payload, session)
