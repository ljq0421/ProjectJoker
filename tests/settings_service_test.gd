extends "res://tests/test_case.gd"

class FakeDisplayAdapter:
	extends RefCounted

	var runtime := {
		"mode": "windowed",
		"window_size": Vector2i(1280, 720),
		"vsync_enabled": true,
	}
	var resolutions: Array[Vector2i] = [
		Vector2i(1280, 720),
		Vector2i(1600, 900),
		Vector2i(1920, 1080),
	]
	var fail_apply := false
	var fail_restore := false

	func snapshot() -> Dictionary:
		return runtime.duplicate(true)

	func available_resolutions() -> Array[Vector2i]:
		return resolutions.duplicate()

	func apply_settings(settings: Dictionary) -> Dictionary:
		if fail_apply:
			return {"ok": false, "error": "fake apply failure"}
		runtime["mode"] = settings["mode"]
		runtime["window_size"] = Vector2i(
			int(settings["window_width"]),
			int(settings["window_height"])
		)
		runtime["vsync_enabled"] = settings["vsync_enabled"]
		return {"ok": true, "error": ""}

	func restore(snapshot_values: Dictionary) -> Dictionary:
		if fail_restore:
			return {"ok": false, "error": "fake restore failure"}
		runtime = snapshot_values.duplicate(true)
		return {"ok": true, "error": ""}

func run() -> void:
	assert_true(
		ResourceLoader.exists("res://scripts/settings/settings_store.gd"),
		"settings store script should exist"
	)
	assert_true(
		ResourceLoader.exists("res://scripts/settings/display_settings_adapter.gd"),
		"display settings adapter script should exist"
	)
	assert_true(
		ResourceLoader.exists("res://scripts/settings/settings_service.gd"),
		"settings service script should exist"
	)
	if failures.size() > 0:
		return
	_test_store_validation_and_round_trip()
	_test_service_audio_and_display_flow()

func _test_store_validation_and_round_trip() -> void:
	var path := _temporary_path("store")
	_remove_settings_files(path)
	var service_script := load("res://scripts/settings/settings_service.gd")
	var defaults: Dictionary = service_script.new().default_settings()
	var store := SettingsStore.new(path)

	var missing: Dictionary = store.load_settings(defaults)
	assert_equal(
		missing["values"],
		defaults,
		"missing settings should use defaults"
	)
	assert_false(
		bool(missing["parse_failed"]),
		"a missing file is not a parse failure"
	)

	var values := defaults.duplicate(true)
	values["audio"]["ui_linear"] = 0.25
	values["display"]["window_width"] = 1600
	values["display"]["window_height"] = 900
	var save_result: Dictionary = store.save_settings(values)
	assert_true(bool(save_result["ok"]), "valid settings should save")
	var reloaded: Dictionary = store.load_settings(defaults)
	assert_equal(
		reloaded["values"]["audio"]["ui_linear"],
		0.25,
		"saved audio value should reload"
	)
	assert_equal(
		reloaded["values"]["display"]["window_width"],
		1600,
		"saved window width should reload"
	)

	var invalid := ConfigFile.new()
	invalid.set_value("meta", "schema_version", 1)
	invalid.set_value("audio", "master_linear", 2.0)
	invalid.set_value("audio", "ui_linear", 0.33)
	invalid.set_value("display", "window_width", 1111)
	invalid.set_value("display", "window_height", 777)
	assert_equal(invalid.save(path), OK, "invalid fixture should save")
	var validated: Dictionary = store.load_settings(defaults)
	assert_equal(
		validated["values"]["audio"]["master_linear"],
		defaults["audio"]["master_linear"],
		"out-of-range audio should fall back alone"
	)
	assert_true(
		absf(float(validated["values"]["audio"]["ui_linear"]) - 0.33) < 0.0001,
		"valid sibling audio should survive"
	)
	assert_equal(
		validated["values"]["display"]["window_width"],
		1280,
		"unapproved resolution should fall back"
	)

	var corrupt := FileAccess.open(path, FileAccess.WRITE)
	assert_true(corrupt != null, "corrupt fixture should open")
	if corrupt != null:
		corrupt.store_string("[audio")
		corrupt.close()
	var corrupt_before := FileAccess.get_file_as_string(path)
	var corrupt_result: Dictionary = store.load_settings(defaults)
	assert_true(
		bool(corrupt_result["parse_failed"]),
		"unparseable settings should report parse failure"
	)
	assert_equal(
		FileAccess.get_file_as_string(path),
		corrupt_before,
		"loading corrupt settings must not overwrite the source"
	)
	_remove_settings_files(path)

func _test_service_audio_and_display_flow() -> void:
	var path := _temporary_path("service")
	_remove_settings_files(path)
	var store := SettingsStore.new(path)
	var fake_display := FakeDisplayAdapter.new()
	var service_script := load("res://scripts/settings/settings_service.gd")
	var service: Node = service_script.new()
	service.configure_for_test(store, fake_display, 0.05)

	var bus_snapshot := _audio_bus_snapshot()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(service)
	assert_equal(
		service.audio_percent(&"master"),
		100,
		"master default should be 100%"
	)
	assert_equal(
		service.audio_percent(&"ui"),
		50,
		"UI default should reflect -6 dB"
	)
	assert_equal(
		service.audio_percent(&"gameplay"),
		79,
		"gameplay default should reflect -2 dB"
	)

	var previews: Array[StringName] = []
	service.preview_requested.connect(
		func(cue_id: StringName) -> void:
			previews.append(cue_id)
	)
	assert_true(
		service.set_audio_linear(&"ui", 0.25),
		"valid audio adjustment should apply"
	)
	var ui_bus := AudioServer.get_bus_index(&"UI")
	assert_true(
		absf(AudioServer.get_bus_volume_db(ui_bus) - linear_to_db(0.25)) < 0.01,
		"UI bus should receive the adjusted linear value"
	)
	assert_true(
		service.finish_audio_adjustment(&"ui"),
		"finishing audio adjustment should save"
	)
	assert_equal(
		previews,
		[&"ui_confirm"],
		"drag end should request one UI preview"
	)
	assert_true(
		service.set_audio_linear(&"ui", 0.0),
		"zero volume should apply safely"
	)
	assert_true(
		service.set_audio_muted(&"ui", true),
		"explicit mute should save"
	)
	assert_true(
		service.set_audio_muted(&"ui", false),
		"unmute should save"
	)
	assert_true(
		service.audio_linear(&"ui") > 0.0,
		"unmuting zero should restore the last audible value"
	)

	service.begin_display_draft()
	service.set_display_draft_resolution(Vector2i(1600, 900))
	service.set_display_draft_vsync(false)
	assert_equal(
		service.confirmed_display()["window_width"],
		1280,
		"display draft must not mutate confirmed state"
	)
	assert_true(
		service.apply_display_draft(),
		"valid display draft should enter confirmation"
	)
	assert_true(
		service.display_confirmation_active(),
		"display confirmation should become active"
	)
	assert_equal(
		fake_display.runtime["window_size"],
		Vector2i(1600, 900),
		"fake runtime should receive the draft"
	)
	assert_true(
		service.confirm_display_settings(),
		"confirmed display settings should save"
	)
	var saved: Dictionary = store.load_settings(service.default_settings())
	assert_equal(
		saved["values"]["display"]["window_width"],
		1600,
		"only confirmed display values should persist"
	)

	service.begin_display_draft()
	service.set_display_draft_mode("fullscreen")
	assert_true(
		service.apply_display_draft(),
		"fullscreen draft should apply"
	)
	service._process(0.06)
	assert_false(
		service.display_confirmation_active(),
		"timeout should clear display confirmation"
	)
	assert_equal(
		fake_display.runtime["mode"],
		"windowed",
		"timeout should restore the runtime snapshot"
	)

	fake_display.resolutions = [Vector2i(1280, 720)]
	service._apply_confirmed_display_on_startup()
	assert_equal(
		fake_display.runtime["window_size"],
		Vector2i(1280, 720),
		"startup should use the largest fitting window preset"
	)
	assert_equal(
		service.confirmed_display()["window_width"],
		1600,
		"startup fallback must not overwrite the confirmed saved size"
	)

	service.begin_display_draft()
	service.set_display_draft_mode("fullscreen")
	fake_display.fail_apply = true
	assert_false(
		service.apply_display_draft(),
		"adapter failure should reject display apply"
	)
	assert_false(
		service.display_confirmation_active(),
		"failed display apply should not open confirmation"
	)

	service.free()
	_restore_audio_bus_snapshot(bus_snapshot)
	_remove_settings_files(path)

func _audio_bus_snapshot() -> Dictionary:
	var result := {}
	for bus_name in [&"Master", &"UI", &"Gameplay"]:
		var index := AudioServer.get_bus_index(bus_name)
		result[bus_name] = {
			"volume_db": AudioServer.get_bus_volume_db(index),
			"muted": AudioServer.is_bus_mute(index),
		}
	return result

func _restore_audio_bus_snapshot(snapshot: Dictionary) -> void:
	for bus_name in snapshot:
		var index := AudioServer.get_bus_index(bus_name)
		AudioServer.set_bus_volume_db(
			index,
			float(snapshot[bus_name]["volume_db"])
		)
		AudioServer.set_bus_mute(index, bool(snapshot[bus_name]["muted"]))

func _temporary_path(suffix: String) -> String:
	return "%s/project-joker-settings-%s-%d.cfg" % [
		OS.get_temp_dir(),
		suffix,
		Time.get_ticks_usec(),
	]

func _remove_settings_files(path: String) -> void:
	for candidate in [path, "%s.tmp" % path, "%s.bak" % path]:
		var absolute := ProjectSettings.globalize_path(candidate)
		if FileAccess.file_exists(absolute):
			DirAccess.remove_absolute(absolute)
