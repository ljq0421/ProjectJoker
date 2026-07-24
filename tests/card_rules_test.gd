extends "res://tests/test_case.gd"

const RoundStateScript = preload("res://scripts/run/round_state.gd")
const CardDefinitionScript = preload("res://scripts/cards/card_definition.gd")
const PlayedCardScript = preload("res://scripts/cards/played_card.gd")
const CardRulesScript = preload("res://scripts/cards/card_rules.gd")

func run() -> void:
	var boost := CardDefinitionScript.new()
	boost.id = &"diamond_boost"
	boost.display_name = "映射"
	boost.target_type = CardDefinitionScript.TargetType.TABLE

	var state := RoundStateScript.new()
	var first = CardRulesScript.play_card(state, PlayedCardScript.new(boost, &"left"))
	assert_true(first.accepted, "first card should be accepted")
	assert_equal(first.next_state.played_cards.size(), 1, "first card should enter cloned state")
	assert_equal(state.played_cards.size(), 0, "playing a card must not mutate original state")

	var second = CardRulesScript.play_card(first.next_state, PlayedCardScript.new(boost, &"middle"))
	var third = CardRulesScript.play_card(second.next_state, PlayedCardScript.new(boost, &"right"))
	assert_true(second.accepted, "second card should be accepted")
	assert_false(third.accepted, "third card should exceed the round limit")

	var no_target = CardRulesScript.play_card(state, PlayedCardScript.new(boost, &""))
	assert_false(no_target.accepted, "targeted cards require a target ID")
