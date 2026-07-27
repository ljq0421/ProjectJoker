extends "res://tests/test_case.gd"

func run() -> void:
	_test_isolated_round_trip()
	_test_corrupt_file_is_preserved()

func _test_isolated_round_trip() -> void:
	var path := "%s/project-joker-faceless-guide-%d.cfg" % [
		OS.get_temp_dir(),
		Time.get_ticks_usec(),
	]
	var config := ConfigFile.new()
	config.set_value("onboarding", "completed", true)
	config.set_value("mirror_hall_guide_v1", "seen_dealer", true)
	config.set_value("faceless_hub_guide_v1", "seen_composite", true)
	config.set_value("faceless_hub_guide_v1", "seen_schedule", true)
	config.set_value("faceless_hub_guide_v1", "seen_restriction", true)
	config.set_value("faceless_hub_guide_v1", "dismissed", true)
	assert_equal(config.save(path), OK, "fixture config should save")

	var store := FacelessHubGuideProgressStore.new(path)
	assert_true(store.is_seen(&"composite"), "fixture should load composite")
	assert_true(store.is_dismissed(), "fixture should load dismissed")
	assert_equal(store.reset(), OK, "reset should persist")
	var snapshot := store.snapshot()
	assert_false(snapshot.seen_composite, "reset clears composite")
	assert_false(snapshot.seen_schedule, "reset clears schedule")
	assert_false(snapshot.seen_restriction, "reset clears restriction")
	assert_false(snapshot.dismissed, "reset clears faceless dismissal")

	var reloaded := ConfigFile.new()
	assert_equal(reloaded.load(path), OK, "reset file should reload")
	assert_true(reloaded.get_value("onboarding", "completed"), "onboarding is isolated")
	assert_true(
		reloaded.get_value("mirror_hall_guide_v1", "seen_dealer"),
		"mirror guide is isolated"
	)
	assert_equal(store.mark_seen(&"schedule"), OK, "known checkpoint persists")
	assert_true(store.is_seen(&"schedule"), "seen state should update")
	assert_equal(store.dismiss_all(), OK, "dismiss should persist")
	assert_true(store.is_dismissed(), "dismiss state should update")
	assert_equal(
		store.mark_seen(&"missing"),
		ERR_INVALID_PARAMETER,
		"unknown checkpoint should reject"
	)
	DirAccess.remove_absolute(path)

func _test_corrupt_file_is_preserved() -> void:
	var path := "%s/project-joker-faceless-guide-corrupt-%d.cfg" % [
		OS.get_temp_dir(),
		Time.get_ticks_usec(),
	]
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("[faceless_hub_guide_v1")
	file.close()
	var before := FileAccess.get_file_as_string(path)
	var store := FacelessHubGuideProgressStore.new(path)
	assert_true(store.initial_load_error() != OK, "corrupt config reports load error")
	assert_true(
		store.mark_seen(&"composite") != OK,
		"writes stay blocked after corrupt load"
	)
	assert_equal(
		FileAccess.get_file_as_string(path),
		before,
		"corrupt source text must not be overwritten"
	)
	DirAccess.remove_absolute(path)
