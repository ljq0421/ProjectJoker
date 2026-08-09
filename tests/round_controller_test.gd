extends "res://tests/test_case.gd"

const DieStateScript = preload("res://scripts/run/die_state.gd")
const RoundStateScript = preload("res://scripts/run/round_state.gd")
const RuleDefinitionScript = preload("res://scripts/rules/rule_definition.gd")
const EncounterDefinitionScript = preload("res://scripts/resolution/encounter_definition.gd")
const CardDefinitionScript = preload("res://scripts/cards/card_definition.gd")
const EffectSpecScript = preload("res://scripts/cards/effect_spec.gd")
const PlayedCardScript = preload("res://scripts/cards/played_card.gd")
const RoundControllerScript = preload("res://scripts/run/round_controller.gd")

func run() -> void:
	var controller = RoundControllerScript.new(_state(), _encounter())
	assert_equal(controller.undo_remaining(), 1, "a fresh round should allow one undo")
	assert_false(controller.undo(), "an empty history should reject undo")
	assert_equal(controller.undo_remaining(), 1, "a rejected undo must not spend the allowance")
	assert_true(controller.assign_die(&"d1", &"left", 2).accepted, "assign d1")
	assert_true(controller.unassign_die(&"d1").accepted, "tray return should unassign d1")
	assert_equal(
		controller.state.assigned_die_ids(&"left"),
		[],
		"tray return should clear the lane"
	)
	assert_true(controller.undo(), "tray return should be undoable")
	assert_equal(
		controller.state.assigned_die_ids(&"left"),
		[&"d1"],
		"undo should restore the lane assignment"
	)
	assert_equal(controller.undo_remaining(), 0, "the first successful undo spends the allowance")
	assert_true(controller.assign_die(&"d6", &"left", 2).accepted, "actions remain legal after undo")
	assert_false(controller.undo(), "a second undo in the same round must be rejected")
	assert_equal(
		controller.undo_block_reason(),
		"本回合最多撤销 1 次",
		"the second undo should explain the per-round cap"
	)

	controller = _completed_controller()
	assert_equal(controller.undo_remaining(), 1, "a new round controller resets undo")
	var played := PlayedCardScript.new(_boost_card(), &"left")
	assert_true(controller.play_card(played).accepted, "play coefficient card")
	var preview = controller.preview()
	assert_equal(preview.total, 51, "preview should total 51")

	assert_true(controller.undo(), "card play should be undoable")
	assert_equal(controller.preview().total, 44, "undo should remove the coefficient card")
	assert_false(controller.undo(), "the card round should also reject a second undo")
	assert_true(controller.play_card(played).accepted, "card should be playable again")

	var final_preview = controller.preview()
	var committed = controller.commit()
	assert_equal(committed.total, final_preview.total, "commit total must equal preview")
	assert_equal(
		committed.event_signature(),
		final_preview.event_signature(),
		"commit events must equal preview events"
	)
	assert_false(controller.adjust_die(&"d1", 1).accepted, "committed rounds reject further actions")

func _completed_controller():
	var controller = RoundControllerScript.new(_state(), _encounter())
	assert_true(controller.assign_die(&"d1", &"left", 2).accepted, "assign d1")
	assert_true(controller.assign_die(&"d6", &"left", 2).accepted, "assign d6")
	assert_true(controller.assign_die(&"d2", &"middle", 3).accepted, "assign d2")
	assert_true(controller.assign_die(&"d3", &"middle", 3).accepted, "assign d3")
	assert_true(controller.assign_die(&"d4", &"middle", 3).accepted, "assign d4")
	assert_true(controller.adjust_die(&"d5", -1).accepted, "calibrate d5 from 5 to 4")
	assert_true(controller.assign_die(&"d5", &"right", 1).accepted, "assign d5")
	return controller

func _state():
	var state := RoundStateScript.new()
	for value in range(1, 7):
		state.dice.append(DieStateScript.new(StringName("d%d" % value), value))
	return state

func _encounter():
	var encounter := EncounterDefinitionScript.new()
	encounter.id = &"controller_round"
	encounter.rules = [
		_rule(&"left", RuleDefinitionScript.ConditionType.EXACT_SUM, 2, 2, 7),
		_rule(&"middle", RuleDefinitionScript.ConditionType.CONSECUTIVE, 3, 2),
		_rule(&"right", RuleDefinitionScript.ConditionType.ALL_EVEN, 1, 3),
	]
	return encounter

func _rule(id: StringName, type: int, slots: int, coefficient: int, target: int = 0):
	var rule := RuleDefinitionScript.new()
	rule.id = id
	rule.condition_type = type
	rule.slot_count = slots
	rule.coefficient = coefficient
	rule.target_value = target
	return rule

func _boost_card():
	var effect := EffectSpecScript.new()
	effect.operation = EffectSpecScript.Operation.MODIFY_COEFFICIENT
	effect.amount = 1
	var card := CardDefinitionScript.new()
	card.id = &"diamond_boost"
	card.display_name = "映射"
	card.target_type = CardDefinitionScript.TargetType.TABLE
	card.effects = [effect]
	return card
