class_name EngineBattleController
extends RefCounted

const EngineBattleState = preload("res://scripts/engine_slice/engine_battle_state.gd")
const EngineBattleReport = preload("res://scripts/engine_slice/engine_battle_report.gd")
const EngineBattleResolver = preload("res://scripts/engine_slice/engine_battle_resolver.gd")
const EngineSliceCatalog = preload("res://scripts/engine_slice/engine_slice_catalog.gd")
const EngineEnemyDefinition = preload("res://scripts/engine_slice/engine_enemy_definition.gd")
const EngineIntentDefinition = preload("res://scripts/engine_slice/engine_intent_definition.gd")
const DieState = preload("res://scripts/run/die_state.gd")

const LANE_CAPACITY := {&"attack": 2, &"guard": 2, &"engine": 1}

var state: EngineBattleState
var catalog: EngineSliceCatalog
var _resolver := EngineBattleResolver.new()
var _history: Array[EngineBattleState] = []

func _init(
	enemy: EngineEnemyDefinition = null,
	player_health: int = 40,
	technique_ids: Array = [],
	upgrades: Dictionary = {},
	p_catalog: EngineSliceCatalog = null
) -> void:
	catalog = p_catalog if p_catalog != null else EngineSliceCatalog.new()
	state = EngineBattleState.new()
	if enemy != null:
		state.enemy_id = enemy.id
		state.enemy_health = enemy.max_health
		state.enemy_max_health = enemy.max_health
	state.player_health = player_health
	state.technique_ids.assign(technique_ids)
	state.technique_upgrades = upgrades.duplicate(true)

func restore(snapshot: Dictionary) -> OperationResult:
	state = EngineBattleState.new().from_snapshot(snapshot)
	_history.clear()
	return OperationResult.new(true)

func begin_turn(values: Array[int], tactic_ids: Array[StringName]) -> OperationResult:
	if state.phase not in [EngineBattleState.Phase.READY, EngineBattleState.Phase.RESOLVED]:
		return OperationResult.new(false, "当前不能开始新回合")
	state.turn += 1
	state.phase = EngineBattleState.Phase.BUILD
	state.dice.clear()
	for index in values.size():
		state.dice.append(DieState.new(StringName("d%d" % (index + 1)), values[index]))
	state.consumed_die_ids.clear()
	state.assignments = {&"attack": [], &"guard": [], &"engine": []}
	state.technique_uses.clear()
	state.activated_technique_counts.clear()
	state.die_technique_marks.clear()
	state.tactic_hand.assign(tactic_ids)
	state.tactic_used_id = &""
	state.locked_technique_id = state.next_locked_technique_id
	state.next_locked_technique_id = &""
	state.attack_multiplier = 1
	state.guard_multiplier = 1
	state.attack_repeats = 0
	state.guard_repeats = 0
	state.engine_bonus = 0
	state.flat_damage = 0
	state.flat_block = 0
	state.intent_reduction = 0
	state.intent_pressure = 0
	state.counter_percent = 0
	state.carried_block = state.next_retained_block
	state.next_retained_block = 0
	_history.clear()
	return OperationResult.new(true)

func assign_die(die_id: StringName, lane_id: StringName) -> OperationResult:
	if state.phase != EngineBattleState.Phase.BUILD:
		return OperationResult.new(false, "当前不能分配骰子")
	if lane_id not in LANE_CAPACITY:
		return OperationResult.new(false, "未知规则台")
	if state.find_die(die_id) == null or die_id in state.consumed_die_ids:
		return OperationResult.new(false, "这颗骰子不可用")
	var current := state.assigned_lane(die_id)
	if current == lane_id:
		return OperationResult.new(true)
	if state.assignments[lane_id].size() >= int(LANE_CAPACITY[lane_id]):
		return OperationResult.new(false, "规则台骰位已满")
	_push_history()
	if current != &"":
		state.assignments[current].erase(die_id)
	state.assignments[lane_id].append(die_id)
	return OperationResult.new(true)

func unassign_die(die_id: StringName) -> OperationResult:
	var lane_id := state.assigned_lane(die_id)
	if lane_id == &"":
		return OperationResult.new(false, "骰子不在规则台")
	_push_history()
	state.assignments[lane_id].erase(die_id)
	return OperationResult.new(true)

func activate_technique(technique_id: StringName, die_id: StringName) -> OperationResult:
	if state.phase != EngineBattleState.Phase.BUILD:
		return OperationResult.new(false, "当前不能发动手法")
	if technique_id not in state.technique_ids:
		return OperationResult.new(false, "手法不在常驻栏")
	if technique_id == state.locked_technique_id:
		return OperationResult.new(false, "这张手法被本轮封锁")
	if int(state.technique_uses.get(technique_id, 0)) >= 1:
		return OperationResult.new(false, "这张手法本轮已经发动")
	if not state.is_available(die_id):
		return OperationResult.new(false, "请选择骰盘中的可用骰子")
	var definition := catalog.technique(technique_id)
	var die := state.find_die(die_id)
	if definition == null or not definition.accepts(die.value):
		return OperationResult.new(false, "需要%s" % (definition.socket_copy() if definition != null else "有效插槽"))
	_push_history()
	var branch: StringName = state.technique_upgrades.get(technique_id, &"")
	var profile := definition.profile_for(branch)
	for effect in profile.get("activation", []):
		_apply_profile_effect(effect, die)
	state.technique_uses[technique_id] = 1
	state.activated_technique_counts[technique_id] = int(state.activated_technique_counts.get(technique_id, 0)) + 1
	var marks: Array = state.die_technique_marks.get(die_id, [])
	marks.append(technique_id)
	state.die_technique_marks[die_id] = marks
	if not definition.returns_die_for(branch):
		state.consumed_die_ids.append(die_id)
	return OperationResult.new(true)

func activate_tactic(tactic_id: StringName) -> OperationResult:
	if state.phase != EngineBattleState.Phase.BUILD:
		return OperationResult.new(false, "当前不能使用战术")
	if state.tactic_used_id != &"":
		return OperationResult.new(false, "本轮最多使用一张临时战术")
	if tactic_id not in state.tactic_hand:
		return OperationResult.new(false, "战术不在本轮手牌")
	var definition := catalog.tactic(tactic_id)
	if definition == null:
		return OperationResult.new(false, "战术定义不存在")
	_push_history()
	_apply_effect(definition.effect_id, definition.amount, null)
	state.tactic_used_id = tactic_id
	return OperationResult.new(true)

func preview(enemy: EngineEnemyDefinition, intent: EngineIntentDefinition) -> EngineBattleReport:
	return _resolver.resolve(state, enemy, intent, catalog)

func commit(enemy: EngineEnemyDefinition, intent: EngineIntentDefinition) -> EngineBattleReport:
	var report := preview(enemy, intent)
	if not report.valid or state.phase != EngineBattleState.Phase.BUILD:
		return report
	state.enemy_health = report.enemy_health_after
	state.player_health = report.player_health_after
	state.engine_charge = report.engine_charge_after
	state.next_retained_block = report.retained_block_after
	state.next_extra_dice = mini(2, state.next_extra_dice + report.engine_dice)
	if not report.intent_cancelled:
		if intent.effect_id == &"lock_technique" and not report.engine_passed and not state.technique_ids.is_empty():
			state.next_locked_technique_id = state.technique_ids[(state.turn - 1) % state.technique_ids.size()]
		if intent.effect_id == &"drain_die" and not report.guard_passed:
			state.next_dice_drain = intent.effect_amount
	if report.enemy_defeated:
		state.phase = EngineBattleState.Phase.WON
	elif report.player_defeated:
		state.phase = EngineBattleState.Phase.LOST
	else:
		state.phase = EngineBattleState.Phase.RESOLVED
	_history.clear()
	return report

func undo() -> OperationResult:
	if _history.is_empty() or state.phase != EngineBattleState.Phase.BUILD:
		return OperationResult.new(false, "没有可撤销的操作")
	state = _history.pop_back()
	return OperationResult.new(true)

func _push_history() -> void:
	_history.append(state.clone())

func _apply_effect(effect_id: StringName, amount: int, die: DieState) -> void:
	match effect_id:
		&"adjust_down":
			die.value = maxi(1, die.value - amount)
		&"adjust_up":
			die.value = mini(6, die.value + amount)
		&"flip":
			die.value = 7 - die.value
		&"set_four":
			die.value = 4
		&"attack_multiplier":
			state.attack_multiplier += amount
		&"guard_multiplier":
			state.guard_multiplier += amount
		&"attack_repeat":
			state.attack_repeats += amount
		&"guard_repeat":
			state.guard_repeats += amount
		&"engine_bonus":
			state.engine_bonus += amount
		&"flat_damage":
			state.flat_damage += amount
		&"flat_block":
			state.flat_block += amount
		&"flat_both":
			state.flat_damage += amount
			state.flat_block += amount
		&"heal":
			state.player_health = mini(state.player_max_health, state.player_health + amount)
		&"next_die":
			state.next_extra_dice = mini(2, state.next_extra_dice + amount)
		&"intent_reduction":
			state.intent_reduction += amount
		&"refresh":
			state.technique_uses.clear()
		&"risky_attack":
			state.attack_multiplier += amount
			state.intent_pressure += 2

func _apply_profile_effect(effect: Dictionary, die: DieState) -> void:
	var op := StringName(effect.get("op", &""))
	var amount := int(effect.get("amount", 0))
	match op:
		&"adjust_down":
			die.value = maxi(1, die.value - amount)
		&"adjust_up":
			die.value = mini(6, die.value + amount)
		&"flip":
			die.value = 7 - die.value
		&"set_four":
			die.value = 4
		&"attack_multiplier":
			state.attack_multiplier += amount
		&"guard_multiplier":
			state.guard_multiplier += amount
		&"attack_repeat":
			state.attack_repeats += amount
		&"guard_repeat":
			state.guard_repeats += amount
		&"counter_percent":
			state.counter_percent += amount
		&"intent_pressure":
			state.intent_pressure += amount
