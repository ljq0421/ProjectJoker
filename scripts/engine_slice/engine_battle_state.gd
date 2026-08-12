class_name EngineBattleState
extends RefCounted

const DieState = preload("res://scripts/run/die_state.gd")

enum Phase { READY, BUILD, RESOLVED, WON, LOST }

var phase: Phase = Phase.READY
var enemy_id: StringName
var enemy_health := 0
var enemy_max_health := 0
var player_health := 40
var player_max_health := 40
var turn := 0
var dice: Array[DieState] = []
var consumed_die_ids: Array[StringName] = []
var assignments: Dictionary = {&"attack": [], &"guard": [], &"engine": []}
var technique_ids: Array[StringName] = []
var technique_upgrades: Dictionary = {}
var technique_uses: Dictionary = {}
var activated_technique_counts: Dictionary = {}
var die_technique_marks: Dictionary = {}
var tactic_hand: Array[StringName] = []
var tactic_used_id: StringName = &""
var locked_technique_id: StringName = &""
var next_locked_technique_id: StringName = &""
var next_extra_dice := 0
var next_dice_drain := 0
var engine_charge := 0
var carried_block := 0
var next_retained_block := 0
var attack_multiplier := 1
var guard_multiplier := 1
var attack_repeats := 0
var guard_repeats := 0
var engine_bonus := 0
var flat_damage := 0
var flat_block := 0
var intent_reduction := 0
var intent_pressure := 0
var counter_percent := 0

func find_die(die_id: StringName) -> DieState:
	for die in dice:
		if die.id == die_id:
			return die
	return null

func assigned_lane(die_id: StringName) -> StringName:
	for lane_id in assignments:
		if die_id in assignments[lane_id]:
			return lane_id
	return &""

func is_available(die_id: StringName) -> bool:
	return find_die(die_id) != null and die_id not in consumed_die_ids and assigned_lane(die_id) == &""

func clone():
	return from_snapshot(to_snapshot())

func to_snapshot() -> Dictionary:
	var die_snapshots: Array[Dictionary] = []
	for die in dice:
		die_snapshots.append({"id": die.id, "value": die.value, "rolled_value": die.rolled_value})
	return {
		"phase": phase,
		"enemy_id": enemy_id,
		"enemy_health": enemy_health,
		"enemy_max_health": enemy_max_health,
		"player_health": player_health,
		"player_max_health": player_max_health,
		"turn": turn,
		"dice": die_snapshots,
		"consumed_die_ids": consumed_die_ids.duplicate(),
		"assignments": assignments.duplicate(true),
		"technique_ids": technique_ids.duplicate(),
		"technique_upgrades": technique_upgrades.duplicate(true),
		"technique_uses": technique_uses.duplicate(true),
		"activated_technique_counts": activated_technique_counts.duplicate(true),
		"die_technique_marks": die_technique_marks.duplicate(true),
		"tactic_hand": tactic_hand.duplicate(),
		"tactic_used_id": tactic_used_id,
		"locked_technique_id": locked_technique_id,
		"next_locked_technique_id": next_locked_technique_id,
		"next_extra_dice": next_extra_dice,
		"next_dice_drain": next_dice_drain,
		"engine_charge": engine_charge,
		"carried_block": carried_block,
		"next_retained_block": next_retained_block,
		"attack_multiplier": attack_multiplier,
		"guard_multiplier": guard_multiplier,
		"attack_repeats": attack_repeats,
		"guard_repeats": guard_repeats,
		"engine_bonus": engine_bonus,
		"flat_damage": flat_damage,
		"flat_block": flat_block,
		"intent_reduction": intent_reduction,
		"intent_pressure": intent_pressure,
		"counter_percent": counter_percent,
	}

func from_snapshot(snapshot: Dictionary):
	var state = get_script().new()
	state.phase = int(snapshot.get("phase", Phase.READY))
	state.enemy_id = snapshot.get("enemy_id", &"")
	state.enemy_health = int(snapshot.get("enemy_health", 0))
	state.enemy_max_health = int(snapshot.get("enemy_max_health", 0))
	state.player_health = int(snapshot.get("player_health", 40))
	state.player_max_health = int(snapshot.get("player_max_health", 40))
	state.turn = int(snapshot.get("turn", 0))
	for entry in snapshot.get("dice", []):
		state.dice.append(DieState.new(entry["id"], int(entry["value"]), &"", 0, int(entry.get("rolled_value", entry["value"]))))
	state.consumed_die_ids.assign(snapshot.get("consumed_die_ids", []))
	state.assignments = snapshot.get("assignments", {&"attack": [], &"guard": [], &"engine": []}).duplicate(true)
	state.technique_ids.assign(snapshot.get("technique_ids", []))
	state.technique_upgrades = snapshot.get("technique_upgrades", {}).duplicate(true)
	state.technique_uses = snapshot.get("technique_uses", {}).duplicate(true)
	state.activated_technique_counts = snapshot.get("activated_technique_counts", {}).duplicate(true)
	state.die_technique_marks = snapshot.get("die_technique_marks", {}).duplicate(true)
	state.tactic_hand.assign(snapshot.get("tactic_hand", []))
	state.tactic_used_id = snapshot.get("tactic_used_id", &"")
	state.locked_technique_id = snapshot.get("locked_technique_id", &"")
	state.next_locked_technique_id = snapshot.get("next_locked_technique_id", &"")
	state.next_extra_dice = int(snapshot.get("next_extra_dice", 0))
	state.next_dice_drain = int(snapshot.get("next_dice_drain", 0))
	state.engine_charge = int(snapshot.get("engine_charge", 0))
	state.carried_block = int(snapshot.get("carried_block", 0))
	state.next_retained_block = int(snapshot.get("next_retained_block", 0))
	state.attack_multiplier = int(snapshot.get("attack_multiplier", 1))
	state.guard_multiplier = int(snapshot.get("guard_multiplier", 1))
	state.attack_repeats = int(snapshot.get("attack_repeats", 0))
	state.guard_repeats = int(snapshot.get("guard_repeats", 0))
	state.engine_bonus = int(snapshot.get("engine_bonus", 0))
	state.flat_damage = int(snapshot.get("flat_damage", 0))
	state.flat_block = int(snapshot.get("flat_block", 0))
	state.intent_reduction = int(snapshot.get("intent_reduction", 0))
	state.intent_pressure = int(snapshot.get("intent_pressure", 0))
	state.counter_percent = int(snapshot.get("counter_percent", 0))
	return state
