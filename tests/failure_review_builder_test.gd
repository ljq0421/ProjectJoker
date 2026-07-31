extends "res://tests/test_case.gd"

func run() -> void:
	var builder_script := load("res://scripts/run/failure_review_builder.gd")
	assert_true(builder_script != null, "failure review builder should exist")
	if builder_script == null:
		return

	var first := ResolutionReport.new()
	first.total = 42
	first.unassigned_dice = 2
	first.rule_failures = [
		{
			"rule_id": &"left",
			"display_name": "左轨精确校验",
			"reason": "需要总和 12，当前为 9",
			"assigned_dice": 2,
		},
	]
	first.missed_effects = ["左轨未通过，桥接未触发"]
	var second := ResolutionReport.new()
	second.total = 18
	second.unassigned_dice = 1
	second.dealer_reward_lost = 2
	second.rule_failures = first.rule_failures.duplicate(true)
	var third := ResolutionReport.new()
	third.total = 35

	var review: Dictionary = builder_script.new().build(
		[first, second, third],
		120,
		true
	)
	assert_equal(review.get("cumulative_total"), 95, "review should sum rounds")
	assert_equal(review.get("target_gap"), 25, "review should expose target gap")
	assert_equal(review.get("weakest_round"), 2, "review should find weakest round")
	assert_equal(review.get("weakest_total"), 18, "review should retain weakest score")
	assert_equal(review.get("unassigned_dice"), 3, "review should sum unused dice")
	assert_equal(review.get("dealer_reward_lost"), 2, "review should sum lost reward")
	assert_equal(
		review.get("rule_failures", []).size(),
		1,
		"duplicate rule failures should collapse"
	)
	assert_true(
		review.get("suggestions", []).size() <= 3,
		"review should show at most three suggestions"
	)
	assert_true(
		String(review.get("suggestions", [])[0]).contains("未分配"),
		"unused dice should be the first actionable suggestion"
	)
