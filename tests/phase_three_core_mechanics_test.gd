extends "res://tests/test_case.gd"

const SuitRules = preload("res://scripts/cards/card_suit_rules.gd")
const SetResolver = preload("res://scripts/engravings/engraving_set_resolver.gd")

func run() -> void:
	_test_area_passive_caps_and_round_boundary()
	_test_free_refresh_token_is_consumed_without_refund()
	_test_fault_die_persists_and_blocks_changes()
	_test_all_in_only_copies_card_intel()
	_test_discard_cards_and_rank_conversion_are_undoable()
	_test_burned_rewrite_uses_card_ledger_without_bridge_count()
	_test_suit_semantics_audit()
	_test_all_engraving_set_families_and_states()

func _test_area_passive_caps_and_round_boundary() -> void:
	var passive := AreaPassiveState.new()
	var encounter := EncounterDefinition.new()
	var rule := _exact_rule(&"left", 1, 1)
	var template := RuleTableTemplate.new()
	template.id = &"phase3_point"
	template.display_name = "点数测试"
	template.category = RuleTableTemplate.Category.POINT
	template.condition_kind = RuleTableTemplate.ConditionKind.EXACT_SUM
	rule.template = template
	encounter.rules = [rule]
	var report := ResolutionReport.new()
	for _index in range(5):
		passive.record_gold_report(encounter, report)
	assert_equal(
		passive.coefficient_bonus(RuleTableTemplate.Category.POINT),
		3,
		"gold passive should cap each category at plus three"
	)
	assert_equal(passive.apply_faceless_failures(2, true), 2, "two failed tables grant two relief")
	assert_equal(passive.apply_faceless_failures(2, true), 1, "encounter relief caps at three")
	assert_equal(passive.apply_faceless_failures(3, false), 0, "last round failures grant no relief")
	passive.begin_encounter(&"faceless_hub")
	assert_equal(passive.faceless_target_relief, 0, "new encounter resets faceless relief")
	assert_true(passive.award_mirror_refresh(), "first mirror token should be granted")
	assert_true(passive.award_mirror_refresh(), "second mirror token should be granted")
	assert_false(passive.award_mirror_refresh(), "mirror token cap should be two")
	var restored := AreaPassiveState.new()
	assert_true(restored.restore_snapshot(passive.to_snapshot()).accepted, "passive snapshot restores")
	assert_equal(restored.mirror_refresh_tokens, 2, "passive snapshot preserves tokens")

func _test_free_refresh_token_is_consumed_without_refund() -> void:
	var catalog := CardCatalog.new()
	var shop := ShopSession.new(
		catalog,
		catalog.starter_ids(),
		catalog.shop_ids(),
		0,
		ShopIntelSnapshot.routes([&"gold_room_narrow_ledger", &"gold_room_parallel_proof"]),
		0,
		true,
		0,
		true,
		0,
		1
	)
	assert_equal(shop.refresh_price(), 0, "free refresh token takes priority")
	assert_true(shop.refresh_offers().accepted, "free refresh should work without intel")
	assert_equal(shop.free_refresh_tokens, 0, "successful refresh consumes the token")
	assert_equal(shop.intel_tickets, 0, "free refresh never charges or refunds intel")
	var restored := ShopSession.from_snapshot(catalog, shop.to_snapshot())
	assert_true(restored.accepted, "shop with consumed token should restore")
	assert_equal(restored.session.free_refresh_tokens, 0, "consumed token stays consumed")

func _test_fault_die_persists_and_blocks_changes() -> void:
	var catalog := CardCatalog.new()
	var state := _state([6, 2])
	state.calibration_points = 2
	state.assignments = {&"left": [&"d1"]}
	var controller := RoundController.new(state, _encounter([1]))
	assert_true(
		controller.play_card(PlayedCard.new(catalog.find_card(&"stage7_fault_die"), &"d1")).accepted,
		"fault die should play on a healthy die"
	)
	assert_true(controller.state.find_die(&"d1").faulted, "fault flag should persist in state")
	assert_equal(controller.preview().effective_die_values[&"d1"], 1, "fault forces final value one")
	assert_equal(controller.preview().effective_table_coefficients[&"left"], 4, "fault adds three coefficient")
	assert_false(controller.adjust_die(&"d1", 1).accepted, "fault blocks calibration")
	assert_false(controller.apply_paid_reroll(&"d1", 4).accepted, "fault blocks paid reroll")
	var swap := catalog.find_card(&"faceless_swap_values")
	assert_false(
		controller.play_card(PlayedCard.new(swap, &"d1", &"d2")).accepted,
		"fault blocks swap targeting the die"
	)
	assert_true(controller.undo(), "fault card can be undone before round submission")
	assert_false(controller.state.find_die(&"d1").faulted, "undo removes uncommitted fault")

func _test_all_in_only_copies_card_intel() -> void:
	var catalog := CardCatalog.new()
	var state := _state([1, 1, 1])
	state.assignments = {&"left": [&"d1"], &"middle": [&"d2"], &"right": [&"d3"]}
	state.played_cards = [
		PlayedCard.new(catalog.find_card(&"stage7_all_in")),
		PlayedCard.new(catalog.find_card(&"faceless_complete_dossier")),
	]
	var report := RoundResolver.new().resolve(state, _encounter([1, 1, 1]))
	assert_true(report.all_in_awarded, "all-in triggers on a full clear")
	assert_equal(report.all_in_bonus_intel, 3, "only the card-produced three intel is copied")
	assert_equal(report.intel_delta, 6, "card intel plus its copy should total six")
	var guard_state := _state([1])
	guard_state.calibration_points = 0
	assert_false(
		CardRules.play_card(guard_state, PlayedCard.new(catalog.find_card(&"stage7_all_in"))).accepted,
		"all-in requires calibration to wager"
	)

func _test_discard_cards_and_rank_conversion_are_undoable() -> void:
	var catalog := CardCatalog.new()
	var state := _state([1])
	var encounter := _encounter([1])
	var hand: Array[CardDefinition] = [
		catalog.find_card(&"stage7_insurance_draft"),
		catalog.find_card(&"starter_nudge_up_1"),
		catalog.find_card(&"starter_nudge_down_1"),
	]
	var session := SingleEncounterSession.new(
		state, encounter, hand, null, null, [], true, RoundController.UndoMode.SPLIT
	)
	assert_true(session.play_card_with_discards(0, &"", [1]), "insurance should discard one unused card")
	assert_equal(session.controller.state.extra_card_undos, 1, "insurance adds a card undo")
	assert_true(&"starter_nudge_up_1" in session.controller.state.discarded_card_ids, "discard is recorded")
	assert_true(session.undo(), "insurance action should undo atomically")
	assert_true(session.controller.state.discarded_card_ids.is_empty(), "undo restores the discarded card")

	var numeric_hand: Array[CardDefinition] = [catalog.find_card(&"starter_nudge_down_2")]
	var conversion := SingleEncounterSession.new(
		_state([1]), encounter, numeric_hand, null, null, [], true, RoundController.UndoMode.SPLIT
	)
	assert_true(conversion.convert_rank_card_to_calibration(0), "numeric card can become calibration")
	assert_equal(conversion.controller.state.calibration_points, 3, "rank three grants one calibration")
	assert_true(conversion.undo(), "rank conversion is a card-stack action")
	assert_equal(conversion.controller.state.calibration_points, 2, "undo removes converted calibration")
	assert_true(conversion.controller.state.discarded_card_ids.is_empty(), "undo restores converted card")
	var fixed := SingleEncounterSession.new(_state([1]), encounter, numeric_hand, null, null, [], true, RoundController.UndoMode.SPLIT, false, false)
	assert_false(fixed.convert_rank_card_to_calibration(0), "fixed-hand puzzle blocks conversion")

func _test_burned_rewrite_uses_card_ledger_without_bridge_count() -> void:
	var catalog := CardCatalog.new()
	var state := _state([2])
	state.assignments = {&"left": [&"d1"]}
	var rewrite := PlayedCard.new(catalog.find_card(&"stage7_burned_rewrite"), &"left")
	rewrite.discarded_card_ids = [&"discard_a", &"discard_b"]
	state.played_cards = [rewrite]
	var encounter := _encounter([2])
	encounter.rules[0].coefficient = 3
	var report := RoundResolver.new().resolve(state, encounter)
	assert_equal(report.score_breakdown[ResolutionEvent.ScoreSource.CARD], 4, "rewrite uses coefficient two in card ledger")
	assert_equal(report.successful_bridge_count, 0, "rewrite never counts as a bridge")
	assert_true(report.events.any(func(event: ResolutionEvent) -> bool: return event.combo_kind == &"rewrite"), "rewrite is traceable")

func _test_suit_semantics_audit() -> void:
	var catalog := CardCatalog.new()
	for card in catalog.all_cards():
		assert_equal(SuitRules.validation_error(card), "", "%s should match suit semantics" % card.id)
	assert_equal(SuitRules.rank_calibration_value("1"), 1, "rank one converts to one")
	assert_equal(SuitRules.rank_calibration_value("6"), 2, "rank six converts to two")
	assert_equal(SuitRules.rank_calibration_value("10"), 3, "rank ten converts to three")
	assert_equal(SuitRules.rank_calibration_value("J"), 0, "face cards cannot convert")

func _test_all_engraving_set_families_and_states() -> void:
	var resolver = SetResolver.new()
	var catalog := EngravingCatalog.new()
	var pairs := {
		resolver.ECHO: [&"engraving_echo", &"engraving_afterimage"],
		resolver.ANCHOR: [&"engraving_anchor", &"engraving_silver_anchor"],
		resolver.BRIDGE: [&"engraving_bridge", &"engraving_backflow_bridge"],
		resolver.PRISM: [&"engraving_prism", &"engraving_mirror_prism"],
	}
	for family in pairs:
		var state := _state([1, 1])
		state.dice[0].engraving_id = pairs[family][0]
		state.dice[0].engraved_face = 1
		state.dice[1].engraving_id = pairs[family][1]
		state.dice[1].engraved_face = 1
		state.assignments = {&"left": [&"d1"], &"middle": [&"d2"]}
		var states := resolver.family_states(state.dice, catalog, [family])
		assert_equal(states[family]["copy"], "已激活", "%s set exposes activated state" % family)
		var report := ResolutionReport.new()
		var first := ResolutionEvent.new(pairs[family][0], "trigger", 0, 0, true)
		first.source_die_id = &"d1"
		report.events.append(first)
		if family == resolver.PRISM:
			var second := ResolutionEvent.new(pairs[family][1], "trigger", 0, 0, true)
			second.source_die_id = &"d2"
			report.events.append(second)
		var outcomes := resolver.bonus_outcomes(
			state,
			report,
			{&"left": true, &"middle": true},
			ResolutionContext.new(null, catalog)
		)
		assert_equal(outcomes.size(), 1, "%s set should emit one bonus" % family)
		if not outcomes.is_empty():
			assert_equal(outcomes[0].target_table_id, &"", "set bonus must not increment bridge count")

func _state(values: Array[int]) -> RoundState:
	var state := RoundState.new()
	for index in values.size():
		state.dice.append(DieState.new(StringName("d%d" % (index + 1)), values[index]))
	return state

func _encounter(targets: Array[int]) -> EncounterDefinition:
	var encounter := EncounterDefinition.new()
	var ids: Array[StringName] = [&"left", &"middle", &"right"]
	for index in targets.size():
		encounter.rules.append(_exact_rule(ids[index], 1, targets[index]))
	return encounter

func _exact_rule(id: StringName, slots: int, target: int) -> RuleDefinition:
	var rule := RuleDefinition.new()
	rule.id = id
	rule.display_name = String(id)
	rule.condition_type = RuleDefinition.ConditionType.EXACT_SUM
	rule.slot_count = slots
	rule.target_value = target
	rule.coefficient = 1
	return rule
