extends "res://tests/test_case.gd"

const StoreScript = preload("res://scripts/ui/tutorial/tutorial_progress_store.gd")

func run() -> void:
	var path := OS.get_temp_dir().path_join(
		"project-joker-onboarding-store-%d.cfg" % Time.get_ticks_usec()
	)
	DirAccess.remove_absolute(path)

	var first = StoreScript.new(path)
	assert_false(first.is_done(), "missing onboarding config should default to not done")
	assert_equal(first.mark_done(), OK, "mark_done should save successfully")
	assert_true(StoreScript.new(path).is_done(), "done state should persist across instances")
	assert_equal(first.reset(), OK, "reset should save successfully")
	assert_false(StoreScript.new(path).is_done(), "reset should persist not-done state")

	DirAccess.remove_absolute(path)
