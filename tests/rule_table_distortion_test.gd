extends "res://tests/test_case.gd"

const ECHO = preload("res://resources/rules/templates/rule_echo_table.tres")
const REVERSE = preload("res://resources/rules/templates/rule_reverse_table.tres")
const BRIDGE = preload("res://resources/rules/templates/rule_bridge_table.tres")

func run() -> void:
	_test_intrinsic_effect_order_and_non_recursive_copy()
	_test_reverse_parity_with_card()
	_test_multiple_reverse_tables_use_parity()
	_test_inactive_effect_events()
	_test_bridge_placement_validation()
	_test_preview_commit_equivalence()

func _test_intrinsic_effect_order_and_non_recursive_copy() -> void:
	var encounter := _encounter(ECHO, BRIDGE, REVERSE)
	var state := _filled_state()
	state.played_cards = [_repeat_card(&"left")]
	var report := RoundResolver.new().resolve(state, encounter)
	assert_equal(
		report.resolution_direction,
		EncounterRuleProfile.ResolutionDirection.RIGHT_TO_LEFT,
		"a passing reverse table should determine direction before scoring"
	)
	assert_equal(
		report.ordered_rule_ids,
		[&"right", &"middle", &"left"],
		"final rule order should follow the intrinsic reverse"
	)
	assert_equal(report.total, 43, "echo and bridge should copy only one base score")
	assert_equal(
		_deltas(report, &"left"),
		[6, 6],
		"card repeat should remain on the table source"
	)
	assert_equal(
		_deltas(report, ECHO.id),
		[6],
		"echo should create one distinct intrinsic event"
	)
	assert_equal(
		_deltas(report, BRIDGE.id),
		[7],
		"bridge should copy its own base score once"
	)
	assert_true(
		_event_index(report, BRIDGE.id) > _event_index(report, &"left"),
		"bridge events should be emitted after every base table"
	)

func _test_reverse_parity_with_card() -> void:
	var encounter := _encounter(ECHO, BRIDGE, REVERSE)
	var state := _filled_state()
	state.played_cards = [_reverse_card()]
	var report := RoundResolver.new().resolve(state, encounter)
	assert_equal(
		report.resolution_direction,
		EncounterRuleProfile.ResolutionDirection.LEFT_TO_RIGHT,
		"one card reverse plus one reverse table should cancel"
	)
	assert_equal(
		report.ordered_rule_ids,
		[&"left", &"middle", &"right"],
		"cancelled reversals should restore left-to-right order"
	)

func _test_multiple_reverse_tables_use_parity() -> void:
	var report := RoundResolver.new().resolve(
		_filled_state(),
		_encounter(REVERSE, BRIDGE, REVERSE)
	)
	assert_equal(
		report.resolution_direction,
		EncounterRuleProfile.ResolutionDirection.LEFT_TO_RIGHT,
		"two passing reverse tables should cancel by parity"
	)

func _test_inactive_effect_events() -> void:
	var encounter := _encounter(ECHO, BRIDGE, REVERSE)
	var state := _filled_state()
	state.assignments[&"right"] = [&"d5", &""]
	var report := RoundResolver.new().resolve(state, encounter)
	assert_equal(
		report.resolution_direction,
		EncounterRuleProfile.ResolutionDirection.LEFT_TO_RIGHT,
		"an unfilled reverse table must not change direction"
	)
	assert_equal(
		_deltas(report, REVERSE.id),
		[0],
		"inactive reverse should remain visible as a zero event"
	)
	assert_equal(
		_deltas(report, BRIDGE.id),
		[0],
		"bridge should report zero when its final-direction target fails"
	)

	state = _filled_state()
	state.assignments[&"left"] = [&"d1", &""]
	report = RoundResolver.new().resolve(state, encounter)
	assert_equal(
		_deltas(report, ECHO.id),
		[0],
		"an unfilled echo should remain visible as a zero event"
	)

func _test_bridge_placement_validation() -> void:
	var invalid := _encounter(BRIDGE, ECHO, REVERSE)
	var errors := ContentValidator.new().validate(invalid.rules, [])
	assert_true(
		errors.any(
			func(message: String) -> bool: return "bridge template must occupy the middle track" in message
		),
		"content validation should reject a bridge outside the middle track"
	)

func _test_preview_commit_equivalence() -> void:
	var controller := RoundController.new(
		_filled_state(),
		_encounter(ECHO, BRIDGE, REVERSE)
	)
	var preview := controller.preview()
	var committed := controller.commit()
	assert_equal(
		committed.event_signature(),
		preview.event_signature(),
		"distortion preview and commit events should be identical"
	)
	assert_equal(
		committed.resolution_direction,
		preview.resolution_direction,
		"distortion preview and commit direction should be identical"
	)

func _encounter(
	left_template: RuleTableTemplate,
	middle_template: RuleTableTemplate,
	right_template: RuleTableTemplate
) -> EncounterDefinition:
	var encounter := EncounterDefinition.new()
	encounter.rules = [
		_rule(&"left", left_template, 2, 2),
		_rule(&"middle", middle_template, 2, 1),
		_rule(&"right", right_template, 2, 1),
	]
	return encounter

func _rule(
	id: StringName,
	template: RuleTableTemplate,
	slots: int,
	coefficient: int
) -> RuleDefinition:
	var rule := RuleDefinition.new()
	rule.id = id
	rule.display_name = String(id)
	rule.template = template
	rule.slot_count = slots
	rule.coefficient = coefficient
	return rule

func _filled_state() -> RoundState:
	var state := RoundState.new()
	for value in range(1, 7):
		state.dice.append(DieState.new(StringName("d%d" % value), value))
	state.assignments = {
		&"left": [&"d1", &"d2"],
		&"middle": [&"d3", &"d4"],
		&"right": [&"d5", &"d6"],
	}
	return state

func _repeat_card(table_id: StringName) -> PlayedCard:
	var effect := EffectSpec.new()
	effect.operation = EffectSpec.Operation.REPEAT_TABLE
	effect.amount = 1
	var card := CardDefinition.new()
	card.id = &"test_repeat"
	card.display_name = "repeat"
	card.target_type = CardDefinition.TargetType.TABLE
	card.effects = [effect]
	return PlayedCard.new(card, table_id)

func _reverse_card() -> PlayedCard:
	var effect := EffectSpec.new()
	effect.operation = EffectSpec.Operation.REVERSE_RESOLUTION
	var card := CardDefinition.new()
	card.id = &"test_reverse"
	card.display_name = "reverse"
	card.target_type = CardDefinition.TargetType.GLOBAL
	card.effects = [effect]
	return PlayedCard.new(card)

func _deltas(report: ResolutionReport, source_id: StringName) -> Array:
	var result: Array = []
	for event in report.events:
		if event.source_id == source_id:
			result.append(event.delta)
	return result

func _event_index(report: ResolutionReport, source_id: StringName) -> int:
	for index in range(report.events.size()):
		if report.events[index].source_id == source_id:
			return index
	return -1
