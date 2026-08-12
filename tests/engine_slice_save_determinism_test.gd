extends "res://tests/test_case.gd"

const Session = preload("res://scripts/engine_slice/engine_slice_run_session.gd")
const Catalog = preload("res://scripts/engine_slice/engine_slice_catalog.gd")
const Store = preload("res://scripts/engine_slice/engine_slice_save_store.gd")

var _path := ""

func run() -> void:
	_path = OS.get_environment("TEMP").path_join("project-joker-engine-slice-%d.cfg" % Time.get_ticks_usec())
	var original = Session.new()
	assert_true(original.start_new(20260811, Catalog.DICE_CONTROL).accepted, "seeded slice should start")
	assert_true(original.choose_route(&"gold_precise_steps").accepted, "first route should enter battle")
	var store = Store.new(_path)
	assert_true(store.save_snapshot(original.to_snapshot()).accepted, "versioned engine save should write")
	var loaded: Dictionary = store.load_snapshot()
	assert_true(loaded.get("ok", false), "versioned engine save should load")
	var resumed = Session.new()
	assert_true(resumed.restore_snapshot(loaded["snapshot"]).accepted, "saved battle should restore")
	_assert_turn_equal(original, resumed, "restored submitted boundary")
	original.commit_turn()
	resumed.commit_turn()
	assert_true(original.start_next_turn().accepted, "original should advance deterministically")
	assert_true(resumed.start_next_turn().accepted, "resumed should advance deterministically")
	_assert_turn_equal(original, resumed, "next dice, tactics and intent should match after resume")
	assert_true(store.clear_save().accepted, "slice save should clear independently")
	assert_false(store.has_save(), "cleared slice save should be absent")
	_test_v1_migration(store, original.to_snapshot())

func _test_v1_migration(store, snapshot: Dictionary) -> void:
	var legacy := snapshot.duplicate(true)
	for key in ["activated_technique_counts", "die_technique_marks", "engine_charge", "carried_block", "next_retained_block", "counter_percent"]:
		legacy["battle"].erase(key)
	var config := ConfigFile.new()
	config.set_value("meta", "format_version", 1)
	config.set_value("run", "snapshot", legacy)
	assert_equal(config.save(_path), OK, "legacy fixture should write")
	var loaded: Dictionary = store.load_snapshot()
	assert_true(loaded.get("ok", false), "v1 save should migrate")
	var battle: Dictionary = loaded["snapshot"]["battle"]
	assert_true(battle.has("die_technique_marks"), "migration should add die marks")
	assert_equal(int(battle.get("engine_charge", -1)), 0, "migration should initialize encounter charge")
	assert_equal(int(loaded["snapshot"].get("seed_value", 0)), int(snapshot["seed_value"]), "migration should preserve seed")
	store.clear_save()

func _assert_turn_equal(left, right, message: String) -> void:
	assert_equal(
		left.battle.state.dice.map(func(die): return die.value),
		right.battle.state.dice.map(func(die): return die.value),
		message + " dice"
	)
	assert_equal(left.battle.state.tactic_hand, right.battle.state.tactic_hand, message + " tactics")
	assert_equal(left.current_intent_id, right.current_intent_id, message + " intent")
	assert_equal(left.rng.snapshot_state(), right.rng.snapshot_state(), message + " RNG state")
