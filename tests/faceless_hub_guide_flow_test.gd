extends "res://tests/test_case.gd"

const EXPECTED_ORDER: Array[StringName] = [
	&"composite",
	&"schedule",
	&"restriction",
]

func run() -> void:
	var flow := FacelessHubGuideFlow.new()
	assert_equal(
		flow.checkpoint_ids(),
		EXPECTED_ORDER,
		"faceless guide checkpoint order is fixed"
	)
	for index in range(EXPECTED_ORDER.size()):
		var checkpoint_id: StringName = EXPECTED_ORDER[index]
		var spec := flow.card_spec(checkpoint_id)
		assert_equal(spec.id, checkpoint_id, "card ID should stay stable")
		assert_equal(spec.progress_index, index + 1, "progress index should match")
		assert_equal(spec.progress_total, 3, "progress total should be three")
		assert_false(String(spec.title).strip_edges().is_empty(), "title should exist")
		assert_false(
			String(spec.instruction).strip_edges().is_empty(),
			"instruction should exist"
		)
		assert_true(
			not spec.target_ids.is_empty(),
			"each guide card should focus real UI"
		)
		assert_true(
			flow.should_present(checkpoint_id, {}),
			"unseen checkpoint should present"
		)
		assert_true(
			flow.mark_requested(checkpoint_id),
			"known checkpoint should mark requested"
		)
		assert_false(
			flow.should_present(checkpoint_id, {}),
			"requested checkpoint should not repeat in one run"
		)

	var fresh := FacelessHubGuideFlow.new()
	assert_false(
		fresh.should_present(&"composite", {"dismissed": true}),
		"dismissed guide stays hidden"
	)
	assert_false(
		fresh.should_present(&"restriction", {"seen_restriction": true}),
		"seen checkpoint stays hidden"
	)
	assert_equal(fresh.card_spec(&"missing"), {}, "unknown checkpoint has no card")
