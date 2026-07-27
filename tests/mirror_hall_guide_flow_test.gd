extends "res://tests/test_case.gd"

const EXPECTED_ORDER: Array[StringName] = [
	&"direction",
	&"mirror",
	&"dealer",
]

func run() -> void:
	var flow := MirrorHallGuideFlow.new()
	assert_equal(flow.checkpoint_ids(), EXPECTED_ORDER, "mirror guide order is fixed")
	for index in range(EXPECTED_ORDER.size()):
		var checkpoint_id: StringName = EXPECTED_ORDER[index]
		var spec := flow.card_spec(checkpoint_id)
		assert_equal(spec.id, checkpoint_id, "card ID should stay stable")
		assert_equal(spec.progress_index, index + 1, "progress index should match")
		assert_equal(spec.progress_total, 3, "progress total should be three")
		assert_false(String(spec.title).strip_edges().is_empty(), "title should exist")
		assert_false(String(spec.instruction).strip_edges().is_empty(), "copy should exist")
		assert_true(spec.target_ids.size() >= 3, "each card should focus real UI")
		assert_true(flow.should_present(checkpoint_id, {}), "unseen card should present")
		assert_true(flow.mark_requested(checkpoint_id), "known checkpoint marks requested")
		assert_false(flow.should_present(checkpoint_id, {}), "requested card should not repeat")

	var fresh := MirrorHallGuideFlow.new()
	assert_false(fresh.should_present(&"direction", {"dismissed": true}), "dismissed hides")
	assert_false(
		fresh.should_present(&"mirror", {"seen_mirror": true}),
		"seen checkpoint stays hidden"
	)
	assert_equal(fresh.card_spec(&"missing"), {}, "unknown checkpoint has no card")
