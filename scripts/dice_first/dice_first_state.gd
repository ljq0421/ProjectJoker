class_name DiceFirstState
extends RefCounted

enum Phase { AWAITING_ROLL, REROLL_DECISION, BUILD, COMMITTED }

var phase: Phase = Phase.AWAITING_ROLL
var table_rule_id: StringName = &"echo"
var dice: Array[DieState] = []
var initial_combo_candidates: Array[Dictionary] = []
var selected_reroll_die_ids: Array[StringName] = []
var played_cards: Array[PlayedCard] = []
var rerolled_die_ids: Array[StringName] = []
var left_table_die_ids: Array[StringName] = []
var right_table_die_ids: Array[StringName] = []
var breakthrough_requested := false

func find_die(die_id: StringName) -> DieState:
	for die in dice:
		if die.id == die_id: return die
	return null

func clone():
	var copy = get_script().new()
	copy.phase = phase
	copy.table_rule_id = table_rule_id
	for die in dice: copy.dice.append(die.clone())
	for candidate in initial_combo_candidates: copy.initial_combo_candidates.append(candidate.duplicate(true))
	copy.selected_reroll_die_ids.assign(selected_reroll_die_ids)
	for played_card in played_cards: copy.played_cards.append(played_card.clone())
	copy.rerolled_die_ids.assign(rerolled_die_ids)
	copy.left_table_die_ids.assign(left_table_die_ids)
	copy.right_table_die_ids.assign(right_table_die_ids)
	copy.breakthrough_requested = breakthrough_requested
	return copy
