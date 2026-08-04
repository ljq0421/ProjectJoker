extends "res://tests/test_case.gd"

const DieStateScript = preload("res://scripts/run/die_state.gd")
const RoundStateScript = preload("res://scripts/run/round_state.gd")
const RoundActionsScript = preload("res://scripts/run/round_actions.gd")
const RoundControllerScript = preload("res://scripts/run/round_controller.gd")
const SingleEncounterSessionScript = preload(
	"res://scripts/ui/single_encounter_session.gd"
)
const EncounterDefinitionScript = preload("res://scripts/resolution/encounter_definition.gd")
const RuleDefinitionScript = preload("res://scripts/rules/rule_definition.gd")

func run() -> void:
	var state := _state()
	var first := RoundActionsScript.assign_die_to_slot(
		state, &"d1", &"left", 1, 3
	)
	assert_true(first.accepted, "an unassigned die should enter a chosen empty slot")
	assert_equal(
		first.next_state.assignments[&"left"],
		[&"", &"d1", &""],
		"chosen placement should preserve explicit empty slots"
	)

	var occupied_rejection := RoundActionsScript.assign_die_to_slot(
		first.next_state, &"d2", &"left", 1, 3
	)
	assert_false(
		occupied_rejection.accepted,
		"an unassigned die must not overwrite an occupied slot"
	)
	var empty_hand: Array[CardDefinition] = []
	var drag_session := SingleEncounterSessionScript.new(
		first.next_state,
		_encounter(),
		empty_hand
	)
	assert_true(
		drag_session.assign_dropped_die_to_slot(&"d2", &"left", 1),
		"a free dragged die should fall back from an occupied slot"
	)
	assert_equal(
		drag_session.controller.state.assignments[&"left"],
		[&"d2", &"d1", &""],
		"drag fallback should use the nearest open slot without replacing the occupant"
	)

	var second := RoundActionsScript.assign_die_to_slot(
		first.next_state, &"d2", &"right", 0, 2
	)
	var swapped := RoundActionsScript.assign_die_to_slot(
		second.next_state, &"d1", &"right", 0, 2
	)
	assert_true(swapped.accepted, "assigned dice should swap across tables")
	assert_equal(
		swapped.next_state.assignments[&"left"],
		[&"", &"d2", &""],
		"cross-table swap should put the target die in the source slot"
	)
	assert_equal(
		swapped.next_state.assignments[&"right"],
		[&"d1", &""],
		"cross-table swap should put the source die in the target slot"
	)

	var controller := RoundControllerScript.new(_state(), _encounter())
	assert_true(
		controller.assign_die_to_slot(&"d1", &"left", 1, 3).accepted,
		"controller should accept explicit placement"
	)
	assert_true(
		controller.assign_die_to_slot(&"d2", &"right", 0, 2).accepted,
		"controller should accept a second explicit placement"
	)
	assert_true(
		controller.assign_die_to_slot(&"d1", &"right", 0, 2).accepted,
		"controller should record a swap as one action"
	)
	assert_true(controller.undo(), "one undo should reverse the complete swap")
	assert_equal(
		controller.state.assignments[&"left"],
		[&"", &"d1", &""],
		"undo should restore the source placement"
	)
	assert_equal(
		controller.state.assignments[&"right"],
		[&"d2", &""],
		"undo should restore the target placement"
	)

func _state() -> RoundState:
	var state := RoundStateScript.new()
	state.dice = [
		DieStateScript.new(&"d1", 1),
		DieStateScript.new(&"d2", 2),
	]
	return state

func _encounter() -> EncounterDefinition:
	var encounter := EncounterDefinitionScript.new()
	encounter.rules = [
		_rule(&"left", 3),
		_rule(&"middle", 1),
		_rule(&"right", 2),
	]
	return encounter

func _rule(id: StringName, slots: int) -> RuleDefinition:
	var rule := RuleDefinitionScript.new()
	rule.id = id
	rule.slot_count = slots
	return rule
