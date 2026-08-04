extends "res://tests/test_case.gd"

const SCENE_PATH := "res://scenes/run/dice_first_prototype_screen.tscn"
const SCRIPT_PATH := "res://scripts/ui/dice_first_prototype_screen.gd"
const DIE_SCENE_PATH := "res://scenes/components/dice_first_die_token.tscn"

func run() -> void:
	assert_true(ResourceLoader.exists(SCENE_PATH), "dice-first playable scene should exist")
	assert_true(ResourceLoader.exists(SCRIPT_PATH), "dice-first screen binder should exist")
	assert_true(ResourceLoader.exists(DIE_SCENE_PATH), "large dice token scene should exist")
	if not ResourceLoader.exists(SCENE_PATH):
		return
	var packed = load(SCENE_PATH)
	assert_true(packed != null, "dice-first scene should load")
	if packed == null:
		return
	var screen = packed.instantiate()
	for node_path in [
		"%RollButton",
		"%RerollButton",
		"%KeepAllButton",
		"%DiceTray",
		"%Body",
		"%BoardColumn",
		"%RightRail",
		"%ResonanceList",
		"%SelectionPanel",
		"%SelectionSummaryLabel",
		"%LeftTableButton",
		"%RightTableButton",
		"%ClearTableButton",
		"%LeftTableDiceLabel",
		"%RightTableDiceLabel",
		"%CrossTableEchoLabel",
		"%InstructionRow",
		"%PreviewPanel",
		"%PreviewTotalLabel",
		"%EnergyLabel",
		"%BreakthroughButton",
		"%CommitButton",
		"%RestartButton",
		"%Footer",
		"%BreakthroughOverlay",
	]:
		assert_true(screen.get_node_or_null(node_path) != null, "%s must be scene-owned" % node_path)
	assert_true(screen.get_node_or_null("%LockChoices") == null, "lock choice buttons should be removed from the scene")
	assert_true(screen.get_node_or_null("%LockPanel") == null, "lock panel should be removed from the scene")
	screen.free()
	var source := FileAccess.get_file_as_string(SCRIPT_PATH)
	assert_true(source.contains("DiceFirstResolver"), "UI should consume the formal resolver")
	assert_false(source.contains("func _calculate_score"), "UI must not own a second score path")
	assert_true(source.contains("CardDefinition.new"), "prototype instructions should retain CardDefinition")
	assert_false(source.contains("静域"), "obsolete multiplier-domain wording should be removed")
	assert_false(source.contains("辉域"), "obsolete multiplier-domain wording should be removed")
	var scene_source := FileAccess.get_file_as_string(SCENE_PATH)
	var player_copy := source + scene_source
	assert_false(player_copy.contains("锁住"), "the redundant lock action should be removed")
	assert_false(player_copy.contains("锁定组合"), "player copy should not imply a separate lock state")
	assert_true(player_copy.contains("选择 1–3 颗骰子重投"), "the reroll action should be direct")
	assert_true(player_copy.contains("组合升级 +1能量"), "the upgrade reward should remain explicit")
	assert_true(player_copy.contains("跨台共振"), "the behavior rule should explain its spatial condition")
	assert_true(player_copy.contains("左台 3 颗 · 右台 3 颗"), "the allocation contract should be explicit")
	assert_true(player_copy.contains("极性回路"), "the rule pool should include a sum-seven spatial contract")
	assert_true(player_copy.contains("蓄能台"), "the rule pool should include a score-for-energy contract")
	assert_false(player_copy.contains("迁徙"), "internal migration terminology should not appear in player copy")
	assert_false(player_copy.contains("兑现"), "cashout terminology should be replaced by a plain score action")
	assert_false(player_copy.contains("拿额外分"), "obsolete cashout action should be removed")
	assert_false(player_copy.contains("保住组合"), "obsolete recovery action should be removed")
	var menu = load("res://scenes/run/main_menu_screen.tscn").instantiate()
	assert_true(
		menu.get_node_or_null("%DiceFirstPrototypeButton") != null,
		"main menu should expose the independent developer prototype entry"
	)
	menu.free()
