extends "res://tests/test_case.gd"

func run() -> void:
	_test_all_intel_conditions_preview_success_and_failure()
	_test_committed_reports_credit_intel_once()

func _test_all_intel_conditions_preview_success_and_failure() -> void:
	var conditions := [
		EffectSpec.IntelCondition.TARGET_TABLE_PASSED,
		EffectSpec.IntelCondition.ALL_DICE_ASSIGNED,
		EffectSpec.IntelCondition.ALL_TABLES_OCCUPIED,
		EffectSpec.IntelCondition.ALL_TABLES_PASSED,
	]
	for condition in conditions:
		var success_state := _state(true, true)
		var success := RoundController.new(success_state, _encounter(true))
		var card := _intel_card(condition)
		assert_true(
			success.play_card(PlayedCard.new(
				card,
				&"left" if condition == EffectSpec.IntelCondition.TARGET_TABLE_PASSED else &""
			)).accepted,
			"intel condition %d should play" % condition
		)
		var preview := success.preview()
		assert_equal(preview.intel_delta, 2, "satisfied condition previews intel")
		assert_true(
			_has_intel_event(preview, card.id, true),
			"satisfied condition creates a visible event"
		)

		var failure_state := _failure_state(condition)
		var failure := RoundController.new(
			failure_state,
			_encounter(
				condition not in [
					EffectSpec.IntelCondition.TARGET_TABLE_PASSED,
					EffectSpec.IntelCondition.ALL_TABLES_PASSED,
				]
			)
		)
		assert_true(
			failure.play_card(PlayedCard.new(
				card,
				&"right" if condition == EffectSpec.IntelCondition.TARGET_TABLE_PASSED else &""
			)).accepted,
			"unsatisfied intel card still plays"
		)
		var failed_preview := failure.preview()
		assert_equal(failed_preview.intel_delta, 0, "unsatisfied condition grants zero")
		assert_true(
			_has_intel_event(failed_preview, card.id, false),
			"unsatisfied condition creates a visible failed event"
		)

func _test_committed_reports_credit_intel_once() -> void:
	var setup := EncounterRunSetup.new()
	setup.deck_ids = CardCatalog.new().starter_ids()
	setup.encounter = SingleEncounterFixture.make_encounter()
	setup.success_intel_reward = 3
	setup.prepare_shop_offers = false
	var session := ThreeRoundEncounterSession.new(
		CardCatalog.new(),
		20260727,
		0,
		setup
	)
	assert_true(session.start().accepted, "intel credit fixture should start")
	for round_index in range(3):
		var report := session.current_session.commit()
		report.intel_delta = 2
		assert_true(
			session.accept_committed_report(report).accepted,
			"committed report should be accepted once"
		)
		assert_false(
			session.accept_committed_report(report).accepted,
			"same committed report must not credit twice"
		)
		if round_index < 2:
			assert_true(session.advance_round().accepted, "advance intel fixture")
	assert_equal(session.earned_intel_tickets, 6, "three reports accumulate intel")
	assert_equal(session.intel_tickets, 9, "success reward includes earned intel")

func _state(assign_all: bool, occupy_all: bool) -> RoundState:
	var state := RoundState.new()
	for value in range(1, 7):
		state.dice.append(DieState.new(StringName("d%d" % value), value))
	state.assignments = {
		&"left": [&"d1", &"d6"],
		&"middle": [&"d2", &"d5"],
		&"right": [&"d3", &"d4"],
	}
	if not assign_all:
		state.assignments[&"right"] = [&"d3"]
	if not occupy_all:
		state.assignments[&"right"] = []
	return state

func _failure_state(condition: EffectSpec.IntelCondition) -> RoundState:
	match condition:
		EffectSpec.IntelCondition.TARGET_TABLE_PASSED:
			return _state(true, true)
		EffectSpec.IntelCondition.ALL_DICE_ASSIGNED:
			return _state(false, true)
		EffectSpec.IntelCondition.ALL_TABLES_OCCUPIED:
			return _state(false, false)
		EffectSpec.IntelCondition.ALL_TABLES_PASSED:
			return _state(true, true)
	return _state(true, true)

func _encounter(all_pass: bool) -> EncounterDefinition:
	var encounter := EncounterDefinition.new()
	encounter.id = &"intel_fixture"
	var targets := [7, 7, 7 if all_pass else 8]
	var ids: Array[StringName] = [&"left", &"middle", &"right"]
	for index in range(3):
		var rule := RuleDefinition.new()
		rule.id = ids[index]
		rule.display_name = String(ids[index])
		rule.slot_count = 2
		rule.target_value = targets[index]
		rule.coefficient = 1
		encounter.rules.append(rule)
	return encounter

func _intel_card(condition: EffectSpec.IntelCondition) -> CardDefinition:
	var effect := EffectSpec.new()
	effect.operation = EffectSpec.Operation.GRANT_INTEL_ON_CONDITION
	effect.intel_condition = condition
	effect.amount = 2
	var card := CardDefinition.new()
	card.id = StringName("intel_%d" % condition)
	card.display_name = String(card.id)
	card.rule_text = "满足公开条件后获得情报。"
	card.tags = PackedStringArray(["情报"])
	card.target_type = (
		CardDefinition.TargetType.TABLE
		if condition == EffectSpec.IntelCondition.TARGET_TABLE_PASSED
		else CardDefinition.TargetType.GLOBAL
	)
	card.suit = CardDefinition.Suit.DIAMONDS
	card.rank_label = "测试"
	card.rarity = CardDefinition.Rarity.COMMON
	card.effects = [effect]
	return card

func _has_intel_event(
	report: ResolutionReport,
	source_id: StringName,
	applied: bool
) -> bool:
	for event in report.events:
		if event.source_id == source_id and event.effect_applied == applied:
			return true
	return false
