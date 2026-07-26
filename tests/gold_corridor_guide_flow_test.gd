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
	_test_seen_and_dismissed_filtering()
	_test_run_request_deduplication()
	_test_unknown_checkpoint_is_rejected()

func _test_order_and_complete_specs() -> void:
	var flow = FlowScript.new()
	assert_equal(flow.checkpoint_ids(), EXPECTED_ORDER, "order should be stable")
	for index in range(EXPECTED_ORDER.size()):
		var checkpoint_id := EXPECTED_ORDER[index]
		var spec: Dictionary = flow.card_spec(checkpoint_id)
		assert_equal(spec.get("id"), checkpoint_id, "spec should retain ID")
		assert_equal(spec.get("progress_label"), "鍖哄煙鎻愮ず", "label should be exact")
		assert_equal(spec.get("progress_index"), index + 1, "index should be stable")
		assert_equal(spec.get("progress_total"), 4, "total should be four")
		assert_false(String(spec.get("title", "")).is_empty(), "title is required")
		assert_false(String(spec.get("instruction", "")).is_empty(), "instruction is required")
		assert_true(Array(spec.get("target_ids", [])).size() > 0, "targets are required")

func _test_exact_strategy_copy() -> void:
	var flow = FlowScript.new()
	assert_true(String(flow.card_spec(&"route").get("instruction")).contains("涓夎疆鍏卞悓瀹屾垚绱鐩爣"), "route copy should explain shared accumulation")
	assert_true(String(flow.card_spec(&"shop").get("instruction")).contains("绗簩涓埧闂村拰閾佺畻鐩?"), "shop copy should explain inheritance")
	assert_true(String(flow.card_spec(&"shop").get("instruction")).contains("涓嶈喘涔扮洿鎺ョ寮€"), "shop copy should allow leaving")
	assert_true(String(flow.card_spec(&"dealer").get("instruction")).contains("150"), "dealer copy should state target")
	assert_true(String(flow.card_spec(&"dealer").get("instruction")).contains("鍑忓皯 2"), "dealer copy should state penalty")
	assert_true(String(flow.card_spec(&"engraving").get("instruction")).contains("涓嶅啀杩涘叆鍒诲嵃楠岃瘉灞€"), "engraving copy should state direct completion")

func _test_seen_and_dismissed_filtering() -> void:
	var flow = FlowScript.new()
	var snapshot := _progress_fixture()
	assert_true(flow.should_present(&"route", snapshot), "unseen route should present")
	snapshot["seen_shop"] = true
	assert_false(flow.should_present(&"shop", snapshot), "seen shop should be hidden")
	snapshot["dismissed"] = true
	assert_false(flow.should_present(&"dealer", snapshot), "dismissed guide should hide cards")

func _test_run_request_deduplication() -> void:
	var flow = FlowScript.new()
	var snapshot := _progress_fixture()
	assert_true(flow.mark_requested(&"route"), "known checkpoint should request")
	assert_false(flow.should_present(&"route", snapshot), "requested route should be hidden")
	assert_true(flow.should_present(&"shop", snapshot), "shop remains presentable")

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
