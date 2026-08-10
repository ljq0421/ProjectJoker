extends "res://tests/test_case.gd"

func run() -> void:
	_test_area_balance_telemetry_is_checkpointed()
	_test_expedition_aggregates_area_telemetry()

func _test_area_balance_telemetry_is_checkpointed() -> void:
	var area := AreaRunSession.new(20260810)
	assert_true(area.start().accepted, "telemetry area should start")
	var report := ResolutionReport.new()
	report.consolation_awarded = true
	report.resonance_awarded = true
	report.storm_awarded = true
	area._record_balance_report(report)
	area._record_emergency_balance(&"reroll", 1)
	area._record_emergency_balance(&"calibration", 2)
	area._record_balance_sample()
	var telemetry: Dictionary = area.balance_telemetry_snapshot()
	assert_equal(telemetry["consolation_rounds"], 1, "consolation should be counted")
	assert_equal(telemetry["resonance_rounds"], 1, "resonance should be counted")
	assert_equal(telemetry["storm_rounds"], 1, "storm should be counted")
	assert_equal(telemetry["emergency_spend_total"], 3, "emergency spend should total")
	assert_true(telemetry["average_deck_size"] >= 12.0, "deck average should be recorded")
	assert_true(telemetry.has("average_intel_balance"), "intel average should be recorded")
	var checkpoint := area.checkpoint_snapshot()
	assert_true(checkpoint.has("balance_telemetry"), "area checkpoint should persist telemetry")
	var restored := AreaRunSession.new(20260810)
	assert_true(restored.restore_checkpoint(checkpoint).accepted, "telemetry checkpoint should restore")
	assert_equal(
		restored.balance_telemetry_snapshot(),
		telemetry,
		"telemetry should survive an exact checkpoint round trip"
	)

func _test_expedition_aggregates_area_telemetry() -> void:
	var expedition := ExpeditionSession.new()
	assert_true(expedition.start_new(20260810).accepted, "telemetry expedition should start")
	var area_telemetry := {
		"consolation_rounds": 2,
		"resonance_rounds": 1,
		"storm_rounds": 1,
		"emergency_rerolls": 1,
		"emergency_calibrations": 1,
		"emergency_retries": 0,
		"emergency_spend_total": 3,
		"deck_size_total": 26,
		"intel_balance_total": 8,
		"sample_count": 2,
		"average_deck_size": 13.0,
		"average_intel_balance": 4.0,
	}
	expedition.area_checkpoint = {
		"area_id": &"gold_corridor",
		"balance_telemetry": area_telemetry,
	}
	var aggregate: Dictionary = expedition.balance_telemetry_snapshot()
	assert_equal(aggregate["consolation_rounds"], 2, "active area should aggregate")
	assert_equal(aggregate["average_deck_size"], 13.0, "weighted deck average should aggregate")
	assert_equal(aggregate["average_intel_balance"], 4.0, "weighted intel average should aggregate")
	assert_true(
		expedition.to_snapshot().has("balance_telemetry"),
		"expedition save should expose its balance telemetry"
	)
