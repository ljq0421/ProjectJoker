class_name EngineSliceRunSession
extends RefCounted

const EngineSliceCatalog = preload("res://scripts/engine_slice/engine_slice_catalog.gd")
const EngineBattleController = preload("res://scripts/engine_slice/engine_battle_controller.gd")
const EngineBattleState = preload("res://scripts/engine_slice/engine_battle_state.gd")
const EngineBattleReport = preload("res://scripts/engine_slice/engine_battle_report.gd")
const EngineEnemyDefinition = preload("res://scripts/engine_slice/engine_enemy_definition.gd")
const EngineIntentDefinition = preload("res://scripts/engine_slice/engine_intent_definition.gd")
const RunRng = preload("res://scripts/run/run_rng.gd")
const OperationResult = preload("res://scripts/run/operation_result.gd")

enum Phase { SETUP, ROUTE, BATTLE, REWARD, SHOP, RESULT }

const PLAYER_MAX_HEALTH := 40
const MAX_TECHNIQUES := 5

var phase: Phase = Phase.SETUP
var seed_value := 1
var build_id: StringName = EngineSliceCatalog.DICE_CONTROL
var player_health := PLAYER_MAX_HEALTH
var intel := 2
var route_stage := 0
var selected_route_ids: Array[StringName] = []
var technique_ids: Array[StringName] = []
var technique_upgrades: Dictionary = {}
var tactic_ids: Array[StringName] = []
var current_enemy_id: StringName = &""
var battle: EngineBattleController
var current_intent_id: StringName = &""
var reward_options: Array[Dictionary] = []
var tactic_draw_pile: Array[StringName] = []
var tactic_discard: Array[StringName] = []
var last_report: EngineBattleReport
var result_copy := ""
var catalog := EngineSliceCatalog.new()
var rng := RunRng.new(1)

func start_new(p_seed: int, p_build_id: StringName) -> OperationResult:
	if p_seed <= 0:
		return OperationResult.new(false, "种子必须是正整数")
	var build := catalog.build_definition(p_build_id)
	if build.is_empty():
		return OperationResult.new(false, "未知起始构筑")
	seed_value = p_seed
	build_id = p_build_id
	rng = RunRng.new(seed_value)
	player_health = PLAYER_MAX_HEALTH
	intel = 2
	route_stage = 0
	selected_route_ids.clear()
	technique_ids.assign(build["techniques"])
	technique_upgrades.clear()
	tactic_ids.assign(build["tactics"])
	current_enemy_id = &""
	battle = null
	current_intent_id = &""
	reward_options.clear()
	result_copy = ""
	phase = Phase.ROUTE
	return OperationResult.new(true)

func route_options() -> Array[StringName]:
	return catalog.route_options(route_stage)

func choose_route(enemy_id: StringName) -> OperationResult:
	if phase != Phase.ROUTE or enemy_id not in route_options():
		return OperationResult.new(false, "所选路线当前不可用")
	selected_route_ids.append(enemy_id)
	return _begin_battle(enemy_id)

func start_next_turn() -> OperationResult:
	if phase != Phase.BATTLE or battle == null:
		return OperationResult.new(false, "当前没有可继续的战斗")
	if battle.state.phase not in [EngineBattleState.Phase.READY, EngineBattleState.Phase.RESOLVED]:
		return OperationResult.new(false, "上一回合尚未完成")
	for tactic_id in battle.state.tactic_hand:
		tactic_discard.append(tactic_id)
	var dice_count := clampi(
		6 + battle.state.next_extra_dice - battle.state.next_dice_drain,
		4,
		8
	)
	battle.state.next_extra_dice = 0
	battle.state.next_dice_drain = 0
	var values: Array[int] = []
	for _index in dice_count:
		values.append(rng.roll_die())
	var hand := _draw_tactics(2)
	var result := battle.begin_turn(values, hand)
	if result.accepted:
		current_intent_id = _intent_for_current_turn()
	return result

func current_enemy() -> EngineEnemyDefinition:
	return catalog.enemy(current_enemy_id)

func current_intent() -> EngineIntentDefinition:
	return catalog.intent(current_intent_id)

func commit_turn() -> EngineBattleReport:
	if phase != Phase.BATTLE or battle == null:
		var invalid := EngineBattleReport.new()
		invalid.valid = false
		invalid.reason = "当前没有可结算的战斗"
		return invalid
	last_report = battle.commit(current_enemy(), current_intent())
	if not last_report.valid:
		return last_report
	player_health = battle.state.player_health
	if battle.state.phase == EngineBattleState.Phase.WON:
		if current_enemy_id == &"dealer_iron_abacus_engine":
			phase = Phase.RESULT
			result_copy = "铁算盘的总账已经清零。金线引擎切片完成。"
		else:
			intel += 2 if route_stage == 0 else 3
			_generate_reward_options()
			phase = Phase.REWARD
	elif battle.state.phase == EngineBattleState.Phase.LOST:
		phase = Phase.RESULT
		result_copy = "生命归零，契据中止。可使用同一种子重新开局。"
	return last_report

func choose_reward(
	option_index: int,
	branch: StringName = &"",
	replace_id: StringName = &""
) -> OperationResult:
	if phase != Phase.REWARD or option_index < 0 or option_index >= reward_options.size():
		return OperationResult.new(false, "奖励选择无效")
	var option := reward_options[option_index]
	match StringName(option["kind"]):
		&"technique":
			var new_id: StringName = option["id"]
			if technique_ids.size() >= MAX_TECHNIQUES:
				if replace_id not in technique_ids:
					return OperationResult.new(false, "常驻栏已满，请选择要替换的手法")
				var index := technique_ids.find(replace_id)
				technique_ids[index] = new_id
				technique_upgrades.erase(replace_id)
			else:
				technique_ids.append(new_id)
		&"upgrade":
			var target_id: StringName = option["id"]
			if target_id not in technique_ids or branch not in [&"a", &"b"]:
				return OperationResult.new(false, "请选择有效的 A/B 升级")
			technique_upgrades[target_id] = branch
		&"tactic":
			tactic_ids.append(option["id"])
		_:
			return OperationResult.new(false, "未知奖励类型")
	reward_options.clear()
	if route_stage == 0:
		phase = Phase.SHOP
	else:
		return _begin_battle(&"dealer_iron_abacus_engine")
	return OperationResult.new(true)

func buy_heal() -> OperationResult:
	if phase != Phase.SHOP:
		return OperationResult.new(false, "当前不在商店")
	if intel < 2:
		return OperationResult.new(false, "情报不足：恢复需要 2 情报")
	if player_health >= PLAYER_MAX_HEALTH:
		return OperationResult.new(false, "生命已经全满")
	intel -= 2
	player_health = mini(PLAYER_MAX_HEALTH, player_health + 10)
	return OperationResult.new(true)

func buy_upgrade(technique_id: StringName, branch: StringName) -> OperationResult:
	if phase != Phase.SHOP:
		return OperationResult.new(false, "当前不在商店")
	if intel < 3:
		return OperationResult.new(false, "情报不足：升级需要 3 情报")
	if technique_id not in technique_ids or branch not in [&"a", &"b"]:
		return OperationResult.new(false, "升级目标无效")
	if technique_upgrades.has(technique_id):
		return OperationResult.new(false, "这张手法已经升级")
	intel -= 3
	technique_upgrades[technique_id] = branch
	return OperationResult.new(true)

func buy_tactic() -> OperationResult:
	if phase != Phase.SHOP:
		return OperationResult.new(false, "当前不在商店")
	if intel < 2:
		return OperationResult.new(false, "情报不足：战术需要 2 情报")
	var candidates: Array[StringName] = []
	for tactic_id in catalog.tactic_ids():
		if tactic_id not in tactic_ids:
			candidates.append(tactic_id)
	if candidates.is_empty():
		return OperationResult.new(false, "临时战术已经全部收录")
	var shuffled := rng.shuffle(candidates)
	intel -= 2
	tactic_ids.append(shuffled[0])
	return OperationResult.new(true)

func remove_tactic(tactic_id: StringName) -> OperationResult:
	if phase != Phase.SHOP:
		return OperationResult.new(false, "当前不在商店")
	if intel < 1:
		return OperationResult.new(false, "情报不足：移除需要 1 情报")
	if tactic_id not in tactic_ids or tactic_ids.size() <= 4:
		return OperationResult.new(false, "至少保留四张临时战术")
	intel -= 1
	tactic_ids.erase(tactic_id)
	return OperationResult.new(true)

func leave_shop() -> OperationResult:
	if phase != Phase.SHOP:
		return OperationResult.new(false, "当前不在商店")
	route_stage = 1
	phase = Phase.ROUTE
	return OperationResult.new(true)

func to_snapshot() -> Dictionary:
	return {
		"phase": phase,
		"seed_value": seed_value,
		"rng_state": rng.snapshot_state(),
		"build_id": build_id,
		"player_health": player_health,
		"intel": intel,
		"route_stage": route_stage,
		"selected_route_ids": selected_route_ids.duplicate(),
		"technique_ids": technique_ids.duplicate(),
		"technique_upgrades": technique_upgrades.duplicate(true),
		"tactic_ids": tactic_ids.duplicate(),
		"current_enemy_id": current_enemy_id,
		"current_intent_id": current_intent_id,
		"reward_options": reward_options.duplicate(true),
		"tactic_draw_pile": tactic_draw_pile.duplicate(),
		"tactic_discard": tactic_discard.duplicate(),
		"battle": battle.state.to_snapshot() if battle != null else {},
		"result_copy": result_copy,
	}

func restore_snapshot(snapshot: Dictionary) -> OperationResult:
	for key in ["phase", "seed_value", "rng_state", "build_id", "player_health", "intel", "route_stage", "technique_ids", "tactic_ids"]:
		if not snapshot.has(key):
			return OperationResult.new(false, "引擎切片存档缺少字段：%s" % key)
	phase = int(snapshot["phase"])
	seed_value = int(snapshot["seed_value"])
	rng = RunRng.new(seed_value)
	rng.restore_state(int(snapshot["rng_state"]))
	build_id = snapshot["build_id"]
	player_health = int(snapshot["player_health"])
	intel = int(snapshot["intel"])
	route_stage = int(snapshot["route_stage"])
	selected_route_ids.assign(snapshot.get("selected_route_ids", []))
	technique_ids.assign(snapshot["technique_ids"])
	technique_upgrades = snapshot.get("technique_upgrades", {}).duplicate(true)
	tactic_ids.assign(snapshot["tactic_ids"])
	current_enemy_id = snapshot.get("current_enemy_id", &"")
	current_intent_id = snapshot.get("current_intent_id", &"")
	reward_options.assign(snapshot.get("reward_options", []))
	tactic_draw_pile.assign(snapshot.get("tactic_draw_pile", []))
	tactic_discard.assign(snapshot.get("tactic_discard", []))
	result_copy = snapshot.get("result_copy", "")
	var battle_snapshot: Dictionary = snapshot.get("battle", {})
	if not battle_snapshot.is_empty():
		battle = EngineBattleController.new(null, player_health, technique_ids, technique_upgrades, catalog)
		battle.restore(battle_snapshot)
	return OperationResult.new(true)

func _begin_battle(enemy_id: StringName) -> OperationResult:
	var enemy := catalog.enemy(enemy_id)
	if enemy == null:
		return OperationResult.new(false, "遭遇定义不存在")
	current_enemy_id = enemy_id
	battle = EngineBattleController.new(enemy, player_health, technique_ids, technique_upgrades, catalog)
	tactic_draw_pile.assign(rng.shuffle(tactic_ids))
	tactic_discard.clear()
	phase = Phase.BATTLE
	return start_next_turn()

func _draw_tactics(count: int) -> Array[StringName]:
	var result: Array[StringName] = []
	for _index in count:
		if tactic_draw_pile.is_empty():
			if tactic_discard.is_empty():
				break
			tactic_draw_pile.assign(rng.shuffle(tactic_discard))
			tactic_discard.clear()
		result.append(tactic_draw_pile.pop_front())
	return result

func _intent_for_current_turn() -> StringName:
	var enemy := current_enemy()
	var pool := enemy.intent_ids
	if (
		not enemy.phase_two_intent_ids.is_empty()
		and battle.state.enemy_health <= ceili(float(enemy.max_health) * enemy.phase_two_threshold)
	):
		pool = enemy.phase_two_intent_ids
	return pool[(battle.state.turn - 1) % pool.size()]

func _generate_reward_options() -> void:
	reward_options.clear()
	var new_techniques: Array[StringName] = []
	for technique_id in catalog.technique_ids():
		if technique_id not in technique_ids:
			new_techniques.append(technique_id)
	var upgradeable: Array[StringName] = []
	for technique_id in technique_ids:
		if not technique_upgrades.has(technique_id):
			upgradeable.append(technique_id)
	var new_tactics: Array[StringName] = []
	for tactic_id in catalog.tactic_ids():
		if tactic_id not in tactic_ids:
			new_tactics.append(tactic_id)
	if not new_techniques.is_empty():
		reward_options.append({"kind": &"technique", "id": rng.shuffle(new_techniques)[0]})
	if not upgradeable.is_empty():
		reward_options.append({"kind": &"upgrade", "id": rng.shuffle(upgradeable)[0]})
	if not new_tactics.is_empty():
		reward_options.append({"kind": &"tactic", "id": rng.shuffle(new_tactics)[0]})
