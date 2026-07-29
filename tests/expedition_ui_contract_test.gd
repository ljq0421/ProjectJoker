extends "res://tests/test_case.gd"

func run() -> void:
	_test_main_menu_expedition_controls()
	_test_expedition_host_and_summary_structure()
	_test_area_complete_panel_supports_continuation()

func _test_main_menu_expedition_controls() -> void:
	var menu: Control = load(
		"res://scenes/run/main_menu_screen.tscn"
	).instantiate()
	for node_name in [
		"StartExpeditionButton",
		"ContinueExpeditionButton",
		"AbandonExpeditionButton",
		"ExpeditionStatusLabel",
		"AbandonExpeditionDialog",
	]:
		assert_true(
			menu.get_node_or_null("%" + node_name) != null,
			"main menu should expose %s" % node_name
		)
	menu.free()

func _test_expedition_host_and_summary_structure() -> void:
	var packed := load("res://scenes/run/expedition_run_screen.tscn")
	assert_true(packed != null, "expedition host scene should load")
	if packed == null:
		return
	var screen: Control = packed.instantiate()
	assert_true(screen is ExpeditionRunScreen, "host should use ExpeditionRunScreen")
	for node_name in [
		"AreaHost",
		"ExpeditionErrorPanel",
		"ExpeditionSummaryPanel",
		"ExpeditionSeedLabel",
		"ExpeditionAreaHistoryLabel",
		"ExpeditionEpilogueLabel",
		"NarrativeCard",
		"ReturnFromExpeditionButton",
	]:
		assert_true(
			screen.get_node_or_null("%" + node_name) != null,
			"expedition host should expose %s" % node_name
		)
	screen.free()

func _test_area_complete_panel_supports_continuation() -> void:
	var panel: Control = load(
		"res://scenes/components/area_complete_panel.tscn"
	).instantiate()
	assert_true(
		panel.has_signal("continue_requested"),
		"area complete panel should expose continuation signal"
	)
	panel.free()
