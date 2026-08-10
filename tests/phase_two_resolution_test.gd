extends "res://tests/test_case.gd"

func run() -> void:
	_test_lucky_face_uses_final_effective_value()
	_test_all_odd_full_clear_triggers_resonance()
	_test_third_successful_bridge_triggers_one_storm()

func _test_lucky_face_uses_final_effective_value() -> void:
	var state := RoundState.new()
	state.dice.append(DieState.new(&"d1", 6, &"", 0, 1))
	state.assignments[&"left"] = [&"d1"]
	var encounter := EncounterDefinition.new()
	encounter.rules = [_exact_rule(&"left", 1, 6)]
	var context := ResolutionContext.new(null, null, &"", {&"d1": 6})
	var report := RoundResolver.new().resolve(state, encounter, context)
	assert_true(
		report.events.any(func(event: ResolutionEvent) -> bool: return event.source_id == &"lucky_critical"),
		"calibrated final value should hit its lucky face"
	)

func _test_all_odd_full_clear_triggers_resonance() -> void:
	var state := RoundState.new()
	var encounter := EncounterDefinition.new()
	for table_index in range(3):
		var table_id := StringName(["left", "middle", "right"][table_index])
		encounter.rules.append(_exact_rule(table_id, 2, 2))
		state.assignments[table_id] = []
		for die_offset in range(2):
			var die_id := StringName("d%d" % (table_index * 2 + die_offset + 1))
			state.dice.append(DieState.new(die_id, 1))
			state.assignments[table_id].append(die_id)
	var report := RoundResolver.new().resolve(state, encounter)
	assert_true(report.resonance_awarded, "all-odd full clear should trigger resonance")
	assert_true(report.full_clear_calibration_awarded, "full clear should queue calibration")
	assert_equal(
		report.score_breakdown[ResolutionEvent.ScoreSource.RULE_CHAIN],
		3,
		"resonance should add half of six base points"
	)

func _test_third_successful_bridge_triggers_one_storm() -> void:
	var state := RoundState.new()
	var encounter := EncounterDefinition.new()
	for table_index in range(3):
		var table_id := StringName(["left", "middle", "right"][table_index])
		encounter.rules.append(_exact_rule(table_id, 1, 1))
		var die_id := StringName("d%d" % (table_index + 1))
		state.dice.append(DieState.new(die_id, 1))
		state.assignments[table_id] = [die_id]
	state.played_cards = [
		_bridge_card(&"bridge_a", &"left", &"middle"),
		_bridge_card(&"bridge_b", &"left", &"right"),
		_bridge_card(&"bridge_c", &"middle", &"right"),
	]
	var report := RoundResolver.new().resolve(state, encounter)
	assert_equal(report.successful_bridge_count, 3, "all three transfers should count")
	assert_true(report.storm_awarded, "third successful bridge should trigger storm")
	assert_equal(
		report.events.filter(func(event: ResolutionEvent) -> bool: return event.combo_kind == &"storm").size(),
		1,
		"storm should trigger at most once"
	)

func _exact_rule(id: StringName, slots: int, target: int) -> RuleDefinition:
	var rule := RuleDefinition.new()
	rule.id = id
	rule.display_name = String(id)
	rule.condition_type = RuleDefinition.ConditionType.EXACT_SUM
	rule.slot_count = slots
	rule.target_value = target
	rule.coefficient = 1
	return rule

func _bridge_card(id: StringName, source: StringName, target: StringName) -> PlayedCard:
	var effect := EffectSpec.new()
	effect.operation = EffectSpec.Operation.LINK_NEIGHBORS
	var card := CardDefinition.new()
	card.id = id
	card.display_name = String(id)
	card.target_type = CardDefinition.TargetType.GAP
	card.effects = [effect]
	return PlayedCard.new(card, source, target)
