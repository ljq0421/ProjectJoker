class_name DiceFirstController
extends RefCounted

const StateScript = preload("res://scripts/dice_first/dice_first_state.gd")
const ResolverScript = preload("res://scripts/dice_first/dice_first_resolver.gd")
const TABLE_RULE_IDS: Array[StringName] = [&"echo", &"polar", &"charge"]

var state = StateScript.new()
var _resolver = ResolverScript.new()
var _rng := RandomNumberGenerator.new()
var _committed_report
var _table_rule_override: StringName = &""

func _init(seed_value: int = 0, table_rule_override: StringName = &"") -> void:
	_rng.seed = seed_value if seed_value != 0 else Time.get_ticks_usec()
	_table_rule_override = table_rule_override

func roll_initial() -> bool:
	if state.phase != StateScript.Phase.AWAITING_ROLL: return false
	for index in range(6): state.dice.append(DieState.new(StringName("d%d" % (index + 1)), _rng.randi_range(1, 6)))
	state.table_rule_id = (
		_table_rule_override
		if _table_rule_override in TABLE_RULE_IDS
		else TABLE_RULE_IDS[_rng.randi_range(0, TABLE_RULE_IDS.size() - 1)]
	)
	state.phase = StateScript.Phase.REROLL_DECISION
	return true

func toggle_reroll_die(die_id: StringName) -> bool:
	if state.phase != StateScript.Phase.REROLL_DECISION or state.find_die(die_id) == null: return false
	if die_id in state.selected_reroll_die_ids:
		state.selected_reroll_die_ids.erase(die_id)
		return true
	if state.selected_reroll_die_ids.size() >= 3: return false
	state.selected_reroll_die_ids.append(die_id)
	return true

func confirm_reroll() -> bool:
	if state.phase != StateScript.Phase.REROLL_DECISION or state.selected_reroll_die_ids.is_empty() or state.selected_reroll_die_ids.size() > 3: return false
	_snapshot_initial_combos()
	for die_id in state.selected_reroll_die_ids:
		var die := state.find_die(die_id)
		var value := _rng.randi_range(1, 6)
		die.rolled_value = value
		die.value = value
	state.rerolled_die_ids.assign(state.selected_reroll_die_ids)
	state.selected_reroll_die_ids.clear()
	state.phase = StateScript.Phase.BUILD
	return true

func keep_all() -> bool:
	if state.phase != StateScript.Phase.REROLL_DECISION: return false
	_snapshot_initial_combos()
	state.selected_reroll_die_ids.clear()
	state.phase = StateScript.Phase.BUILD
	return true

func _snapshot_initial_combos() -> void:
	state.initial_combo_candidates.clear()
	for candidate in preview().combo_candidates:
		state.initial_combo_candidates.append(candidate.duplicate(true))

func play_instruction(definition: CardDefinition, die_id: StringName) -> bool:
	if state.phase != StateScript.Phase.BUILD or definition == null or state.find_die(die_id) == null or not state.played_cards.is_empty(): return false
	state.played_cards.append(PlayedCard.new(definition, die_id))
	state.breakthrough_requested = false
	return true

func assign_die_to_table(die_id: StringName, table_id: StringName) -> bool:
	if state.phase != StateScript.Phase.BUILD or state.find_die(die_id) == null: return false
	if table_id not in [&"left", &"right"]: return false
	var destination: Array[StringName] = state.left_table_die_ids if table_id == &"left" else state.right_table_die_ids
	if die_id in destination: return true
	if destination.size() >= 3: return false
	state.left_table_die_ids.erase(die_id)
	state.right_table_die_ids.erase(die_id)
	destination.append(die_id)
	state.breakthrough_requested = false
	return true

func clear_die_table(die_id: StringName) -> bool:
	if state.phase != StateScript.Phase.BUILD or state.find_die(die_id) == null: return false
	var removed := false
	if die_id in state.left_table_die_ids:
		state.left_table_die_ids.erase(die_id)
		removed = true
	if die_id in state.right_table_die_ids:
		state.right_table_die_ids.erase(die_id)
		removed = true
	if removed: state.breakthrough_requested = false
	return removed

func preview(): return _resolver.resolve(state)

func toggle_breakthrough() -> bool:
	if state.phase != StateScript.Phase.BUILD: return false
	if state.breakthrough_requested:
		state.breakthrough_requested = false
		return true
	var report = preview()
	if not report.table_allocation_complete or not report.breakthrough_available: return false
	state.breakthrough_requested = true
	return true

func commit():
	if _committed_report != null: return _committed_report
	if state.phase != StateScript.Phase.BUILD: return null
	if not preview().table_allocation_complete: return null
	_committed_report = _resolver.resolve(state)
	if not _committed_report.valid: return null
	state.phase = StateScript.Phase.COMMITTED
	return _committed_report
