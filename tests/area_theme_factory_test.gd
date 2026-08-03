extends "res://tests/test_case.gd"

const FACTORY_PATH := "res://scripts/ui/area_theme_factory.gd"
const BASE_THEME := preload("res://resources/themes/neon_dream_theme.tres")
const PRESENTATIONS := preload("res://scripts/ui/area_presentation_catalog.gd")

func run() -> void:
	var factory_script := load(FACTORY_PATH)
	assert_true(factory_script != null, "area theme factory should exist")
	if factory_script == null:
		return
	var button_surfaces: Dictionary = {}
	var panel_surfaces: Dictionary = {}
	for area_id in [&"gold_corridor", &"mirror_hall", &"faceless_hub"]:
		var presentation: Dictionary = PRESENTATIONS.new().find(area_id)
		for key in ["surface", "surface_raised"]:
			assert_true(
				presentation.has(key),
				"%s should define %s" % [area_id, key]
			)
		var themed: Theme = factory_script.build(BASE_THEME, presentation)
		var button_style := themed.get_stylebox("normal", "Button") as StyleBoxFlat
		var panel_style := themed.get_stylebox("panel", "PanelContainer") as StyleBoxFlat
		assert_true(button_style != null, "%s buttons should use a flat area surface" % area_id)
		assert_true(panel_style != null, "%s panels should use a flat area surface" % area_id)
		if button_style != null:
			assert_equal(
				button_style.bg_color,
				presentation["surface_raised"],
				"%s button surface should follow its area palette" % area_id
			)
			button_surfaces[button_style.bg_color] = true
		if panel_style != null:
			assert_equal(
				panel_style.bg_color,
				presentation["surface"],
				"%s panel surface should follow its area palette" % area_id
			)
			panel_surfaces[panel_style.bg_color] = true
	assert_equal(button_surfaces.size(), 3, "all three button surfaces should be distinct")
	assert_equal(panel_surfaces.size(), 3, "all three panel surfaces should be distinct")
