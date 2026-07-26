extends "res://tests/test_case.gd"

const FlowScript = preload(
	"res://scripts/ui/tutorial/gold_corridor_guide_flow.gd"
)
const EXPECTED_ORDER: Array[StringName] = [
	&"route",
	&"shop",
	&"dealer",
	&"engraving",
]

func run() -> void:
	_test_order_and_complete_specs()
	_test_exact_strategy_copy()
	_test_card_specs_are_defensive_copies()
	_test_seen_and_dismissed_filtering()
	_test_run_request_deduplication()
	_test_request_deduplication_is_instance_local()
	_test_unknown_checkpoint_is_rejected()

func _test_order_and_complete_specs() -> void:
	var flow = FlowScript.new()
	assert_equal(flow.checkpoint_ids(), EXPECTED_ORDER, "order should be stable")
	for index in range(EXPECTED_ORDER.size()):
		var checkpoint_id := EXPECTED_ORDER[index]
		var spec: Dictionary = flow.card_spec(checkpoint_id)
		assert_equal(spec.get("id"), checkpoint_id, "spec should retain ID")
		assert_equal(spec.get("progress_label"), "区域提示", "label should be exact")
		assert_equal(spec.get("progress_index"), index + 1, "index should be stable")
		assert_equal(spec.get("progress_total"), 4, "total should be four")
		assert_false(String(spec.get("title", "")).is_empty(), "title is required")
		assert_false(String(spec.get("instruction", "")).is_empty(), "instruction is required")
		assert_true(Array(spec.get("target_ids", [])).size() > 0, "targets are required")

func _test_exact_strategy_copy() -> void:
	var flow = FlowScript.new()
	assert_true(
		String(flow.card_spec(&"route").get("instruction")).contains(
			"三轮共同完成累计目标"
		),
		"route copy should explain shared accumulation"
	)
	assert_true(
		String(flow.card_spec(&"shop").get("instruction")).contains(
			"第二个房间和铁算盘"
		),
		"shop copy should explain inheritance"
	)
	assert_true(
		String(flow.card_spec(&"shop").get("instruction")).contains(
			"不购买直接离开"
		),
		"shop copy should allow leaving"
	)
	assert_true(String(flow.card_spec(&"dealer").get("instruction")).contains("150"), "dealer copy should state target")
	assert_true(String(flow.card_spec(&"dealer").get("instruction")).contains("减少 2"), "dealer copy should state penalty")
	assert_true(
		String(flow.card_spec(&"engraving").get("instruction")).contains(
			"不再进入刻印验证局"
		),
		"engraving copy should state direct completion"
	)

func _test_seen_and_dismissed_filtering() -> void:
	var flow = FlowScript.new()
	var snapshot := _progress_fixture()
	assert_true(flow.should_present(&"route", snapshot), "unseen route should present")
	snapshot["seen_shop"] = true
	assert_false(flow.should_present(&"shop", snapshot), "seen shop should be hidden")
	snapshot["dismissed"] = true
	assert_false(flow.should_present(&"dealer", snapshot), "dismissed guide should hide cards")

func _test_card_specs_are_defensive_copies() -> void:
	var flow = FlowScript.new()
	var mutated_spec: Dictionary = flow.card_spec(&"route")
	var mutated_targets: Array = mutated_spec.get("target_ids", [])
	mutated_targets[0] = &"mutated_target"
	mutated_targets.append(&"extra_target")
	var fresh_spec: Dictionary = flow.card_spec(&"route")
	assert_equal(
		fresh_spec.get("target_ids"),
		[&"route_left", &"route_right"],
		"nested target IDs should be copied defensively"
	)

func _test_run_request_deduplication() -> void:
	var flow = FlowScript.new()
	var snapshot := _progress_fixture()
	assert_true(flow.mark_requested(&"route"), "known checkpoint should request")
	assert_false(flow.should_present(&"route", snapshot), "requested route should be hidden")
	assert_true(flow.should_present(&"shop", snapshot), "shop remains presentable")

func _test_request_deduplication_is_instance_local() -> void:
	var first_flow = FlowScript.new()
	var second_flow = FlowScript.new()
	var snapshot := _progress_fixture()
	assert_true(first_flow.mark_requested(&"route"), "first flow should record route")
	assert_false(
		first_flow.should_present(&"route", snapshot),
		"first flow should suppress its requested route"
	)
	assert_true(
		second_flow.should_present(&"route", snapshot),
		"a second flow instance should still present route"
	)

func _test_unknown_checkpoint_is_rejected() -> void:
	var flow = FlowScript.new()
	var snapshot := _progress_fixture()
	assert_equal(flow.card_spec(&"unknown"), {}, "unknown spec should be empty")
	assert_false(flow.should_present(&"unknown", snapshot), "unknown checkpoint should not present")
	assert_false(flow.mark_requested(&"unknown"), "unknown checkpoint should not request")

func _progress_fixture() -> Dictionary:
	return {
		"dismissed": false,
		"seen_route": false,
		"seen_shop": false,
		"seen_dealer": false,
		"seen_engraving": false,
	}
