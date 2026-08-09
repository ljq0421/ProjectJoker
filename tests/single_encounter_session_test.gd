extends "res://tests/test_case.gd"

const SessionScript = preload("res://scripts/ui/single_encounter_session.gd")

func run() -> void:
	var session := SessionScript.new(
		SingleEncounterFixture.make_state(),
		SingleEncounterFixture.make_encounter(),
		SingleEncounterFixture.make_hand()
	)

	_assign(session, &"d1", &"left")
	_assign(session, &"d6", &"left")
	_assign(session, &"d2", &"middle")
	_assign(session, &"d3", &"middle")
	_assign(session, &"d4", &"middle")
	assert_true(session.activate_die(&"d5"), "d5 should select for calibration")
	assert_true(session.calibrate_die(&"d5", -1), "d5 should calibrate to four")
	assert_equal(
		session.selection.kind,
		InteractionState.Kind.NONE,
		"accepted calibration should immediately clear the die selection"
	)
	_assign(session, &"d5", &"right")
	assert_equal(session.preview().total, 44, "base placement should preview 44")

	assert_true(session.activate_card(1), "table card should become selected")
	assert_true(session.activate_table(&"left"), "selected table card should play")
	assert_equal(session.preview().total, 51, "coefficient card should preview 51")
	assert_true(session.undo(), "card play should be undoable")
	assert_equal(session.preview().total, 44, "undo should restore 44")

	assert_true(session.activate_card(2), "gap card should become selected")
	assert_true(session.activate_gap(&"left", &"middle"), "gap target should play the card")
	assert_true(session.is_card_used(2), "played gap card should be disabled")

	var target_session := SessionScript.new(
		SingleEncounterFixture.make_state(),
		SingleEncounterFixture.make_encounter(),
		SingleEncounterFixture.make_hand()
	)
	assert_true(target_session.activate_card(0), "die card should become selected")
	assert_true(target_session.activate_die(&"d6"), "selected die card should play on d6")
	assert_true(target_session.is_card_used(0), "die card should become used")
	assert_true(target_session.activate_card(3), "global card should play immediately")
	assert_true(target_session.is_card_used(3), "global card should become used")

func _assign(session, die_id: StringName, table_id: StringName) -> void:
	assert_true(session.activate_die(die_id), "die should become selected")
	assert_true(session.activate_table(table_id), "selected die should enter lane")
