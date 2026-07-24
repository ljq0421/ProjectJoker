extends "res://tests/test_case.gd"

const DieStateScript = preload("res://scripts/run/die_state.gd")
const RoundStateScript = preload("res://scripts/run/round_state.gd")
const RoundActionsScript = preload("res://scripts/run/round_actions.gd")

func run() -> void:
	var state := RoundStateScript.new()
	state.dice = [
		DieStateScript.new(&"d1", 1),
		DieStateScript.new(&"d2", 6),
	]

	var adjusted = RoundActionsScript.adjust_die(state, &"d1", 1)
	assert_true(adjusted.accepted, "a +1 calibration should be accepted")
	assert_equal(adjusted.next_state.find_die(&"d1").value, 2, "calibration should change cloned state")
	assert_equal(state.find_die(&"d1").value, 1, "calibration must not mutate original state")
	assert_equal(adjusted.next_state.calibration_points, 1, "calibration should consume one point")

	var out_of_range = RoundActionsScript.adjust_die(state, &"d2", 1)
	assert_false(out_of_range.accepted, "a die cannot be calibrated above 6")

	var first_assignment = RoundActionsScript.assign_die(state, &"d1", &"left", 2)
	var moved_assignment = RoundActionsScript.assign_die(first_assignment.next_state, &"d1", &"right", 1)
	assert_equal(moved_assignment.next_state.assignments[&"left"].size(), 0, "moving should clear old table")
	assert_equal(moved_assignment.next_state.assignments[&"right"], [&"d1"], "die should exist in one table")

	var full_table = RoundActionsScript.assign_die(moved_assignment.next_state, &"d2", &"right", 1)
	assert_false(full_table.accepted, "assignment should reject a full table")
