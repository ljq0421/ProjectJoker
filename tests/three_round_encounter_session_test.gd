extends "res://tests/test_case.gd"

const RunScript = preload("res://scripts/run/three_round_encounter_session.gd")

func run() -> void:
	var first := _play_empty_run(20260726, 100)
	var second := _play_empty_run(20260726, 100)
	assert_equal(first.dice, second.dice, "same seed should reproduce dice")
	assert_equal(first.hands, second.hands, "same seed should reproduce hands")
	assert_equal(first.offers, second.offers, "same seed should reproduce shop offer order")
	assert_equal(first.seen.size(), 12, "three rounds should expose twelve cards")
	var unique_seen: Dictionary = {}
	for card_id in first.seen:
		unique_seen[card_id] = true
	assert_equal(unique_seen.size(), 12, "three round hands should not repeat cards")
	assert_equal(first.status, RunScript.Status.FAILED, "zero total should fail a target of 100")
	assert_equal(
		first.cumulative,
		first.report_sum,
		"cumulative total should equal the three committed reports"
	)

	var different := _play_empty_run(20260727, 100)
	assert_true(
		first.dice != different.dice or first.hands != different.hands,
		"different seeds should change dice or hand order"
	)

	var successful := _play_empty_run(20260726, 0)
	var successful_repeat := _play_empty_run(20260726, 0)
	assert_equal(successful.status, RunScript.Status.SUCCEEDED, "zero target should succeed")
	assert_equal(successful.intel, 2, "success should grant two intelligence tickets")
	assert_equal(successful.offers.size(), 3, "success should prepare three offers")
	assert_equal(
		successful.offers,
		successful_repeat.offers,
		"same successful seed should reproduce shop offer order"
	)

func _play_empty_run(seed_value: int, target_total: int) -> Dictionary:
	var run_session = RunScript.new(CardCatalog.new(), seed_value, target_total)
	assert_true(run_session.start().accepted, "run should start")
	var dice_by_round: Array = []
	var hands_by_round: Array = []
	var seen: Array[StringName] = []
	var report_sum := 0

	for round_number in range(1, 4):
		var dice_values: Array[int] = []
		for die in run_session.current_session.controller.state.dice:
			dice_values.append(die.value)
		dice_by_round.append(dice_values)
		hands_by_round.append(run_session.current_hand_ids.duplicate())
		seen.append_array(run_session.current_hand_ids)

		var preview: ResolutionReport = run_session.current_session.preview()
		var report: ResolutionReport = run_session.current_session.commit()
		assert_equal(report.total, preview.total, "preview and commit totals should match")
		assert_equal(
			report.event_signature(),
			preview.event_signature(),
			"preview and commit events should match"
		)
		report_sum += report.total
		var accepted: OperationResult = run_session.accept_committed_report(report)
		assert_true(accepted.accepted, "committed report should be accepted")
		if round_number == 1:
			var before: int = run_session.cumulative_total
			var duplicate: OperationResult = run_session.accept_committed_report(report)
			assert_false(duplicate.accepted, "same round should not be accumulated twice")
			assert_equal(run_session.cumulative_total, before, "duplicate should not change total")
		if round_number < 3:
			assert_equal(
				run_session.status,
				RunScript.Status.ROUND_SUMMARY,
				"early rounds should stop at summary"
			)
			assert_true(run_session.advance_round().accepted, "next round should start")

	return {
		"dice": dice_by_round,
		"hands": hands_by_round,
		"seen": seen,
		"status": run_session.status,
		"intel": run_session.intel_tickets,
		"offers": run_session.shop_offer_ids.duplicate(),
		"cumulative": run_session.cumulative_total,
		"report_sum": report_sum,
	}
