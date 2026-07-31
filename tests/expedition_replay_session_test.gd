extends "res://tests/test_case.gd"

const ExpeditionConfigs = preload("res://scripts/run/expedition_config_catalog.gd")

func run() -> void:
	var configs := ExpeditionConfigs.new()
	var session := ExpeditionSession.new()
	var started := session.start_new(
		246810,
		&"table_chain",
		[&"high_pressure", &"no_undo"]
	)
	assert_true(started.accepted, "configured expedition should start")
	assert_equal(session.starting_deck_id, &"table_chain", "session should retain deck preset")
	assert_equal(
		session.challenge_ids,
		[&"high_pressure", &"no_undo"],
		"session should retain public challenges"
	)
	assert_true(not session.run_id.is_empty(), "session should assign a run id")

	var entry := session.current_entry_state()
	assert_equal(
		entry.get("deck_ids"),
		configs.find_deck(&"table_chain")["card_ids"],
		"first area should receive the selected starting deck"
	)
	assert_equal(
		entry.get("challenge_ids"),
		[&"high_pressure", &"no_undo"],
		"first area should receive challenge ids"
	)

	var snapshot := session.to_snapshot()
	assert_equal(snapshot.get("starting_deck_id"), &"table_chain", "snapshot should retain deck")
	assert_equal(snapshot.get("challenge_ids", []).size(), 2, "snapshot should retain challenges")
	assert_equal(snapshot.get("run_id"), session.run_id, "snapshot should retain run id")

	var restored := ExpeditionSession.new()
	var restored_result := restored.restore_snapshot(snapshot)
	assert_true(restored_result.accepted, "configured snapshot should restore")
	assert_equal(restored.to_snapshot(), snapshot, "restored configuration should not drift")

	var invalid := ExpeditionSession.new().start_new(
		13579,
		&"dice_control",
		[&"high_pressure", &"short_hand", &"no_undo"]
	)
	assert_true(not invalid.accepted, "session should reject more than two challenges")

	var malformed := snapshot.duplicate(true)
	malformed["challenge_ids"] = "high_pressure"
	assert_true(
		not ExpeditionSession.snapshot_error(malformed).is_empty(),
		"snapshot validation should reject a non-array challenge list"
	)

	malformed = snapshot.duplicate(true)
	malformed["starting_deck_id"] = {"bad": "shape"}
	assert_true(
		not ExpeditionSession.snapshot_error(malformed).is_empty(),
		"snapshot validation should reject a non-string deck id"
	)
