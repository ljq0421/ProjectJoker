extends "res://tests/test_case.gd"

var _engraving_context := ResolutionContext.new(null, EngravingCatalog.new())

func run() -> void:
	_test_dealer_rewards()
	_test_echo()
	_test_anchor_bonus()
	_test_bridge_direction()
	_test_prism()

func _test_dealer_rewards() -> void:
	for assigned_count in range(0, 7):
		var state := _state_with_legal_assignments(assigned_count)
		var report := RoundResolver.new().resolve(
			state,
			SingleEncounterFixture.make_encounter(),
			ResolutionContext.new(DealerCatalog.new().iron_abacus(), null)
		)
		assert_equal(
			report.dealer_reward,
			assigned_count * 2,
			"dealer reward should equal two per assigned die"
		)
		assert_equal(report.assigned_dice, assigned_count, "assigned metric should be public")
		assert_equal(report.unassigned_dice, 6 - assigned_count, "unassigned metric should be public")
		assert_equal(
			report.dealer_reward_lost,
			(6 - assigned_count) * 2,
			"dealer loss should match"
		)
		assert_equal(
			report.events[-1].source_id,
			&"dealer_iron_abacus",
			"dealer event should be last"
		)
		assert_equal(
			report.events[-1].delta,
			assigned_count * 2,
			"dealer event should expose exact reward"
		)

func _test_echo() -> void:
	var both := _state([
		DieState.new(&"d1", 3),
		DieState.new(&"d2", 4, &"engraving_echo", 4),
		DieState.new(&"d3", 5),
	], {&"table": [&"d1", &"d2", &"d3"]})
	var both_report := _resolve_with_commit(
		both,
		_encounter([_rule(&"table", RuleDefinition.ConditionType.EXACT_SUM, 3, 1, 12)])
	)
	_assert_event(both_report, &"engraving_echo", 2, true, "echo should choose higher neighbor")
	assert_equal(both_report.total, 14, "echo should add two after base twelve")

	for ordered_ids in [[&"d1", &"d2"], [&"d2", &"d1"]]:
		var one_side := _state([
			DieState.new(&"d1", 4, &"engraving_echo", 4),
			DieState.new(&"d2", 5),
		], {&"table": ordered_ids})
		var one_side_report := _resolve_with_commit(
			one_side,
			_encounter([_rule(&"table", RuleDefinition.ConditionType.EXACT_SUM, 2, 1, 9)])
		)
		_assert_event(
			one_side_report,
			&"engraving_echo",
			2,
			true,
			"echo should support either neighboring side"
		)

	var floor_zero := _state([
		DieState.new(&"d1", 4, &"engraving_echo", 4),
		DieState.new(&"d2", 1),
	], {&"table": [&"d1", &"d2"]})
	var floor_report := _resolve_with_commit(
		floor_zero,
		_encounter([_rule(&"table", RuleDefinition.ConditionType.EXACT_SUM, 2, 1, 5)])
	)
	_assert_event(floor_report, &"engraving_echo", 0, true, "zero echo can still apply")

	var no_neighbor := _state(
		[DieState.new(&"d1", 4, &"engraving_echo", 4)],
		{&"table": [&"d1"]}
	)
	var no_neighbor_report := _resolve_with_commit(
		no_neighbor,
		_encounter([_rule(&"table", RuleDefinition.ConditionType.ALL_EVEN, 1, 1)])
	)
	_assert_event(
		no_neighbor_report,
		&"engraving_echo",
		0,
		false,
		"echo without a neighbor should be diagnostic"
	)

	var invalid_source := _state([
		DieState.new(&"d1", 4, &"engraving_echo", 4),
		DieState.new(&"d2", 1),
	], {&"table": [&"d1", &"d2"]})
	var invalid_report := _resolve_with_commit(
		invalid_source,
		_encounter([_rule(&"table", RuleDefinition.ConditionType.EXACT_SUM, 2, 1, 6)])
	)
	_assert_event(
		invalid_report,
		&"engraving_echo",
		0,
		false,
		"echo on invalid source should be diagnostic"
	)
	assert_equal(invalid_report.total, 0, "invalid source should add no echo reward")

func _test_anchor_bonus() -> void:
	var active := _state(
		[DieState.new(&"d1", 4, &"engraving_anchor", 4)],
		{&"table": [&"d1"]}
	)
	var active_report := _resolve_with_commit(
		active,
		_encounter([_rule(&"table", RuleDefinition.ConditionType.ALL_EVEN, 1, 1)])
	)
	_assert_event(active_report, &"engraving_anchor", 4, true, "anchor should add four")
	assert_equal(active_report.total, 8, "anchor should add four after base four")

	var inactive := _state(
		[DieState.new(&"d1", 4, &"engraving_anchor", 4, 3)],
		{&"table": [&"d1"]}
	)
	var inactive_report := _resolve_with_commit(
		inactive,
		_encounter([_rule(&"table", RuleDefinition.ConditionType.ALL_EVEN, 1, 1)])
	)
	_assert_no_event(inactive_report, &"engraving_anchor", "inactive anchor should not resolve")
	assert_equal(inactive_report.total, 4, "inactive anchor should not change scoring")

func _test_bridge_direction() -> void:
	var forward := _state([
		DieState.new(&"d1", 4, &"engraving_bridge", 4),
		DieState.new(&"d2", 2),
	], {&"left": [&"d1"], &"right": [&"d2"]})
	var two_tables := _encounter([
		_rule(&"left", RuleDefinition.ConditionType.ALL_EVEN, 1, 1),
		_rule(&"right", RuleDefinition.ConditionType.ALL_EVEN, 1, 1),
	])
	var forward_report := _resolve_with_commit(forward, two_tables)
	_assert_event(forward_report, &"engraving_bridge", 4, true, "bridge should move forward")
	assert_equal(forward_report.total, 10, "forward bridge should add effective die value")

	var reverse := _state([
		DieState.new(&"d1", 2),
		DieState.new(&"d2", 4, &"engraving_bridge", 4),
	], {&"left": [&"d1"], &"right": [&"d2"]})
	reverse.played_cards = [PlayedCard.new(SingleEncounterFixture.make_hand()[3])]
	var reverse_report := _resolve_with_commit(reverse, two_tables)
	_assert_event(reverse_report, &"engraving_bridge", 4, true, "bridge should follow reverse order")
	assert_equal(reverse_report.total, 10, "reverse bridge should add effective die value")

	var no_next := _state(
		[DieState.new(&"d1", 4, &"engraving_bridge", 4)],
		{&"only": [&"d1"]}
	)
	var no_next_report := _resolve_with_commit(
		no_next,
		_encounter([_rule(&"only", RuleDefinition.ConditionType.ALL_EVEN, 1, 1)])
	)
	_assert_event(no_next_report, &"engraving_bridge", 0, false, "last table has no target")

	var invalid_target := _state([
		DieState.new(&"d1", 4, &"engraving_bridge", 4),
		DieState.new(&"d2", 3),
	], {&"left": [&"d1"], &"right": [&"d2"]})
	var invalid_target_report := _resolve_with_commit(invalid_target, two_tables)
	_assert_event(
		invalid_target_report,
		&"engraving_bridge",
		0,
		false,
		"invalid destination should reject bridge"
	)
	assert_equal(invalid_target_report.total, 4, "invalid destination should add no bridge reward")

func _test_prism() -> void:
	var odd := _state(
		[DieState.new(&"d1", 3, &"engraving_prism", 3)],
		{&"table": [&"d1"]}
	)
	var even_rule := _encounter([
		_rule(&"table", RuleDefinition.ConditionType.ALL_EVEN, 1, 1),
	])
	var odd_report := _resolve_with_commit(odd, even_rule)
	_assert_event(odd_report, &"engraving_prism", 0, true, "odd prism should apply")
	assert_equal(odd_report.total, 3, "prism should preserve numeric value")

	var even := _state(
		[DieState.new(&"d1", 4, &"engraving_prism", 4)],
		{&"table": [&"d1"]}
	)
	var even_report := _resolve_with_commit(even, even_rule)
	_assert_event(even_report, &"engraving_prism", 0, true, "even prism should still report")
	assert_equal(even_report.total, 4, "even prism should preserve normal score")

	var exact_report := _resolve_with_commit(
		odd,
		_encounter([_rule(&"table", RuleDefinition.ConditionType.EXACT_SUM, 1, 2, 3)])
	)
	assert_equal(exact_report.total, 6, "prism should not change exact-sum scoring")

	var inactive := _state(
		[DieState.new(&"d1", 3, &"engraving_prism", 3, 2)],
		{&"table": [&"d1"]}
	)
	var inactive_report := _resolve_with_commit(inactive, even_rule)
	_assert_no_event(inactive_report, &"engraving_prism", "inactive prism should not resolve")
	assert_equal(inactive_report.total, 0, "inactive prism should not make odd die even")

func _resolve_with_commit(state: RoundState, encounter: EncounterDefinition) -> ResolutionReport:
	var controller := RoundController.new(state, encounter, _engraving_context)
	var preview := controller.preview()
	var committed := controller.commit()
	assert_equal(committed.total, preview.total, "preview and commit totals should match")
	assert_equal(
		committed.event_signature(),
		preview.event_signature(),
		"preview and commit event signatures should match"
	)
	return committed

func _state(dice: Array[DieState], assignments: Dictionary) -> RoundState:
	var state := RoundState.new()
	state.dice = dice
	state.assignments = assignments
	return state

func _state_with_legal_assignments(assigned_count: int) -> RoundState:
	var state := SingleEncounterFixture.make_state()
	var table_ids := [&"left", &"left", &"middle", &"middle", &"middle", &"right"]
	for index in range(assigned_count):
		var table_id: StringName = table_ids[index]
		if not state.assignments.has(table_id):
			state.assignments[table_id] = []
		state.assignments[table_id].append(StringName("d%d" % (index + 1)))
	return state

func _encounter(rules: Array[RuleDefinition]) -> EncounterDefinition:
	var encounter := EncounterDefinition.new()
	encounter.id = &"engraving_test"
	encounter.rules = rules
	return encounter

func _rule(
	id: StringName,
	condition: RuleDefinition.ConditionType,
	slots: int,
	coefficient: int,
	target: int = 0
) -> RuleDefinition:
	var rule := RuleDefinition.new()
	rule.id = id
	rule.display_name = String(id)
	rule.condition_type = condition
	rule.slot_count = slots
	rule.coefficient = coefficient
	rule.target_value = target
	return rule

func _assert_event(
	report: ResolutionReport,
	source_id: StringName,
	delta: int,
	applied: bool,
	message: String
) -> void:
	var matching := report.events.filter(
		func(event: ResolutionEvent) -> bool: return event.source_id == source_id
	)
	assert_true(not matching.is_empty(), "%s: expected event" % message)
	if not matching.is_empty():
		var event: ResolutionEvent = matching[-1]
		assert_equal(event.delta, delta, "%s: delta" % message)
		assert_equal(event.effect_applied, applied, "%s: applied state" % message)

func _assert_no_event(
	report: ResolutionReport,
	source_id: StringName,
	message: String
) -> void:
	assert_false(
		report.events.any(
			func(event: ResolutionEvent) -> bool: return event.source_id == source_id
		),
		message
	)
