extends "res://tests/test_case.gd"

const REFERENCE_SCENE_PATH := "res://scenes/components/rule_reference_overlay.tscn"

func run() -> void:
	var packed := load(REFERENCE_SCENE_PATH)
	assert_true(packed != null, "rule reference overlay scene should load")
	if packed == null:
		return
	var overlay: Control = packed.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(overlay)
	for node_name in [
		"CloseRuleReferenceButton",
		"CurrentRulesButton",
		"Archive01Button",
		"Archive02Button",
		"Archive03Button",
		"Archive04Button",
		"Archive05Button",
		"Archive06Button",
		"Rule01Button",
		"Rule02Button",
		"Rule03Button",
		"ArchiveContextLabel",
		"ArchiveSummaryLabel",
		"RuleDetailTitle",
		"RuleDetailFormula",
		"RuleDetailDescription",
		"RuleDetailMetrics",
		"RuleDetailTiming",
		"HandbookHint",
		"PracticeArchiveButton",
	]:
		assert_true(
			overlay.get_node_or_null("%%%s" % node_name) != null,
			"rule reference overlay should expose %s" % node_name
		)
	assert_true(
		overlay.has_method("open_reference"),
		"rule reference overlay should expose read-only opening"
	)
	assert_true(
		overlay.has_method("show_archive"),
		"rule reference overlay should switch archive groups"
	)
	overlay.call("open_reference", [])
	assert_true(overlay.visible, "opening rule reference should reveal the overlay")
	assert_false(
		overlay.get_node("%PracticeArchiveButton").visible,
		"in-game handbook should not offer an action that leaves the current run"
	)
	assert_false(
		overlay.get_node("%CurrentRulesButton").visible,
		"current rules entry should hide without an active encounter"
	)
	assert_false(
		overlay.get_node("%Rule01Button").text.is_empty(),
		"archive opening should bind the first rule"
	)
	overlay.get_node("%Rule02Button").emit_signal("pressed")
	assert_equal(
		overlay.get_node("%RuleDetailFormula").text,
		"Σ ≥ 7",
		"minimum-sum reference should use the evaluator's public target"
	)
	overlay.call("show_archive", &"archive_06")
	assert_equal(
		overlay.get_node("%Rule03Button").text,
		"反向台",
		"distortion archive should expose the canonical reverse-table name"
	)
	overlay.get_node("%Rule03Button").emit_signal("pressed")
	assert_true(
		overlay.get_node("%RuleDetailDescription").text.contains("翻转"),
		"reverse-table detail should explain its direction change"
	)
	overlay.call("open_reference", [], true, &"archive_06", "返回主页面")
	assert_true(
		overlay.get_node("%PracticeArchiveButton").visible,
		"standalone handbook should offer practice for the selected category"
	)
	assert_true(
		overlay.get_node("%PracticeArchiveButton").text.contains("扭曲"),
		"practice action should name the selected rule category"
	)
	overlay.free()
