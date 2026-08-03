extends "res://tests/test_case.gd"

const SETTINGS_SCENE_PATH := "res://scenes/components/settings_layer.tscn"
const HOST_SCENES := [
	"res://scenes/run/main_menu_screen.tscn",
	"res://scenes/run/expedition_setup_screen.tscn",
	"res://scenes/run/expedition_run_screen.tscn",
	"res://scenes/run/single_encounter_screen.tscn",
	"res://scenes/run/three_round_run_screen.tscn",
	"res://scenes/run/area_run_screen.tscn",
	"res://scenes/run/iron_abacus_slice_screen.tscn",
	"res://scenes/shop/shop_screen.tscn",
]

func run() -> void:
	_test_settings_scene_contract()
	_test_host_scene_contract()
	_test_nested_host_has_one_active_entry()
	_test_exclusive_guides_block_the_entry()
	_test_ui_script_boundary()

func _test_settings_scene_contract() -> void:
	var scene := load(SETTINGS_SCENE_PATH)
	assert_true(scene != null, "settings layer scene should load")
	if scene == null:
		return
	var layer: CanvasLayer = scene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(layer)

	var settings_button: Button = layer.get_node("%SettingsButton")
	var rule_reference_button: Button = layer.get_node("%RuleReferenceButton")
	assert_equal(
		rule_reference_button.text,
		"规则手册",
		"the in-game entry should use the same handbook term as the main menu"
	)
	assert_equal(
		settings_button.custom_minimum_size,
		Vector2(96, 48),
		"settings entry should use the approved 96x48 slot"
	)
	assert_equal(
		settings_button.anchor_left,
		1.0,
		"settings entry should anchor to the right"
	)
	assert_equal(
		settings_button.offset_right,
		-24.0,
		"settings entry should retain the right safe margin"
	)
	assert_equal(
		rule_reference_button.custom_minimum_size,
		Vector2(96, 48),
		"rule reference entry should match the settings slot"
	)
	assert_equal(
		rule_reference_button.offset_right,
		-128.0,
		"rule reference entry should sit beside settings with an eight pixel gap"
	)
	assert_true(
		layer.has_method("open_rule_reference"),
		"shared utility layer should open the rule reference overlay"
	)
	assert_true(
		layer.has_method("close_rule_reference"),
		"shared utility layer should close the rule reference overlay"
	)
	assert_true(
		layer.get_node_or_null("%RuleReferenceOverlay") != null,
		"shared utility layer should own the rule reference overlay"
	)
	var overlay: Control = layer.get_node("%SettingsOverlay")
	assert_equal(
		overlay.mouse_filter,
		Control.MOUSE_FILTER_STOP,
		"open overlay should stop underlying pointer input"
	)
	for node_name in [
		"AudioTabButton",
		"DisplayTabButton",
		"AccessibilityTabButton",
		"AudioPage",
		"DisplayPage",
		"AccessibilityPage",
		"MasterSlider",
		"MusicSlider",
		"UiSlider",
		"GameplaySlider",
		"MasterValueLabel",
		"MusicValueLabel",
		"UiValueLabel",
		"GameplayValueLabel",
		"MasterMuteCheck",
		"MusicMuteCheck",
		"UiMuteCheck",
		"GameplayMuteCheck",
		"DisplayModeOption",
		"ResolutionOption",
		"VsyncCheck",
		"RestoreAudioDefaultsButton",
		"RestoreDisplayDefaultsButton",
		"ApplyDisplayButton",
		"DisplayConfirmationLayer",
		"KeepDisplayButton",
		"RevertDisplayButton",
		"ReduceFlashesCheck",
		"DisableDistortionCheck",
		"ResolutionSpeedOption",
		"UiScaleOption",
		"RestoreAccessibilityDefaultsButton",
	]:
		assert_true(
			layer.get_node_or_null("%%%s" % node_name) != null,
			"settings scene should expose %s" % node_name
		)

	layer.free()

func _test_host_scene_contract() -> void:
	for scene_path in HOST_SCENES:
		var source := FileAccess.get_file_as_string(scene_path)
		assert_true(
			source.contains(SETTINGS_SCENE_PATH),
			"%s should instance the shared settings layer" % scene_path
		)

func _test_nested_host_has_one_active_entry() -> void:
	var scene := load("res://scenes/run/three_round_run_screen.tscn")
	var host: Control = scene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(host)
	var settings_layer_count := 0
	var visible_entry_count := 0
	var visible_rule_entry_count := 0
	for node in host.find_children("*", "CanvasLayer", true, false):
		if node is not SettingsLayer:
			continue
		settings_layer_count += 1
		if node.get_node("%SettingsButton").visible:
			visible_entry_count += 1
		if node.get_node("%RuleReferenceButton").visible:
			visible_rule_entry_count += 1
	assert_true(
		settings_layer_count >= 3,
		"nested run fixture should exercise duplicate settings layers"
	)
	assert_equal(
		visible_entry_count,
		1,
		"nested run should expose exactly one active settings entry"
	)
	assert_equal(
		visible_rule_entry_count,
		1,
		"nested run should expose exactly one active rule reference entry"
	)
	host.free()

func _test_exclusive_guides_block_the_entry() -> void:
	for scene_path in [
		"res://scenes/components/single_encounter_tutorial.tscn",
		"res://scenes/components/iron_abacus_guide_overlay.tscn",
		"res://scenes/components/shop_intel_panel.tscn",
	]:
		var source := FileAccess.get_file_as_string(scene_path)
		assert_true(
			source.contains("settings_entry_blocker"),
			"%s should explicitly block the settings entry while visible"
			% scene_path
		)

func _test_ui_script_boundary() -> void:
	var source := FileAccess.get_file_as_string(
		"res://scripts/ui/settings_layer.gd"
	)
	for forbidden in ["AudioServer", "DisplayServer", "ConfigFile"]:
		assert_false(
			source.contains(forbidden),
			"settings UI must not reference %s directly" % forbidden
		)
