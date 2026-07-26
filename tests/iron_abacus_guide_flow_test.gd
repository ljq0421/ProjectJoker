extends "res://tests/test_case.gd"

const FlowScript = preload("res://scripts/ui/tutorial/iron_abacus_guide_flow.gd")

const EXPECTED_ORDER: Array[StringName] = [
	&"normal",
	&"shop",
	&"dealer",
	&"reward",
	&"verification",
]

func run() -> void:
	_test_order_and_specs()
	_test_seen_and_dismissed_filtering()
	_test_run_request_deduplication()
	_test_unknown_checkpoint()

func _test_order_and_specs() -> void:
	var flow = FlowScript.new()
	assert_equal(flow.checkpoint_ids(), EXPECTED_ORDER, "checkpoint order should be stable")
	for index in range(EXPECTED_ORDER.size()):
		var checkpoint_id := EXPECTED_ORDER[index]
		var spec: Dictionary = flow.card_spec(checkpoint_id)
		assert_equal(spec.get("id"), checkpoint_id, "spec should retain checkpoint id")
		assert_equal(spec.get("progress_index"), index + 1, "spec should retain original index")
		assert_equal(spec.get("progress_total"), 5, "spec should report five total cards")
		assert_false(String(spec.get("title", "")).is_empty(), "spec title should not be empty")
		assert_false(
			String(spec.get("instruction", "")).is_empty(),
			"spec instruction should not be empty"
		)
		assert_true(
			Array(spec.get("target_ids", [])).size() > 0,
			"spec should have at least one semantic target"
		)

	assert_true(
		String(flow.card_spec(&"normal").get("instruction")).contains("100"),
		"normal copy should state target 100"
	)
	assert_true(
		String(flow.card_spec(&"normal").get("instruction")).contains("2 张情报券"),
		"normal copy should state the two-ticket reward"
	)
	assert_true(
		String(flow.card_spec(&"shop").get("instruction")).contains("12 张"),
		"shop copy should state deck size"
	)
	assert_true(
		String(flow.card_spec(&"dealer").get("instruction")).contains("150"),
		"dealer copy should state target 150"
	)
	assert_true(
		String(flow.card_spec(&"dealer").get("instruction")).contains("减少 2"),
		"dealer copy should state the unassigned-die penalty"
	)
	assert_true(
		String(flow.card_spec(&"reward").get("instruction")).contains("刻印"),
		"reward copy should explain engraving selection"
	)
	assert_true(
		String(flow.card_spec(&"verification").get("instruction")).contains("强制"),
		"verification copy should explain the forced engraved face"
	)

func _test_seen_and_dismissed_filtering() -> void:
	var flow = FlowScript.new()
	var progress := _empty_progress()
	for checkpoint_id in EXPECTED_ORDER:
		assert_true(
			flow.should_present(checkpoint_id, progress),
			"unseen checkpoint should be presentable"
		)

	progress["seen_shop"] = true
	assert_false(flow.should_present(&"shop", progress), "seen checkpoint should be hidden")
	assert_true(flow.should_present(&"dealer", progress), "seen state should not hide other cards")

	progress["dismissed"] = true
	for checkpoint_id in EXPECTED_ORDER:
		assert_false(
			flow.should_present(checkpoint_id, progress),
			"dismissed guide should hide every checkpoint"
		)

func _test_run_request_deduplication() -> void:
	var flow = FlowScript.new()
	var progress := _empty_progress()
	assert_true(flow.should_present(&"dealer", progress), "dealer should initially present")
	assert_true(flow.mark_requested(&"dealer"), "known checkpoint should mark requested")
	assert_false(
		flow.should_present(&"dealer", progress),
		"requested checkpoint should not reopen in the same run"
	)
	assert_true(
		flow.should_present(&"reward", progress),
		"requesting one checkpoint should not hide another"
	)
	flow.reset_run_requests()
	assert_true(
		flow.should_present(&"dealer", progress),
		"reset_run_requests should allow an unseen checkpoint again"
	)

func _test_unknown_checkpoint() -> void:
	var flow = FlowScript.new()
	assert_equal(flow.card_spec(&"unknown"), {}, "unknown checkpoint should have no spec")
	assert_false(
		flow.should_present(&"unknown", _empty_progress()),
		"unknown checkpoint should never present"
	)
	assert_false(flow.mark_requested(&"unknown"), "unknown checkpoint should not mark requested")

func _empty_progress() -> Dictionary:
	return {
		"dismissed": false,
		"seen_normal": false,
		"seen_shop": false,
		"seen_dealer": false,
		"seen_reward": false,
		"seen_verification": false,
	}
