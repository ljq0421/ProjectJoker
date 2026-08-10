extends "res://tests/test_case.gd"

func run() -> void:
	_test_active_round_round_trips_without_rng_or_undo_drift()

func _test_active_round_round_trips_without_rng_or_undo_drift() -> void:
	var original := AreaRunSession.new(772211, AreaCatalog.new().gold_corridor())
	assert_true(original.start().accepted, "save fixture area starts")
	original.intel_tickets = 8
	assert_true(
		original.select_route(original.current_route_ids()[0]).accepted,
		"save fixture enters room"
	)
	var controller := original.encounter_session.current_session.controller
	var first_rule: RuleDefinition = controller.encounter.rules[0]
	assert_true(
		controller.assign_die(&"d1", first_rule.id, controller.effective_slot_count(first_rule.id)).accepted,
		"fixture placement should record history"
	)
	var d2 := controller.state.find_die(&"d2")
	var delta := -1 if d2.value > 1 else 1
	assert_true(controller.adjust_die(&"d2", delta).accepted, "fixture calibration applies")
	assert_true(controller.undo(), "fixture consumes calibration undo")
	assert_true(original.emergency_add_calibration().accepted, "paid calibration checkpoints")
	var preview_before := controller.preview().event_signature()
	var checkpoint := original.checkpoint_snapshot()
	assert_equal(checkpoint["phase"], AreaRunSession.Phase.NORMAL_ROOM, "save stays mid-round")
	assert_true(checkpoint.has("active_encounter"), "mid-round save contains active encounter")

	var restored := AreaRunSession.new(772211, AreaCatalog.new().gold_corridor())
	assert_true(restored.restore_checkpoint(checkpoint).accepted, "mid-round checkpoint restores")
	var restored_controller := restored.encounter_session.current_session.controller
	assert_equal(
		RunSnapshotCodec.round_state_to_snapshot(restored_controller.state),
		RunSnapshotCodec.round_state_to_snapshot(controller.state),
		"dice, assignments, cards and calibration should round-trip"
	)
	assert_equal(
		restored.encounter_session.current_hand_ids,
		original.encounter_session.current_hand_ids,
		"hand should round-trip"
	)
	assert_equal(restored_controller.preview().event_signature(), preview_before, "preview signature is stable")
	assert_equal(
		restored_controller.calibration_undos_remaining(),
		controller.calibration_undos_remaining(),
		"used split undo quota should round-trip"
	)
	assert_equal(restored.intel_tickets, original.intel_tickets, "paid intel spend should round-trip")
	assert_false(
		restored.emergency_add_calibration().accepted,
		"used paid calibration must remain used"
	)
	assert_true(original.emergency_reroll(&"d1").accepted, "original future reroll succeeds")
	assert_true(restored.emergency_reroll(&"d1").accepted, "restored future reroll succeeds")
	assert_equal(
		restored_controller.state.find_die(&"d1").rolled_value,
		controller.state.find_die(&"d1").rolled_value,
		"shared RNG continuation should be identical"
	)
