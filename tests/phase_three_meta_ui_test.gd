extends "res://tests/test_case.gd"

func run() -> void:
	var menu := _read("res://scenes/run/main_menu_screen.tscn")
	assert_true(menu.contains("DailyChallengeButton"), "main menu exposes daily challenge")
	assert_true(menu.contains("CustomExpeditionButton"), "main menu exposes custom expedition")
	assert_true(menu.contains("AchievementArchiveButton"), "main menu exposes achievement archive")
	var custom := _read("res://scenes/run/custom_expedition_setup_screen.tscn")
	assert_true(custom.contains("TargetMultiplierOption"), "custom setup exposes bounded target multiplier")
	assert_true(custom.contains("CustomModifierList"), "custom setup exposes per-area modifiers")
	assert_true(custom.contains("CustomChallengeList"), "custom setup exposes zero to six challenges")
	var archive := _read("res://scenes/run/achievement_archive_screen.tscn")
	assert_true(archive.contains("AchievementList"), "archive exposes title and badge list")
	var area := _read("res://scenes/run/area_run_screen.tscn")
	assert_true(area.contains("AreaProtocolLabel"), "formal expedition keeps the area passive visible")

func _read(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()
