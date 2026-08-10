extends "res://tests/test_case.gd"

const Achievements = preload("res://scripts/run/achievement_catalog.gd")
const StartConfig = preload("res://scripts/run/expedition_start_config.gd")

var _path := ""

func run() -> void:
	_path = OS.get_environment("TEMP").path_join(
		"project-joker-achievements-%d.cfg" % Time.get_ticks_usec()
	)
	_test_catalog_and_mode_isolation()
	_test_v1_meta_migration_backfills_safe_achievements()
	ExpeditionMetaStore.new(_path).clear()

func _test_catalog_and_mode_isolation() -> void:
	assert_equal(Achievements.new().ids().size(), 12, "achievement catalog contains twelve badges")
	var store := ExpeditionMetaStore.new(_path)
	assert_true(store.record_run(_record(&"custom", StartConfig.CUSTOM)).accepted, "custom history records")
	var snapshot := store.load_snapshot().snapshot
	assert_false(snapshot.challenges_unlocked, "custom clear does not unlock standard systems")
	assert_true(snapshot.achievements.values().all(func(value) -> bool: return not value), "custom unlocks no badge")
	assert_true(store.record_run(_record(&"daily", StartConfig.DAILY)).accepted, "daily history records")
	snapshot = store.load_snapshot().snapshot
	assert_true(snapshot.achievements[Achievements.FIRST_DAILY_CLEAR], "daily unlocks daily badge")
	assert_false(snapshot.achievements[Achievements.FIRST_CLEAR], "daily does not unlock standard clear")
	assert_true(store.record_run(_record(&"standard", StartConfig.STANDARD)).accepted, "standard history records")
	snapshot = store.load_snapshot().snapshot
	for achievement_id in [
		Achievements.FIRST_CLEAR,
		Achievements.ZERO_CALIBRATION,
		Achievements.FULL_ALLOCATION_EVERY_ROUND,
		Achievements.CLEAR_DICE_CONTROL,
		Achievements.DOUBLE_CHALLENGE,
		Achievements.ZERO_EMERGENCY,
		Achievements.THREE_STORMS,
		Achievements.FIFTEEN_CARD_CLEAR,
		Achievements.ENGRAVING_SET_CLEAR,
	]:
		assert_true(snapshot.achievements[achievement_id], "standard metric unlocks %s" % achievement_id)
	assert_equal(snapshot.custom_history.size(), 1, "custom history remains separate")
	assert_equal(snapshot.daily_history.size(), 1, "daily history remains separate")
	assert_equal(snapshot.history.size(), 1, "standard history remains separate")

func _test_v1_meta_migration_backfills_safe_achievements() -> void:
	ExpeditionMetaStore.new(_path).clear()
	var legacy := {
		"challenges_unlocked": true,
		"identity_completions": {
			&"dice_control": 1, &"table_chain": 0, &"intel_economy": 0,
		},
		"challenge_completions": {},
		"history": [_record(&"legacy", StartConfig.STANDARD)],
	}
	var config := ConfigFile.new()
	config.set_value("meta", "format_version", 1)
	config.set_value("progress", "snapshot", legacy)
	assert_equal(config.save(ProjectSettings.globalize_path(_path)), OK, "legacy meta writes")
	var loaded := ExpeditionMetaStore.new(_path).load_snapshot()
	assert_true(loaded.accepted, "meta v1 migrates")
	assert_true(loaded.snapshot.achievements[Achievements.FIRST_CLEAR], "migration backfills first clear")
	assert_true(loaded.snapshot.achievements[Achievements.CLEAR_DICE_CONTROL], "migration backfills deck badge")
	assert_false(loaded.snapshot.achievements[Achievements.ZERO_CALIBRATION], "unsafe metrics stay locked")

func _record(run_id: StringName, mode: StringName) -> Dictionary:
	return {
		"run_id": run_id,
		"ended_at": 100,
		"result": &"complete",
		"mode": mode,
		"seed_value": 42,
		"starting_deck_id": &"dice_control",
		"challenge_ids": [&"high_pressure", &"no_undo"],
		"completed_areas": [&"gold_corridor", &"mirror_hall", &"faceless_hub"],
		"route_ids": [],
		"reward_ids": [],
		"final_deck_count": 15,
		"intel_tickets": 0,
		"failure_reason": "",
		"zero_calibration": true,
		"full_allocation_every_round": true,
		"emergency_spend": 0,
		"storm_count": 3,
		"engraving_set_activations": 1,
	}
