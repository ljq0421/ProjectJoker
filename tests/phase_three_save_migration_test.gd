extends "res://tests/test_case.gd"

var _path := ""

func run() -> void:
	_path = OS.get_environment("TEMP").path_join(
		"project-joker-phase3-save-%d.cfg" % Time.get_ticks_usec()
	)
	_test_format_three_content_two_migrates_to_standard_config()
	ExpeditionSaveStore.new(_path).clear()

func _test_format_three_content_two_migrates_to_standard_config() -> void:
	var session := ExpeditionSession.new()
	assert_true(session.start_new(20260810, &"table_chain", [&"high_pressure"]).accepted, "fixture starts")
	var legacy := session.to_snapshot()
	legacy.erase("start_config")
	legacy.erase("started_at_unix")
	var config := ConfigFile.new()
	config.set_value("meta", "format_version", 3)
	config.set_value("meta", "content_version", 2)
	config.set_value("run", "snapshot", legacy)
	assert_equal(config.save(ProjectSettings.globalize_path(_path)), OK, "format three fixture writes")
	var loaded := ExpeditionSaveStore.new(_path).load_snapshot()
	assert_true(loaded.accepted, "format three save migrates")
	assert_equal(loaded.snapshot.start_config.mode, &"standard", "legacy defaults to standard mode")
	assert_equal(
		loaded.snapshot.start_config.area_sequence,
		ExpeditionSession.AREA_ORDER,
		"legacy receives fixed three-area sequence"
	)
	assert_equal(loaded.snapshot.start_config.area_modifier_ids, {}, "legacy keeps seeded single modifiers")
	assert_equal(loaded.snapshot.start_config.target_multiplier, 1.0, "legacy target multiplier is safe")
	assert_true(loaded.snapshot.started_at_unix > 0, "legacy receives a safe start time")
