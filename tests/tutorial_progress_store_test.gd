extends "res://tests/test_case.gd"

const StoreScript = preload("res://scripts/ui/tutorial/tutorial_progress_store.gd")

func run() -> void:
	var path := OS.get_temp_dir().path_join(
		"project-joker-onboarding-store-%d.cfg" % Time.get_ticks_usec()
	)
	DirAccess.remove_absolute(path)

	var seeded_config := ConfigFile.new()
	seeded_config.set_value("foreign_section", "preserved_value", 73)
	assert_equal(seeded_config.save(path), OK, "fixture config should save")

	var first = StoreScript.new(path)
	assert_false(first.is_done(), "missing onboarding section should default to not done")
	assert_equal(first.mark_done(), OK, "mark_done should save successfully")
	assert_true(StoreScript.new(path).is_done(), "done state should persist across instances")
	var after_mark := ConfigFile.new()
	assert_equal(after_mark.load(path), OK, "marked config should remain readable")
	assert_equal(
		after_mark.get_value("foreign_section", "preserved_value", 0),
		73,
		"mark_done should preserve foreign config sections"
	)
	assert_equal(first.reset(), OK, "reset should save successfully")
	assert_false(StoreScript.new(path).is_done(), "reset should persist not-done state")
	var after_reset := ConfigFile.new()
	assert_equal(after_reset.load(path), OK, "reset config should remain readable")
	assert_equal(
		after_reset.get_value("foreign_section", "preserved_value", 0),
		73,
		"reset should preserve foreign config sections"
	)

	DirAccess.remove_absolute(path)
