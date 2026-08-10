class_name RoundState
extends RefCounted

const EMPTY_SLOT: StringName = &""

var dice: Array[DieState] = []
var assignments: Dictionary = {}
var played_cards: Array = []
var calibration_points: int = 2
var calibration_locked := false
var discarded_card_ids: Array[StringName] = []
var rank_conversion_used := false
var extra_calibration_undos := 0
var extra_card_undos := 0

func locked_die_ids() -> Array[StringName]:
	var die_ids: Array[StringName] = []
	for played_card in played_cards:
		if played_card is not PlayedCard:
			continue
		for die_id in played_card.locked_die_ids():
			if die_id not in die_ids:
				die_ids.append(die_id)
	return die_ids

func find_die(die_id: StringName) -> DieState:
	for die in dice:
		if die.id == die_id:
			return die
	return null

func slot_values(table_id: StringName, slot_count: int = -1) -> Array:
	var values: Array = assignments.get(table_id, []).duplicate()
	if slot_count < 0:
		return values
	if values.size() > slot_count:
		values.resize(slot_count)
	while values.size() < slot_count:
		values.append(EMPTY_SLOT)
	return values

func assigned_die_ids(table_id: StringName) -> Array:
	var result: Array = []
	for die_id in assignments.get(table_id, []):
		if die_id != EMPTY_SLOT:
			result.append(die_id)
	return result

func find_assignment(die_id: StringName) -> Dictionary:
	for table_id in assignments:
		var table_slots: Array = assignments[table_id]
		var slot_index := table_slots.find(die_id)
		if slot_index >= 0:
			return {
				"table_id": table_id,
				"slot_index": slot_index,
			}
	return {}

func is_assigned(die_id: StringName) -> bool:
	return not find_assignment(die_id).is_empty()

func occupied_slot_count(table_id: StringName) -> int:
	return assigned_die_ids(table_id).size()

func has_occupied_slot(table_id: StringName) -> bool:
	return occupied_slot_count(table_id) > 0

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
	copy.calibration_locked = calibration_locked
	copy.discarded_card_ids.assign(discarded_card_ids)
	copy.rank_conversion_used = rank_conversion_used
	copy.extra_calibration_undos = extra_calibration_undos
	copy.extra_card_undos = extra_card_undos
	return copy
