extends "res://tests/test_case.gd"

const EXPECTED_VERSION := "0.1.0-demo.1"
const EXPECTED_PRESET := "Windows Demo"
const EXPECTED_EXPORT_PATH := "build/windows/ProjectJokerDemo.exe"

func run() -> void:
	_test_project_version()
	_test_windows_demo_export_preset()
	_test_repeatable_build_entrypoint()
	_test_release_workspace()

func _test_project_version() -> void:
	assert_equal(
		ProjectSettings.get_setting("application/config/version", ""),
		EXPECTED_VERSION,
		"the demo build should expose an explicit semantic version"
	)

func _test_windows_demo_export_preset() -> void:
	var config := ConfigFile.new()
	assert_equal(
		config.load("res://export_presets.cfg"),
		OK,
		"the Windows demo export preset should be readable"
	)
	if not config.has_section("preset.0"):
		assert_true(false, "the Windows demo export preset should exist")
		return
	assert_equal(
		config.get_value("preset.0", "name", ""),
		EXPECTED_PRESET,
		"the release preset name should be stable"
	)
	assert_equal(
		config.get_value("preset.0", "platform", ""),
		"Windows Desktop",
		"the demo should export for Windows Desktop"
	)
	assert_equal(
		config.get_value("preset.0", "export_path", ""),
		EXPECTED_EXPORT_PATH,
		"the release artifact path should be stable"
	)
	assert_true(
		"demo" in String(config.get_value("preset.0", "custom_features", "")),
		"the release preset should expose the demo feature flag"
	)
	var excluded := String(config.get_value("preset.0", "exclude_filter", ""))
	for path in ["build/*", "docs/*", "release/*", "tests/*", "tmp/*", "tools/*"]:
		assert_true(path in excluded, "release export should exclude %s" % path)
	assert_equal(
		config.get_value("preset.0.options", "binary_format/architecture", ""),
		"x86_64",
		"the Windows demo should target 64-bit PCs"
	)
	assert_equal(
		config.get_value("preset.0.options", "application/product_version", ""),
		"0.1.0.1",
		"the Windows product version should match the demo version"
	)

func _test_repeatable_build_entrypoint() -> void:
	assert_true(
		FileAccess.file_exists("res://tools/build_windows_demo.ps1"),
		"a repeatable Windows demo build script should exist"
	)
	assert_true(
		FileAccess.file_exists("res://tools/build_windows_demo.cmd"),
		"a Windows-policy-safe build entrypoint should exist"
	)

func _test_release_workspace() -> void:
	for path in [
		"res://release/steam_demo/release_checklist.md",
		"res://release/steam_demo/store_assets_manifest.json",
		"res://release/steam_demo/playtests/session-template.json",
		"res://tools/capture_steam_demo_screenshots.ps1",
		"res://tools/verify_steam_demo_release.ps1",
		"res://tools/summarize_steam_demo_playtests.ps1",
	]:
		assert_true(FileAccess.file_exists(path), "release workflow should include %s" % path)
