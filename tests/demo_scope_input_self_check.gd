extends SceneTree

const MENU_SCENE := preload("res://scenes/run/main_menu_screen.tscn")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var demo_menu: MainMenuScreen = MENU_SCENE.instantiate()
	demo_menu.demo_scope_override = 1
	root.add_child(demo_menu)
	await process_frame
	assert(not demo_menu.get_node("%PracticeRoutesHeader").visible)
	assert(not demo_menu.get_node("%RouteGrid").visible)
	assert(not demo_menu.get_node("%RuleArchiveButton").visible)
	assert(not demo_menu.get_node("%PracticeButton").visible)
	assert(demo_menu.get_node("%DemoJourneyPanel").visible)
	assert(demo_menu.get_node("%PracticeRow").visible)
	assert(demo_menu.get_node("%TutorialButton").visible)
	assert(demo_menu.get_node("%StartExpeditionButton").visible)
	demo_menu.queue_free()
	await process_frame

	var full_menu: MainMenuScreen = MENU_SCENE.instantiate()
	full_menu.demo_scope_override = 0
	root.add_child(full_menu)
	await process_frame
	assert(full_menu.get_node("%PracticeRoutesHeader").visible)
	assert(full_menu.get_node("%RouteGrid").visible)
	assert(full_menu.get_node("%RuleArchiveButton").visible)
	assert(full_menu.get_node("%PracticeButton").visible)
	assert(not full_menu.get_node("%DemoJourneyPanel").visible)
	assert(full_menu.get_node("%TutorialButton").visible)
	print("DEMO_SCOPE_INPUT_SELF_CHECK: PASS")
	quit(0)
