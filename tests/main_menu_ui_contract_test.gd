extends "res://tests/test_case.gd"

func run() -> void:
	assert_equal(
		ProjectSettings.get_setting("application/config/name"),
		"六面诡局 Demo",
		"the release build should expose the public demo title"
	)
	assert_equal(
		ProjectSettings.get_setting("application/run/main_scene"),
		"res://scenes/run/main_menu_screen.tscn",
		"project should start at the dedicated main menu"
	)
	var packed := load("res://scenes/run/main_menu_screen.tscn")
	assert_true(packed != null, "main menu scene should load")
	if packed == null:
		return
	var menu: Control = packed.instantiate()
	var title := menu.get_node_or_null("%GameTitleLabel") as Label
	assert_true(title != null, "main menu should expose the public game title")
	if title != null:
		assert_equal(title.text, "六面诡局", "the public game title should be exact")
	var expedition_title := menu.get_node_or_null("%ExpeditionTitleLabel") as Label
	assert_true(expedition_title != null, "main menu should label the recommended full demo path")
	if expedition_title != null:
		assert_true("推荐" in expedition_title.text, "the full expedition should be the recommended path")
	assert_true(
		menu.get_node_or_null("%PracticeRoutesLabel") is Label,
		"individual regions should be grouped as optional practice"
	)
	for node_name in [
		"TutorialButton",
		"PracticeButton",
		"GoldCorridorButton",
		"MirrorHallButton",
		"FacelessHubButton",
		"RuleArchiveButton",
	]:
		var button := menu.get_node_or_null("%" + node_name) as Button
		assert_true(button != null, "main menu should expose %s" % node_name)
		if button != null:
			assert_false(button.text.is_empty(), "%s needs visible copy" % node_name)
	assert_equal(
		menu.get_node("%StartExpeditionButton").text,
		"开始 Demo 远征",
		"the primary action should name the complete demo path"
	)
	for node_name in ["GoldCorridorButton", "MirrorHallButton", "FacelessHubButton"]:
		assert_true(
			String(menu.get_node("%" + node_name).text).begins_with("练习："),
			"%s should read as optional practice" % node_name
		)
	for card_path in [
		"SafeArea/Content/RouteGrid/GoldCorridorCard",
		"SafeArea/Content/RouteGrid/MirrorHallCard",
		"SafeArea/Content/RouteGrid/FacelessHubCard",
	]:
		var card := menu.get_node(card_path) as Control
		assert_true(
			card.size_flags_horizontal == Control.SIZE_EXPAND_FILL,
			"practice cards should share the available row width"
		)
	for node_name in ["CreditsButton", "QuitButton", "CloseCreditsButton"]:
		var release_button := menu.get_node_or_null("%" + node_name) as Button
		assert_true(release_button != null, "main menu should expose %s" % node_name)
	var version := menu.get_node_or_null("%VersionLabel") as Label
	assert_true(version != null, "main menu should expose a visible build version")
	var credits_overlay := menu.get_node_or_null("%CreditsOverlay") as Control
	assert_true(credits_overlay != null, "main menu should include production and license information")
	if credits_overlay != null:
		assert_false(credits_overlay.visible, "production and license information starts closed")
	assert_true(
		menu.get_node_or_null("%CreditsText") is TextEdit,
		"production and license information should be scrollable"
	)
	assert_true(
		menu.get_node_or_null("%QuitGameDialog") is ConfirmationDialog,
		"quitting should require confirmation"
	)
	menu.free()
