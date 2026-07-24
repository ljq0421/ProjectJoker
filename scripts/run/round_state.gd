class_name RoundState
extends RefCounted

var dice: Array[DieState] = []
var assignments: Dictionary = {}
var played_cards: Array = []
var calibration_points: int = 2

func find_die(die_id: StringName) -> DieState:
	for die in dice:
		if die.id == die_id:
			return die
	return null

func clone() -> RoundState:
	var copy := RoundState.new()
	copy.dice = []
	for die in dice:
		copy.dice.append(die.clone())
	copy.assignments = {}
	for table_id in assignments:
		copy.assignments[table_id] = assignments[table_id].duplicate()
	copy.played_cards = []
	for played_card in played_cards:
		copy.played_cards.append(played_card.clone())
	copy.calibration_points = calibration_points
	return copy
