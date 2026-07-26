extends "res://tests/test_case.gd"

func run() -> void:
	var die := DieState.new(&"d1", 4, &"engraving_anchor", 4)
	die.value = 5
	var clone := die.clone()
	assert_equal(clone.id, &"d1", "clone should preserve die ID")
	assert_equal(clone.rolled_value, 4, "clone should preserve rolled value")
	assert_equal(clone.value, 5, "clone should preserve effective value")
	assert_equal(clone.engraving_id, &"engraving_anchor", "clone should preserve engraving")
	assert_equal(clone.engraved_face, 4, "clone should preserve engraved face")

	var rng := RunRng.new(20260726)
	rng.roll_die()
	var checkpoint: int = rng.snapshot_state()
	var expected := [rng.roll_die(), rng.roll_die(), rng.roll_die()]
	rng.restore_state(checkpoint)
	var actual := [rng.roll_die(), rng.roll_die(), rng.roll_die()]
	assert_equal(actual, expected, "restored RNG should replay the same values")

	var report := ResolutionReport.new()
	report.events = [
		ResolutionEvent.new(&"engraving_echo", "没有相邻骰", 0, 0, false),
	]
	assert_true(
		report.event_signature()[0].ends_with("|false"),
		"event signature should include whether the effect applied"
	)
