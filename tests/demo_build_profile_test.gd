extends "res://tests/test_case.gd"

const DemoProfile = preload("res://scripts/run/demo_build_profile.gd")

func run() -> void:
	var profile = DemoProfile.new()
	assert_true(
		profile.is_demo_build(-1, PackedStringArray(["windows", "demo"])),
		"the export custom feature should activate demo scope"
	)
	assert_false(
		profile.is_demo_build(-1, PackedStringArray(["windows", "editor"])),
		"ordinary editor and development builds should retain full access"
	)
	assert_true(
		profile.is_demo_build(1, PackedStringArray()),
		"tests and captures should be able to force demo scope"
	)
	assert_false(
		profile.is_demo_build(0, PackedStringArray(["demo"])),
		"tests and captures should be able to force full scope"
	)
	var demo_access: Dictionary = profile.main_menu_access(
		1,
		PackedStringArray()
	)
	assert_true(demo_access["complete_expedition"], "demo should keep the complete expedition")
	assert_true(demo_access["tutorial"], "demo should keep onboarding")
	assert_false(demo_access["region_practice"], "demo should hide redundant single-region practice")
	assert_false(demo_access["developer_practice"], "demo should hide prototype practice entries")
