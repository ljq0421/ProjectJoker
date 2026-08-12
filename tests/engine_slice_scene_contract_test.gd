extends "res://tests/test_case.gd"

const SCENE_PATH := "res://scenes/run/engine_slice_screen.tscn"
const SCRIPT_PATH := "res://scripts/ui/engine_slice_screen.gd"

func run() -> void:
	assert_true(ResourceLoader.exists(SCENE_PATH), "engine slice scene should exist")
	assert_true(ResourceLoader.exists(SCRIPT_PATH), "engine slice UI binder should exist")
	var packed = load(SCENE_PATH)
	assert_true(packed != null, "engine slice scene should load")
	if packed == null:
		return
	var screen = packed.instantiate()
	for node_path in [
		"%SetupPanel", "%RoutePanel", "%BattlePanel", "%RewardPanel", "%ShopPanel", "%ResultPanel",
		"%EnemyPortrait", "%EnemyHealth", "%IntentTitle", "%AttackSlots", "%GuardSlots", "%EngineSlots", "%EngineChargeLabel",
		"%DiceRow", "%TechniqueRow", "%TacticRow", "%PreviewLabel", "%UndoButton", "%CommitButton",
	]:
		assert_true(screen.get_node_or_null(node_path) != null, "%s must be scene-owned" % node_path)
	screen.free()
	var source := FileAccess.get_file_as_string(SCRIPT_PATH)
	assert_true(source.contains("session.battle.preview"), "UI should consume the deterministic resolver preview")
	assert_true(source.contains("report.counter_damage"), "preview should distinguish post-intent counter damage")
	assert_false(source.contains("func _calculate_damage"), "UI must not own a second battle formula")
	var menu = load("res://scenes/run/main_menu_screen.tscn").instantiate()
	assert_true(menu.get_node_or_null("%EngineSliceButton") != null, "main menu should expose the isolated slice entry")
	menu.free()
	var narrative_source := FileAccess.get_file_as_string("res://scenes/components/narrative_card.tscn")
	assert_true(narrative_source.contains("fit_content = false"), "mutation candidate text should use a bounded layout")
