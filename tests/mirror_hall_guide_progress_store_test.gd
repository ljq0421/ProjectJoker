extends "res://tests/test_case.gd"

func run() -> void:
	var path := "%s/project-joker-mirror-guide-%d.cfg" % [
		OS.get_temp_dir(),
		Time.get_ticks_usec(),
	]
	var config := ConfigFile.new()
	config.set_value("onboarding", "completed", true)
	config.set_value("iron_abacus_guide_v1", "seen_dealer", true)
	config.set_value("gold_corridor_guide_v1", "seen_route", true)
	config.set_value("mirror_hall_guide_v1", "seen_direction", true)
	config.set_value("mirror_hall_guide_v1", "seen_mirror", true)
	config.set_value("mirror_hall_guide_v1", "seen_dealer", true)
	config.set_value("mirror_hall_guide_v1", "dismissed", true)
	assert_equal(config.save(path), OK, "fixture config should save")

	var store := MirrorHallGuideProgressStore.new(path)
	assert_true(store.is_seen(&"direction"), "fixture should load direction")
	assert_true(store.is_dismissed(), "fixture should load dismissed")
	assert_equal(store.reset(), OK, "reset should persist")
	var snapshot := store.snapshot()
	assert_false(snapshot.seen_direction, "reset clears direction only")
	assert_false(snapshot.seen_mirror, "reset clears mirror only")
	assert_false(snapshot.seen_dealer, "reset clears dealer only")
	assert_false(snapshot.dismissed, "reset clears mirror dismissal")

	var reloaded := ConfigFile.new()
	assert_equal(reloaded.load(path), OK, "reset file should reload")
	assert_true(reloaded.get_value("onboarding", "completed"), "onboarding is isolated")
	assert_true(
		reloaded.get_value("iron_abacus_guide_v1", "seen_dealer"),
		"Iron Abacus guide is isolated"
	)
	assert_true(
		reloaded.get_value("gold_corridor_guide_v1", "seen_route"),
		"Gold Corridor guide is isolated"
	)
	assert_equal(store.mark_seen(&"mirror"), OK, "known checkpoint should persist")
	assert_true(store.is_seen(&"mirror"), "seen mirror should update")
	assert_equal(store.dismiss_all(), OK, "dismiss should persist")
	assert_true(store.is_dismissed(), "dismiss state should update")
	assert_equal(store.mark_seen(&"missing"), ERR_INVALID_PARAMETER, "unknown ID rejects")
	DirAccess.remove_absolute(path)
