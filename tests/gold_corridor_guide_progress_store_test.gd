extends "res://tests/test_case.gd"

const StoreScript = preload(
	"res://scripts/ui/tutorial/gold_corridor_guide_progress_store.gd"
)

const CHECKPOINTS: Array[StringName] = [
	&"route",
	&"shop",
	&"dealer",
	&"engraving",
]

func run() -> void:
	_test_missing_file_and_round_trip()
	_test_section_preservation_and_reset()
	_test_dismiss_does_not_forge_seen()
	_test_unknown_checkpoint_is_atomic()
	_test_corrupt_file_is_not_overwritten()
	_test_write_failure_retains_memory()

func _test_missing_file_and_round_trip() -> void:
	var path := _temp_path("round-trip")
	DirAccess.remove_absolute(path)
	var first = StoreScript.new(path)
	assert_equal(first.initial_load_error(), OK, "missing file should load")
	assert_false(first.is_dismissed(), "fresh guide should not be dismissed")
	for checkpoint_id in CHECKPOINTS:
		assert_false(first.is_seen(checkpoint_id), "checkpoint should begin unseen")
		assert_equal(first.mark_seen(checkpoint_id), OK, "checkpoint should save")
		assert_true(first.is_seen(checkpoint_id), "memory should update")
	var reloaded = StoreScript.new(path)
	for checkpoint_id in CHECKPOINTS:
		assert_true(reloaded.is_seen(checkpoint_id), "seen state should reload")
	DirAccess.remove_absolute(path)

func _test_section_preservation_and_reset() -> void:
	var path := _temp_path("preserve")
	DirAccess.remove_absolute(path)
	var seeded := ConfigFile.new()
	seeded.set_value("onboarding", "done", true)
	seeded.set_value("iron_abacus_guide_v1", "seen_shop", true)
	seeded.set_value("foreign_section", "value", "keep")
	assert_equal(seeded.save(path), OK, "fixture config should save")

	var store = StoreScript.new(path)
	assert_equal(store.mark_seen(&"route"), OK, "route should save")
	assert_equal(store.dismiss_all(), OK, "dismiss should save")
	assert_equal(store.reset(), OK, "reset should save")

	var reloaded := ConfigFile.new()
	assert_equal(reloaded.load(path), OK, "saved config should reload")
	assert_true(bool(reloaded.get_value("onboarding", "done", false)), "base tutorial section should survive")
	assert_true(bool(reloaded.get_value("iron_abacus_guide_v1", "seen_shop", false)), "old guide section should survive")
	assert_equal(reloaded.get_value("foreign_section", "value", ""), "keep", "foreign section should survive")
	for checkpoint_id in CHECKPOINTS:
		assert_false(store.is_seen(checkpoint_id), "reset should clear seen")
	assert_false(store.is_dismissed(), "reset should clear dismissed")
	DirAccess.remove_absolute(path)

func _test_dismiss_does_not_forge_seen() -> void:
	var path := _temp_path("dismiss")
	DirAccess.remove_absolute(path)
	var store = StoreScript.new(path)
	assert_equal(store.dismiss_all(), OK, "dismiss should save")
	assert_true(store.is_dismissed(), "dismiss should update memory")
	for checkpoint_id in CHECKPOINTS:
		assert_false(store.is_seen(checkpoint_id), "dismiss should not forge checkpoint history")
	DirAccess.remove_absolute(path)

func _test_unknown_checkpoint_is_atomic() -> void:
	var path := _temp_path("unknown")
	DirAccess.remove_absolute(path)
	var store = StoreScript.new(path)
	var before: Dictionary = store.snapshot()
	assert_equal(store.mark_seen(&"unknown"), ERR_INVALID_PARAMETER, "unknown checkpoint should be rejected")
	assert_equal(store.snapshot(), before, "unknown checkpoint must be atomic")
	assert_false(FileAccess.file_exists(path), "unknown ID should not create file")

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
	assert_true(store.initial_load_error() != OK, "corruption should report")
	assert_true(store.mark_seen(&"route") != OK, "corrupt file should block save")
	assert_true(store.is_seen(&"route"), "failed save should retain memory")
	assert_equal(FileAccess.get_file_as_string(path), original, "corrupt bytes must remain unchanged")
	DirAccess.remove_absolute(path)

func _test_write_failure_retains_memory() -> void:
	var missing_parent := OS.get_temp_dir().path_join("project-joker-missing-guide-dir-%d" % Time.get_ticks_usec())
	var path := missing_parent.path_join("onboarding.cfg")
	var store = StoreScript.new(path)
	assert_true(store.mark_seen(&"dealer") != OK, "write should fail")
	assert_true(store.is_seen(&"dealer"), "failed write should retain memory")
	assert_false(FileAccess.file_exists(path), "failed write should create nothing")

func _temp_path(label: String) -> String:
	return OS.get_temp_dir().path_join("project-joker-gold-guide-%s-%d.cfg" % [label, Time.get_ticks_usec()])
