extends "res://tests/test_case.gd"

const ExpeditionMeta = preload("res://scripts/run/expedition_meta_store.gd")

func run() -> void:
	var path := OS.get_temp_dir().path_join(
		"project-joker-expedition-meta-%d.cfg" % Time.get_ticks_usec()
	)
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(path + ".tmp")
	var store := ExpeditionMeta.new(path)
	var loaded := store.load_snapshot()
	assert_true(loaded.accepted, "missing meta file should load defaults")
	assert_true(not loaded.snapshot["challenges_unlocked"], "challenges should start locked")
	assert_equal(loaded.snapshot["history"], [], "history should start empty")

	assert_true(store.record_run(_record(&"failed-1", &"failed", 100)).accepted, "failure should record")
	loaded = store.load_snapshot()
	assert_true(not loaded.snapshot["challenges_unlocked"], "failure should not unlock challenges")
	assert_equal(loaded.snapshot["history"].size(), 1, "failure should appear in history")

	assert_true(store.record_run(_record(&"complete-1", &"complete", 200)).accepted, "clear should record")
	loaded = store.load_snapshot()
	assert_true(loaded.snapshot["challenges_unlocked"], "first full clear should unlock challenges")
	assert_equal(loaded.snapshot["identity_completions"][&"table_chain"], 1, "identity clear should count")
	for challenge_id in [&"high_pressure", &"no_undo"]:
		assert_equal(
			loaded.snapshot["challenge_completions"][challenge_id],
			1,
			"completed active challenge should count"
		)

	assert_true(store.record_run(_record(&"complete-1", &"complete", 200)).accepted, "duplicate should be idempotent")
	assert_equal(store.load_snapshot().snapshot["history"].size(), 2, "duplicate id should not append")

	for index in range(35):
		assert_true(
			store.record_run(
				_record(StringName("later-%02d" % index), &"failed", 300 + index)
			).accepted,
			"history append should succeed"
		)
	var history: Array = store.load_snapshot().snapshot["history"]
	assert_equal(history.size(), 30, "history should retain the latest thirty runs")
	assert_equal(history[0]["run_id"], &"later-34", "history should be newest first")
	assert_true(
		history.all(func(record: Dictionary) -> bool: return record["run_id"] != &"failed-1"),
		"oldest history should be trimmed"
	)
	assert_true(store.clear().accepted, "meta test file should clean up")

func _record(run_id: StringName, result: StringName, ended_at: int) -> Dictionary:
	return {
		"run_id": run_id,
		"ended_at": ended_at,
		"result": result,
		"seed_value": ended_at + 7,
		"starting_deck_id": &"table_chain",
		"challenge_ids": [&"high_pressure", &"no_undo"],
		"completed_areas": [],
		"route_ids": [],
		"reward_ids": [],
		"final_deck_count": 12,
		"intel_tickets": 0,
		"failure_reason": "test" if result == &"failed" else "",
	}
