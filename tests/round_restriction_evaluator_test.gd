extends "res://tests/test_case.gd"

func run() -> void:
	_test_real_card_limit_ignores_mirror_copies()
	_test_distribution_reports_specific_missing_tables()
	_test_controller_enforces_operation_limit_and_undo()
	_test_controller_previews_and_rejects_incomplete_distribution()

func _test_real_card_limit_ignores_mirror_copies() -> void:
	var evaluator := RoundRestrictionEvaluator.new()
	var restriction := _card_limit()
	var state := _state()
	assert_true(
		evaluator.validate_card_play(state, restriction).accepted,
		"empty state should accept first real card"
	)

	var mirror := PlayedCard.new(_card(&"mirror"), &"left")
	mirror.is_mirror_copy = true
	state.played_cards.append(mirror)
	assert_true(
		evaluator.validate_card_play(state, restriction).accepted,
		"mirror copy should not consume the real-card limit"
	)

	state.played_cards.append(PlayedCard.new(_card(&"real"), &"left"))
	var blocked := evaluator.validate_card_play(state, restriction)
	assert_false(blocked.accepted, "one real card should reach the limit")
	assert_true(
		"最多使用 1 张真实手法牌" in blocked.reason,
		"card-limit error should expose the public amount"
	)

func _test_distribution_reports_specific_missing_tables() -> void:
	var evaluator := RoundRestrictionEvaluator.new()
	var state := _state()
	state.assignments[&"left"] = [&"d1"]
	var restriction := _three_seats()
	var result := evaluator.evaluate_commit(state, _encounter(), restriction)
	assert_false(result.accepted, "missing tables should reject commit")
	assert_true("中间规则台" in result.reason, "reason should name middle table")
	assert_true("右侧规则台" in result.reason, "reason should name right table")
	assert_equal(
		evaluator.coverage_copy(state, _encounter()),
		"已覆盖 1/3 张规则台",
		"coverage should remain player-readable"
	)

	state.assignments[&"middle"] = [&"d2"]
	state.assignments[&"right"] = [&"d3"]
	assert_true(
		evaluator.evaluate_commit(state, _encounter(), restriction).accepted,
		"all occupied tables should satisfy distribution restriction"
	)

func _test_controller_enforces_operation_limit_and_undo() -> void:
	var controller := RoundController.new(
		_state(),
		_encounter(),
		null,
		_card_limit()
	)
	assert_true(
		controller.play_card(PlayedCard.new(_card(&"first"), &"left")).accepted,
		"first real card should be accepted"
	)
	var blocked := controller.play_card(
		PlayedCard.new(_card(&"second"), &"middle")
	)
	assert_false(blocked.accepted, "second real card should be blocked")
	assert_equal(
		controller.state.played_cards.size(),
		1,
		"blocked play should not mutate state"
	)
	assert_true(controller.undo(), "first card should remain undoable")
	assert_true(
		controller.play_card(PlayedCard.new(_card(&"second"), &"middle")).accepted,
		"undo should restore the one-card allowance"
	)

func _test_controller_previews_and_rejects_incomplete_distribution() -> void:
	var controller := RoundController.new(
		_state(),
		_encounter(),
		null,
		_three_seats()
	)
	assert_true(controller.assign_die(&"d1", &"left", 2).accepted, "assign left")
	var preview := controller.preview()
	assert_true(preview.valid, "incomplete preview should remain adjustable")
	assert_false(
		preview.restriction_satisfied,
		"preview should expose incomplete restriction"
	)
	assert_true("中间规则台" in preview.restriction_reason, "preview names missing lane")

	var rejected := controller.commit()
	assert_false(rejected.valid, "incomplete distribution should reject commit")
	assert_false(controller.committed, "rejected commit should not lock controller")
	assert_equal(
		controller.state.assignments[&"left"],
		[&"d1"],
		"rejected commit should preserve current assignments"
	)

	assert_true(controller.assign_die(&"d2", &"middle", 2).accepted, "assign middle")
	assert_true(controller.assign_die(&"d3", &"right", 2).accepted, "assign right")
	var ready_preview := controller.preview()
	assert_true(ready_preview.restriction_satisfied, "complete preview should satisfy")
	var committed := controller.commit()
	assert_true(committed.valid, "complete distribution should commit")
	assert_true(controller.committed, "accepted commit should lock controller")
	assert_equal(
		committed.event_signature(),
		ready_preview.event_signature(),
		"restriction should not create preview/commit event drift"
	)

func _card_limit() -> FinalRestrictionDefinition:
	var restriction := FinalRestrictionDefinition.new()
	restriction.id = &"solo_verdict"
	restriction.display_name = "独手裁决"
	restriction.rule_text = "本轮最多使用一张真实手法牌。"
	restriction.category = FinalRestrictionDefinition.Category.OPERATION
	restriction.operation = FinalRestrictionDefinition.Operation.MAX_REAL_CARDS
	restriction.amount = 1
	return restriction

func _three_seats() -> FinalRestrictionDefinition:
	var restriction := FinalRestrictionDefinition.new()
	restriction.id = &"three_seats_present"
	restriction.display_name = "三席到场"
	restriction.rule_text = "三张规则台都必须至少分配一颗骰子。"
	restriction.category = FinalRestrictionDefinition.Category.DISTRIBUTION
	restriction.operation = (
		FinalRestrictionDefinition.Operation.REQUIRE_ALL_TABLES_OCCUPIED
	)
	restriction.amount = 3
	return restriction

func _state() -> RoundState:
	var state := RoundState.new()
	for value in range(1, 7):
		state.dice.append(DieState.new(StringName("d%d" % value), value))
	return state

func _encounter() -> EncounterDefinition:
	var encounter := EncounterDefinition.new()
	encounter.id = &"restriction_fixture"
	encounter.rules = [
		_rule(&"left", 7),
		_rule(&"middle", 8),
		_rule(&"right", 9),
	]
	return encounter

func _rule(rule_id: StringName, target: int) -> RuleDefinition:
	var rule := RuleDefinition.new()
	rule.id = rule_id
	rule.display_name = String(rule_id)
	rule.slot_count = 2
	rule.target_value = target
	rule.coefficient = 2
	return rule

func _card(card_id: StringName) -> CardDefinition:
	var effect := EffectSpec.new()
	effect.operation = EffectSpec.Operation.MODIFY_COEFFICIENT
	effect.amount = 1
	var card := CardDefinition.new()
	card.id = card_id
	card.display_name = String(card_id)
	card.target_type = CardDefinition.TargetType.TABLE
	card.effects = [effect]
	return card
