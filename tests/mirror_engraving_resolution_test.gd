extends "res://tests/test_case.gd"

func run() -> void:
	_test_backflow_targets_previous_rule()
	_test_backflow_without_previous_rule_is_diagnostic()
	_test_backflow_applies_after_previous_rule_resolved()
	_test_mirror_prism_requires_adjacent_copy()
	_test_mirror_prism_rejects_ineligible_states()

func _test_backflow_targets_previous_rule() -> void:
	var definition := _engraving(
		&"engraving_backflow_bridge",
		EngravingDefinition.Operation.BRIDGE_BACKWARD,
		1
	)
	var state := _state_with_engraving(definition, 4, 4)
	var outcomes := EngravingResolver.new().table_outcomes(
		state,
		[&"d3"],
		true,
		[&"right", &"middle", &"left"],
		1,
		{&"d3": 4},
		_context(definition)
	)
	assert_equal(outcomes.size(), 1, "backflow should produce one outcome")
	if not outcomes.is_empty():
		assert_equal(
			outcomes[0].target_table_id,
			&"right",
			"backflow should target the previous rule in public resolution order"
		)
		assert_equal(outcomes[0].delta, 4, "backflow should carry the active die value")
		assert_true(outcomes[0].effect_applied, "backflow should be active")

func _test_backflow_without_previous_rule_is_diagnostic() -> void:
	var definition := _engraving(
		&"engraving_backflow_bridge",
		EngravingDefinition.Operation.BRIDGE_BACKWARD,
		1
	)
	var state := _state_with_engraving(definition, 4, 4)
	var outcomes := EngravingResolver.new().table_outcomes(
		state,
		[&"d3"],
		true,
		[&"right", &"middle", &"left"],
		0,
		{&"d3": 4},
		_context(definition)
	)
	assert_equal(outcomes.size(), 1, "first rule should still explain the failed engraving")
	if not outcomes.is_empty():
		assert_equal(outcomes[0].target_table_id, &"", "missing previous rule has no target")
		assert_false(outcomes[0].effect_applied, "missing previous rule should not apply")

func _test_backflow_applies_after_previous_rule_resolved() -> void:
	var definition := _engraving(
		&"engraving_backflow_bridge",
		EngravingDefinition.Operation.BRIDGE_BACKWARD,
		1
	)
	var state := _state_with_engraving(definition, 4, 4)
	state.assignments = {
		&"left": [&"d1"],
		&"middle": [&"d3"],
	}
	state.dice.append(DieState.new(&"d1", 2))
	var encounter := EncounterDefinition.new()
	encounter.rules = [
		_rule(&"left"),
		_rule(&"middle"),
	]
	var report := RoundResolver.new().resolve(
		state,
		encounter,
		_context(definition)
	)
	assert_true(report.valid, "backflow fixture should resolve")
	assert_equal(report.total, 10, "backflow should add its die value immediately")
	var events := report.events.filter(
		func(event: ResolutionEvent) -> bool:
			return event.source_id == definition.id
	)
	assert_equal(events.size(), 1, "backflow should emit one public event")
	if not events.is_empty():
		assert_equal(events[0].delta, 4, "backflow event should expose the added value")
		assert_true(events[0].effect_applied, "backflow event should be applied")

func _test_mirror_prism_requires_adjacent_copy() -> void:
	var definition := _engraving(
		&"engraving_mirror_prism",
		EngravingDefinition.Operation.MIRROR_PRISM,
		0
	)
	var state := _state_with_engraving(definition, 3, 3)
	state.played_cards = [_mirror_copy(&"left", &"middle")]
	var flags := EngravingResolver.new().parity_overrides(
		state,
		[&"d3"],
		&"middle",
		_context(definition)
	)
	assert_equal(flags, [true], "adjacent mirror copy should enable parity override")

func _test_mirror_prism_rejects_ineligible_states() -> void:
	var definition := _engraving(
		&"engraving_mirror_prism",
		EngravingDefinition.Operation.MIRROR_PRISM,
		0
	)
	var resolver := EngravingResolver.new()
	var context := _context(definition)

	var no_copy := _state_with_engraving(definition, 3, 3)
	assert_equal(
		resolver.parity_overrides(no_copy, [&"d3"], &"middle", context),
		[false],
		"mirror prism should require a derived copy"
	)

	var distant_copy := _state_with_engraving(definition, 3, 3)
	distant_copy.played_cards = [_mirror_copy(&"left", &"middle")]
	assert_equal(
		resolver.parity_overrides(distant_copy, [&"d3"], &"right", context),
		[false],
		"mirror prism should require adjacency to the current rule"
	)

	var original_only := _state_with_engraving(definition, 3, 3)
	var original := _mirror_copy(&"left", &"middle")
	original.is_mirror_copy = false
	original_only.played_cards = [original]
	assert_equal(
		resolver.parity_overrides(original_only, [&"d3"], &"middle", context),
		[false],
		"ordinary gap cards should not activate mirror prism"
	)

	var inactive_face := _state_with_engraving(definition, 3, 2)
	inactive_face.played_cards = [_mirror_copy(&"left", &"middle")]
	assert_equal(
		resolver.parity_overrides(inactive_face, [&"d3"], &"middle", context),
		[false],
		"mirror prism should still require the engraved face"
	)

func _engraving(
	id: StringName,
	operation: EngravingDefinition.Operation,
	amount: int
) -> EngravingDefinition:
	var definition := EngravingDefinition.new()
	definition.id = id
	definition.display_name = String(id)
	definition.operation = operation
	definition.amount = amount
	return definition

func _context(definition: EngravingDefinition) -> ResolutionContext:
	var catalog := EngravingCatalog.new()
	catalog._by_id[definition.id] = definition
	return ResolutionContext.new(null, catalog)

func _state_with_engraving(
	definition: EngravingDefinition,
	value: int,
	rolled_value: int
) -> RoundState:
	var state := RoundState.new()
	state.dice = [
		DieState.new(&"d3", value, definition.id, value, rolled_value),
	]
	return state

func _mirror_copy(primary_target: StringName, secondary_target: StringName) -> PlayedCard:
	var card := CardDefinition.new()
	card.id = &"mirror_copy_fixture"
	card.target_type = CardDefinition.TargetType.GAP
	var played := PlayedCard.new(card, primary_target, secondary_target)
	played.is_mirror_copy = true
	played.source_card_id = &"source_fixture"
	return played

func _rule(id: StringName) -> RuleDefinition:
	var rule := RuleDefinition.new()
	rule.id = id
	rule.display_name = String(id)
	rule.condition_type = RuleDefinition.ConditionType.ALL_EVEN
	rule.slot_count = 1
	rule.coefficient = 1
	return rule
