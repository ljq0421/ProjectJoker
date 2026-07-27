extends "res://tests/test_case.gd"

func run() -> void:
	_test_catalog_contract()
	_test_low_murmur_uses_lower_adjacent_value()
	_test_low_murmur_without_neighbor_is_visible()
	_test_terminal_anchor_only_rewards_last_table_and_blocks_changes()
	_test_two_way_bridge_sends_half_to_both_sides()
	_test_sequence_prism_changes_matching_not_score()
	_test_inactive_or_unassigned_engravings_do_not_trigger()

func _test_catalog_contract() -> void:
	var catalog := EngravingCatalog.new()
	assert_equal(catalog.all_engravings().size(), 12, "catalog exposes twelve engravings")
	assert_equal(catalog.faceless_hub_ids().size(), 4, "faceless group contains four")
	assert_equal(catalog.validate(), [], "all engraving resources validate")

func _test_low_murmur_uses_lower_adjacent_value() -> void:
	var state := _state([2, 4, 6])
	state.dice[1].engraving_id = &"engraving_low_murmur"
	state.dice[1].engraved_face = 4
	state.assignments = {&"left": [&"d1", &"d2", &"d3"]}
	var report := _resolve(state, _encounter([12], [3]))
	assert_equal(report.total, 14, "low murmur copies the lower adjacent value")
	assert_true(_has_event(report, &"engraving_low_murmur", 2, true), "low murmur event")

func _test_low_murmur_without_neighbor_is_visible() -> void:
	var state := _state([4])
	state.dice[0].engraving_id = &"engraving_low_murmur"
	state.dice[0].engraved_face = 4
	state.assignments = {&"left": [&"d1"]}
	var report := _resolve(state, _encounter([4], [1]))
	assert_equal(report.total, 4, "no neighbor grants no bonus")
	assert_true(_has_event(report, &"engraving_low_murmur", 0, false), "failure is visible")

func _test_terminal_anchor_only_rewards_last_table_and_blocks_changes() -> void:
	var state := _state([1, 2, 3])
	state.dice[1].engraving_id = &"engraving_terminal_anchor"
	state.dice[1].engraved_face = 2
	state.assignments = {
		&"left": [&"d1"],
		&"middle": [&"d2"],
		&"right": [&"d3"],
	}
	var encounter := _encounter([1, 2, 3], [1, 1, 1])
	var middle_report := _resolve(state, encounter)
	assert_equal(middle_report.total, 6, "non-terminal anchor grants no bonus")
	var controller := RoundController.new(
		state,
		encounter,
		ResolutionContext.new(null, EngravingCatalog.new())
	)
	assert_false(controller.adjust_die(&"d2", 1).accepted, "active terminal anchor blocks changes")

	state.dice[1].engraving_id = &""
	state.dice[1].engraved_face = 0
	state.dice[2].engraving_id = &"engraving_terminal_anchor"
	state.dice[2].engraved_face = 3
	var last_report := _resolve(state, encounter)
	assert_equal(last_report.total, 11, "last table anchor adds five")
	assert_true(_has_event(last_report, &"engraving_terminal_anchor", 5, true), "anchor event")

func _test_two_way_bridge_sends_half_to_both_sides() -> void:
	var state := _state([2, 4, 6])
	state.dice[1].engraving_id = &"engraving_two_way_bridge"
	state.dice[1].engraved_face = 4
	state.assignments = {
		&"left": [&"d1"],
		&"middle": [&"d2"],
		&"right": [&"d3"],
	}
	var report := _resolve(state, _encounter([2, 4, 6], [1, 1, 1]))
	assert_equal(report.total, 16, "middle bridge sends floor(4/2) both ways")
	var bridge_events := _event_count(report, &"engraving_two_way_bridge", 2)
	assert_equal(bridge_events, 2, "two-way bridge emits two transfers")

	var edge := _state([4, 2])
	edge.dice[0].engraving_id = &"engraving_two_way_bridge"
	edge.dice[0].engraved_face = 4
	edge.assignments = {&"left": [&"d1"], &"middle": [&"d2"]}
	var edge_report := _resolve(edge, _encounter([4, 2], [1, 1]))
	assert_equal(edge_report.total, 8, "edge bridge transfers to its only neighbor")
	assert_equal(
		_event_count(edge_report, &"engraving_two_way_bridge", 2),
		1,
		"edge bridge emits one transfer"
	)

func _test_sequence_prism_changes_matching_not_score() -> void:
	var state := _state([1, 3, 4])
	state.dice[0].engraving_id = &"engraving_sequence_prism"
	state.dice[0].engraved_face = 1
	state.assignments = {&"left": [&"d1", &"d2", &"d3"]}
	var encounter := EncounterDefinition.new()
	var rule := RuleDefinition.new()
	rule.id = &"left"
	rule.display_name = "序列"
	rule.condition_type = RuleDefinition.ConditionType.CONSECUTIVE
	rule.slot_count = 3
	rule.coefficient = 1
	encounter.rules = [rule]
	var report := _resolve(state, encounter)
	assert_equal(report.total, 8, "prism passes as 2,3,4 but scores real sum 1+3+4")

func _test_inactive_or_unassigned_engravings_do_not_trigger() -> void:
	var state := _state([2, 3, 4, 1])
	state.dice[3].engraving_id = &"engraving_sequence_prism"
	state.dice[3].engraved_face = 2
	state.assignments = {&"left": [&"d1", &"d2", &"d3"]}
	var encounter := EncounterDefinition.new()
	var rule := RuleDefinition.new()
	rule.id = &"left"
	rule.display_name = "序列"
	rule.condition_type = RuleDefinition.ConditionType.CONSECUTIVE
	rule.slot_count = 3
	encounter.rules = [rule]
	var report := _resolve(state, encounter)
	assert_equal(report.total, 9, "unassigned inactive engraving does not alter a valid table")
	assert_false(
		_has_source_event(report, &"engraving_sequence_prism"),
		"unassigned engraving emits no event"
	)

func _resolve(state: RoundState, encounter: EncounterDefinition) -> ResolutionReport:
	return RoundResolver.new().resolve(
		state,
		encounter,
		ResolutionContext.new(null, EngravingCatalog.new())
	)

func _state(values: Array[int]) -> RoundState:
	var state := RoundState.new()
	for index in values.size():
		state.dice.append(DieState.new(
			StringName("d%d" % (index + 1)),
			values[index]
		))
	return state

func _encounter(targets: Array[int], slots: Array[int]) -> EncounterDefinition:
	var encounter := EncounterDefinition.new()
	var ids: Array[StringName] = [&"left", &"middle", &"right"]
	for index in targets.size():
		var rule := RuleDefinition.new()
		rule.id = ids[index]
		rule.display_name = String(ids[index])
		rule.slot_count = slots[index]
		rule.target_value = targets[index]
		rule.coefficient = 1
		encounter.rules.append(rule)
	return encounter

func _has_event(
	report: ResolutionReport,
	source_id: StringName,
	delta: int,
	applied: bool
) -> bool:
	for event in report.events:
		if (
			event.source_id == source_id
			and event.delta == delta
			and event.effect_applied == applied
		):
			return true
	return false

func _event_count(
	report: ResolutionReport,
	source_id: StringName,
	delta: int
) -> int:
	var count := 0
	for event in report.events:
		if event.source_id == source_id and event.delta == delta:
			count += 1
	return count

func _has_source_event(
	report: ResolutionReport,
	source_id: StringName
) -> bool:
	for event in report.events:
		if event.source_id == source_id:
			return true
	return false
