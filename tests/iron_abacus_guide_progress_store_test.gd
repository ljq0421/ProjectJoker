extends "res://tests/test_case.gd"

const StoreScript = preload(
	"res://scripts/ui/tutorial/iron_abacus_guide_progress_store.gd"
)

const CHECKPOINTS: Array[StringName] = [
	&"normal",
	&"shop",
	&"dealer",
	&"reward",
	&"verification",
]

func run() -> void:
	_test_missing_file_and_all_checkpoint_round_trip()
	_test_dismiss_reset_and_section_preservation()
	_test_unknown_checkpoint_is_rejected()
	_test_corrupt_file_is_not_overwritten()

func _test_missing_file_and_all_checkpoint_round_trip() -> void:
	var path := _temp_path("round-trip")
	DirAccess.remove_absolute(path)

	var first = StoreScript.new(path)
	assert_equal(first.initial_load_error(), OK, "missing config should be a valid initial state")
	assert_false(first.is_dismissed(), "missing config should not dismiss guide")
	for checkpoint_id in CHECKPOINTS:
		assert_false(first.is_seen(checkpoint_id), "missing config should leave checkpoint unseen")
		assert_equal(first.mark_seen(checkpoint_id), OK, "checkpoint should save")
		assert_true(first.is_seen(checkpoint_id), "memory should update after mark_seen")

	var reloaded = StoreScript.new(path)
	assert_equal(reloaded.initial_load_error(), OK, "saved config should reload cleanly")
	for checkpoint_id in CHECKPOINTS:
		assert_true(reloaded.is_seen(checkpoint_id), "saved checkpoint should persist")

	DirAccess.remove_absolute(path)

func _test_dismiss_reset_and_section_preservation() -> void:
	var path := _temp_path("preservation")
	DirAccess.remove_absolute(path)
	var seeded := ConfigFile.new()
	seeded.set_value("onboarding", "done", true)
	seeded.set_value("foreign_section", "value", "keep")
	assert_equal(seeded.save(path), OK, "preservation fixture should save")

	var store = StoreScript.new(path)
	assert_equal(store.dismiss_all(), OK, "dismiss_all should save")
	assert_true(store.is_dismissed(), "dismiss_all should update memory")
	var dismissed_config := ConfigFile.new()
	assert_equal(dismissed_config.load(path), OK, "dismissed config should reload")
	assert_true(
		bool(dismissed_config.get_value("onboarding", "done", false)),
		"advanced store should preserve base tutorial state"
	)
	assert_equal(
		dismissed_config.get_value("foreign_section", "value", ""),
		"keep",
		"advanced store should preserve foreign sections"
	)

	assert_equal(store.mark_seen(&"dealer"), OK, "seen state should save while dismissed")
	assert_equal(store.reset(), OK, "reset should save")
	assert_false(store.is_dismissed(), "reset should clear dismissed")
	for checkpoint_id in CHECKPOINTS:
		assert_false(store.is_seen(checkpoint_id), "reset should clear every checkpoint")
	var reset_config := ConfigFile.new()
	assert_equal(reset_config.load(path), OK, "reset config should reload")
	assert_true(
		bool(reset_config.get_value("onboarding", "done", false)),
		"reset should preserve base tutorial state"
	)
	assert_equal(
		reset_config.get_value("foreign_section", "value", ""),
		"keep",
		"reset should preserve foreign sections"
	)

	DirAccess.remove_absolute(path)

func _test_unknown_checkpoint_is_rejected() -> void:
	var path := _temp_path("unknown")
	DirAccess.remove_absolute(path)
	var store = StoreScript.new(path)
	var before: Dictionary = store.snapshot()
	assert_equal(
		store.mark_seen(&"unknown"),
		ERR_INVALID_PARAMETER,
		"unknown checkpoint should be rejected"
	)
	assert_equal(store.snapshot(), before, "unknown checkpoint should not mutate memory")
	assert_false(FileAccess.file_exists(path), "unknown checkpoint should not create a config")
	DirAccess.remove_absolute(path)

func _test_corrupt_file_is_not_overwritten() -> void:
	var path := _temp_path("corrupt")
	DirAccess.remove_absolute(path)
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert_true(file != null, "corrupt fixture should open")
	if file == null:
		return
	file.store_string("[broken\nvalue")
	file.close()
	var original := FileAccess.get_file_as_string(path)

	var store = StoreScript.new(path)
	assert_true(store.initial_load_error() != OK, "corrupt config should report a load error")
	assert_false(store.is_seen(&"normal"), "corrupt config should use unseen memory defaults")
	assert_true(store.mark_seen(&"normal") != OK, "corrupt config should refuse overwrite")
	assert_true(store.is_seen(&"normal"), "failed save should retain the in-memory decision")
	assert_equal(
		FileAccess.get_file_as_string(path),
		original,
		"corrupt config should remain byte-for-byte unchanged"
	)

	DirAccess.remove_absolute(path)

func _temp_path(label: String) -> String:
	return OS.get_temp_dir().path_join(
		"project-joker-advanced-guide-%s-%d.cfg" % [label, Time.get_ticks_usec()]
	)
