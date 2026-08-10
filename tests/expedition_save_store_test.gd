extends "res://tests/test_case.gd"

var _base_path := ""

func run() -> void:
	_base_path = OS.get_environment("TEMP").path_join(
		"project-joker-expedition-save-test-%d.cfg" % Time.get_ticks_usec()
	)
	_test_round_trip_and_clear()
	_test_v1_snapshot_migrates_without_changing_legacy_deck()
	_test_v2_snapshot_migrates_to_safe_phase_two_defaults()
	_test_corrupt_file_is_preserved()
	_cleanup()

func _test_round_trip_and_clear() -> void:
	var store := ExpeditionSaveStore.new(_base_path)
	var expedition := ExpeditionSession.new()
	expedition.start_new(20260729)
	assert_true(store.save(expedition.to_snapshot()).accepted, "valid save writes")
	assert_true(store.has_save(), "save should exist")
	var loaded := store.load_snapshot()
	assert_true(loaded.accepted, "valid save loads")
	assert_equal(loaded.snapshot, expedition.to_snapshot(), "save round trip is exact")
	assert_true(store.clear().accepted, "save should clear")
	assert_false(store.has_save(), "cleared save is absent")

func _test_corrupt_file_is_preserved() -> void:
	var absolute := ProjectSettings.globalize_path(_base_path)
	var file := FileAccess.open(absolute, FileAccess.WRITE)
	file.store_string("[broken")
	file.close()
	var store := ExpeditionSaveStore.new(_base_path)
	var loaded := store.load_snapshot()
	assert_false(loaded.accepted, "corrupt save should reject")
	assert_true(FileAccess.file_exists(absolute), "corrupt original must remain")
	assert_true(store.archive_corrupt().accepted, "explicit archive should succeed")
	assert_false(store.has_save(), "archived corrupt save leaves formal path free")

func _test_v1_snapshot_migrates_without_changing_legacy_deck() -> void:
	var expedition := ExpeditionSession.new()
	expedition.start_new(20260730)
	var legacy := expedition.to_snapshot()
	legacy.erase("run_id")
	legacy.erase("starting_deck_id")
	legacy.erase("challenge_ids")
	legacy["inherited_state"] = {}
	var config := ConfigFile.new()
	config.set_value("meta", "format_version", 1)
	config.set_value("meta", "content_version", 1)
	config.set_value("run", "snapshot", legacy)
	assert_equal(
		config.save(ProjectSettings.globalize_path(_base_path)),
		OK,
		"legacy fixture should write"
	)
	var loaded := ExpeditionSaveStore.new(_base_path).load_snapshot()
	assert_true(loaded.accepted, "v1 save should migrate")
	assert_equal(
		loaded.snapshot.get("starting_deck_id"),
		&"dice_control",
		"legacy save should receive the compatibility identity"
	)
	assert_equal(loaded.snapshot.get("challenge_ids"), [], "legacy save should have no challenges")
	assert_equal(
		loaded.snapshot.get("inherited_state", {}).get("deck_ids"),
		AreaCatalog.new().gold_corridor().starting_deck_ids,
		"migration should preserve the old starting deck"
	)
	ExpeditionSaveStore.new(_base_path).clear()

func _test_v2_snapshot_migrates_to_safe_phase_two_defaults() -> void:
	var expedition := ExpeditionSession.new()
	expedition.start_new(20260731)
	var legacy := expedition.to_snapshot()
	var config := ConfigFile.new()
	config.set_value("meta", "format_version", 2)
	config.set_value("meta", "content_version", 1)
	config.set_value("run", "snapshot", legacy)
	assert_equal(
		config.save(ProjectSettings.globalize_path(_base_path)),
		OK,
		"v2 fixture should write"
	)
	var loaded := ExpeditionSaveStore.new(_base_path).load_snapshot()
	assert_true(loaded.accepted, "v2 save should migrate")
	assert_equal(
		loaded.snapshot.get("area_checkpoint", {}).get("event_history", []),
		[],
		"v2 save receives empty event history"
	)
	ExpeditionSaveStore.new(_base_path).clear()

func _cleanup() -> void:
	for suffix in ["", ".tmp", ".bak"]:
		var path := ProjectSettings.globalize_path(_base_path + suffix)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	var directory := DirAccess.open(_base_path.get_base_dir())
	if directory != null:
		var prefix := _base_path.get_file() + ".corrupt-"
		for file_name in directory.get_files():
			if file_name.begins_with(prefix):
				DirAccess.remove_absolute(
					_base_path.get_base_dir().path_join(file_name)
				)
