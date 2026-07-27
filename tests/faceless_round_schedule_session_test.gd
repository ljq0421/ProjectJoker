extends "res://tests/test_case.gd"

func run() -> void:
	_test_schedule_changes_each_round_and_requires_choice()
	_test_failed_third_round_creation_is_atomic()
	_test_area_session_delegates_choice_only_during_dealer()

func _test_schedule_changes_each_round_and_requires_choice() -> void:
	var setup := EncounterRunSetup.new()
	setup.run_rng = RunRng.new(20260727)
	setup.deck_ids = CardCatalog.new().starter_ids()
	setup.round_schedule = _schedule()
	setup.prepare_shop_offers = false
	var session := ThreeRoundEncounterSession.new(
		CardCatalog.new(),
		20260727,
		0,
		setup
	)

	assert_true(session.start().accepted, "scheduled session should start")
	assert_equal(
		session.current_round_plan().id,
		&"round_one",
		"first round should expose first plan"
	)
	assert_equal(
		session.current_session.controller.encounter.id,
		&"encounter_one",
		"first round should bind first encounter"
	)
	_commit_current_round(session)
	assert_equal(
		session.status,
		ThreeRoundEncounterSession.Status.ROUND_SUMMARY,
		"first round should keep legacy summary boundary"
	)

	assert_true(session.advance_round().accepted, "second round should start")
	assert_equal(session.current_round_plan().id, &"round_two", "second plan should bind")
	assert_equal(
		session.current_session.controller.encounter.id,
		&"encounter_two",
		"second encounter should bind"
	)
	_commit_current_round(session)
	assert_equal(
		session.status,
		ThreeRoundEncounterSession.Status.AWAITING_RESTRICTION,
		"second round should wait for a public restriction"
	)
	assert_false(
		session.advance_round().accepted,
		"waiting state should not advance without a choice"
	)
	assert_equal(
		session.public_restriction_options().size(),
		2,
		"both restrictions should remain publicly queryable"
	)

	var rng_before := session.setup.run_rng.snapshot_state()
	var hand_before := session.current_hand_ids.duplicate()
	var round_before := session.current_round
	assert_false(
		session.choose_final_restriction(&"missing").accepted,
		"unknown restriction should be rejected"
	)
	assert_equal(session.current_round, round_before, "invalid choice should keep round")
	assert_equal(session.current_hand_ids, hand_before, "invalid choice should keep hand")
	assert_equal(
		session.setup.run_rng.snapshot_state(),
		rng_before,
		"invalid choice should not consume RNG"
	)

	assert_true(
		session.choose_final_restriction(&"solo_verdict").accepted,
		"public restriction should start third round"
	)
	assert_equal(
		session.status,
		ThreeRoundEncounterSession.Status.PLAYING,
		"valid choice should enter third round"
	)
	assert_equal(session.current_round, 3, "valid choice should advance to round three")
	assert_equal(session.current_round_plan().id, &"round_three", "third plan should bind")
	assert_equal(
		session.current_session.controller.encounter.id,
		&"encounter_three",
		"third encounter should bind"
	)
	assert_equal(
		session.active_restriction().id,
		&"solo_verdict",
		"selected restriction should be active"
	)
	assert_false(
		session.choose_final_restriction(&"three_seats_present").accepted,
		"choice should lock after third round starts"
	)
	_commit_current_round(session)
	assert_equal(
		session.status,
		ThreeRoundEncounterSession.Status.SUCCEEDED,
		"zero target schedule should complete"
	)

func _test_failed_third_round_creation_is_atomic() -> void:
	var rng := RunRng.new(20260727)
	var schedule := _schedule()
	var setup := EncounterRunSetup.new()
	setup.run_rng = rng
	setup.deck_ids = CardCatalog.new().starter_ids()
	setup.round_schedule = schedule
	setup.prepare_shop_offers = false
	var session := ThreeRoundEncounterSession.new(
		CardCatalog.new(),
		20260727,
		0,
		setup
	)
	assert_true(session.start().accepted, "atomic fixture should start")
	_commit_current_round(session)
	assert_true(session.advance_round().accepted, "atomic fixture starts round two")
	_commit_current_round(session)

	var valid_third_encounter := schedule.round_plans[2].encounter
	schedule.round_plans[2].encounter = null
	var rng_before := rng.snapshot_state()
	var hand_before := session.current_hand_ids.duplicate()
	var current_session_before := session.current_session
	assert_false(
		session.choose_final_restriction(&"solo_verdict").accepted,
		"missing third encounter should reject the choice"
	)
	assert_equal(
		session.status,
		ThreeRoundEncounterSession.Status.AWAITING_RESTRICTION,
		"failed creation should restore waiting state"
	)
	assert_equal(session.current_round, 2, "failed creation should restore round number")
	assert_equal(session.current_hand_ids, hand_before, "failed creation should restore hand")
	assert_true(
		session.current_session == current_session_before,
		"failed creation should restore previous round session"
	)
	assert_equal(rng.snapshot_state(), rng_before, "failed creation should restore RNG")

	schedule.round_plans[2].encounter = valid_third_encounter
	assert_true(
		session.choose_final_restriction(&"solo_verdict").accepted,
		"repairing the resource should still allow the third round"
	)
	assert_equal(
		session.current_hand_ids.size(),
		CardDeck.HAND_SIZE,
		"restored deck should still contain the final four cards"
	)

func _test_area_session_delegates_choice_only_during_dealer() -> void:
	var area_session := AreaRunSession.new()
	assert_false(
		area_session.choose_dealer_restriction(&"solo_verdict").accepted,
		"area should reject restriction choice outside dealer phase"
	)

	var setup := EncounterRunSetup.new()
	setup.run_rng = RunRng.new(20260727)
	setup.deck_ids = CardCatalog.new().starter_ids()
	setup.round_schedule = _schedule()
	setup.prepare_shop_offers = false
	var encounter_session := ThreeRoundEncounterSession.new(
		CardCatalog.new(),
		20260727,
		0,
		setup
	)
	assert_true(encounter_session.start().accepted, "delegate fixture should start")
	_commit_current_round(encounter_session)
	assert_true(encounter_session.advance_round().accepted, "fixture starts round two")
	_commit_current_round(encounter_session)

	area_session.phase = AreaRunSession.Phase.DEALER
	area_session.encounter_session = encounter_session
	assert_true(
		area_session.choose_dealer_restriction(&"three_seats_present").accepted,
		"dealer phase should delegate the public choice"
	)
	assert_equal(
		encounter_session.active_restriction().id,
		&"three_seats_present",
		"delegated choice should reach encounter session"
	)

func _commit_current_round(session: ThreeRoundEncounterSession) -> void:
	var report := session.current_session.commit()
	assert_true(
		session.accept_committed_report(report).accepted,
		"current committed report should be accepted"
	)

func _schedule() -> DealerRoundSchedule:
	var schedule := DealerRoundSchedule.new()
	schedule.round_plans.assign([
		_round_plan(&"round_one", &"encounter_one"),
		_round_plan(&"round_two", &"encounter_two"),
		_round_plan(&"round_three", &"encounter_three"),
	])
	schedule.operation_restriction = _restriction(
		&"solo_verdict",
		FinalRestrictionDefinition.Category.OPERATION,
		FinalRestrictionDefinition.Operation.MAX_REAL_CARDS,
		1
	)
	schedule.distribution_restriction = _restriction(
		&"three_seats_present",
		FinalRestrictionDefinition.Category.DISTRIBUTION,
		FinalRestrictionDefinition.Operation.REQUIRE_ALL_TABLES_OCCUPIED,
		3
	)
	return schedule

func _round_plan(
	plan_id: StringName,
	encounter_id: StringName
) -> EncounterRoundPlan:
	var plan := EncounterRoundPlan.new()
	plan.id = plan_id
	plan.display_name = String(plan_id)
	plan.public_summary = "公开规则"
	plan.encounter = _encounter(encounter_id)
	return plan

func _restriction(
	restriction_id: StringName,
	category: int,
	operation: int,
	amount: int
) -> FinalRestrictionDefinition:
	var restriction := FinalRestrictionDefinition.new()
	restriction.id = restriction_id
	restriction.display_name = String(restriction_id)
	restriction.rule_text = "公开限制"
	restriction.category = category
	restriction.operation = operation
	restriction.amount = amount
	return restriction

func _encounter(encounter_id: StringName) -> EncounterDefinition:
	var encounter := EncounterDefinition.new()
	encounter.id = encounter_id
	encounter.rules = [
		_rule(&"left", 7),
		_rule(&"middle", 8),
		_rule(&"right", 9),
	]
	return encounter

func _rule(rule_id: StringName, target: int) -> RuleDefinition:
	var rule := RuleDefinition.new()
	rule.id = rule_id
	rule.display_name = "精确为 %d" % target
	rule.slot_count = 2
	rule.target_value = target
	rule.coefficient = 2
	return rule
