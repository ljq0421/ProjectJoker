extends "res://tests/test_case.gd"

const DieStateScript = preload("res://scripts/run/die_state.gd")
const RoundStateScript = preload("res://scripts/run/round_state.gd")
const RuleDefinitionScript = preload("res://scripts/rules/rule_definition.gd")
const EncounterDefinitionScript = preload("res://scripts/resolution/encounter_definition.gd")
const RoundResolverScript = preload("res://scripts/resolution/round_resolver.gd")
const CardDefinitionScript = preload("res://scripts/cards/card_definition.gd")
const EffectSpecScript = preload("res://scripts/cards/effect_spec.gd")
const PlayedCardScript = preload("res://scripts/cards/played_card.gd")

func run() -> void:
	var state = _build_state()
	var encounter = _build_encounter()
	var report = RoundResolverScript.new().resolve(state, encounter)
	assert_true(report.valid, "configured round should resolve")
	assert_equal(report.total, 51, "three tables and coefficient card should total 51")
	assert_equal(report.events.size(), 4, "one card event and three table events are expected")
	assert_equal(report.events[1].source_id, &"left", "left table should resolve first")

func _build_state():
	var state := RoundStateScript.new()
	for value in range(1, 7):
		state.dice.append(DieStateScript.new(StringName("d%d" % value), value))
	state.find_die(&"d5").value = 4
	state.assignments = {
		&"left": [&"d1", &"d6"],
		&"middle": [&"d2", &"d3", &"d4"],
		&"right": [&"d5"],
	}

	var effect := EffectSpecScript.new()
	effect.operation = EffectSpecScript.Operation.MODIFY_COEFFICIENT
	effect.amount = 1
	var card := CardDefinitionScript.new()
	card.id = &"diamond_boost"
	card.display_name = "映射"
	card.target_type = CardDefinitionScript.TargetType.TABLE
	card.effects = [effect]
	state.played_cards = [PlayedCardScript.new(card, &"left")]
	return state

func _build_encounter():
	var left = _rule(&"left", RuleDefinitionScript.ConditionType.EXACT_SUM, 2, 2, 7)
	var middle = _rule(&"middle", RuleDefinitionScript.ConditionType.CONSECUTIVE, 3, 2)
	var right = _rule(&"right", RuleDefinitionScript.ConditionType.ALL_EVEN, 1, 3)
	var encounter := EncounterDefinitionScript.new()
	encounter.id = &"foundation_round"
	encounter.rules = [left, middle, right]
	return encounter

func _rule(id: StringName, type: int, slots: int, coefficient: int, target: int = 0):
	var rule := RuleDefinitionScript.new()
	rule.id = id
	rule.condition_type = type
	rule.slot_count = slots
	rule.coefficient = coefficient
	rule.target_value = target
	return rule
