class_name EngineSliceCatalog
extends RefCounted

const EngineTechniqueDefinition = preload("res://scripts/engine_slice/engine_technique_definition.gd")
const EngineTacticDefinition = preload("res://scripts/engine_slice/engine_tactic_definition.gd")
const EngineIntentDefinition = preload("res://scripts/engine_slice/engine_intent_definition.gd")
const EngineEnemyDefinition = preload("res://scripts/engine_slice/engine_enemy_definition.gd")

const DICE_CONTROL := &"dice_control"
const TABLE_CHAIN := &"table_chain"

var _techniques: Dictionary = {}
var _tactics: Dictionary = {}
var _intents: Dictionary = {}
var _enemies: Dictionary = {}

func _init() -> void:
	_build_techniques()
	_build_tactics()
	_build_intents()
	_build_enemies()

func technique(id: StringName) -> EngineTechniqueDefinition:
	return _techniques.get(id)

func tactic(id: StringName) -> EngineTacticDefinition:
	return _tactics.get(id)

func intent(id: StringName) -> EngineIntentDefinition:
	return _intents.get(id)

func enemy(id: StringName) -> EngineEnemyDefinition:
	return _enemies.get(id)

func technique_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	result.assign(_techniques.keys())
	result.sort()
	return result

func tactic_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	result.assign(_tactics.keys())
	result.sort()
	return result

func enemy_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	result.assign(_enemies.keys())
	result.sort()
	return result

func build_definition(build_id: StringName) -> Dictionary:
	if build_id == TABLE_CHAIN:
		return {
			"id": TABLE_CHAIN,
			"display_name": "规则台连锁",
			"description": "消耗高价值骰制造倍率、复写与额外引擎骰。",
			"techniques": [&"map_attack", &"map_guard", &"repeat_attack", &"engine_charge"],
			"tactics": [&"focus_fire", &"guard_echo", &"overclock", &"quick_ledger", &"cancel_clause", &"golden_margin"],
		}
	return {
		"id": DICE_CONTROL,
		"display_name": "骰值控制",
		"description": "让骰子改值后回到骰盘，稳定满足三张规则台。",
		"techniques": [&"nudge_down", &"nudge_up", &"flip_value", &"set_four"],
		"tactics": [&"focus_fire", &"emergency_guard", &"second_wind", &"quick_ledger", &"cancel_clause", &"golden_margin"],
	}

func route_options(stage: int) -> Array[StringName]:
	var result: Array[StringName] = []
	result.assign(
		[&"gold_narrow_ledger", &"gold_parallel_proof"]
		if stage == 1
		else [&"gold_precise_steps", &"gold_even_split"]
	)
	return result

func validate() -> Array[String]:
	var errors: Array[String] = []
	var activation_ops := [&"adjust_down", &"adjust_up", &"flip", &"set_four", &"attack_multiplier", &"guard_multiplier", &"attack_repeat", &"guard_repeat", &"counter_percent", &"intent_pressure"]
	var rider_ops := [&"add_block_die", &"add_counter_die", &"add_damage_die", &"add_damage", &"add_damage_die_conditional", &"add_charge", &"retain_block", &"add_counter_gap", &"burst_bonus", &"burst_next_die", &"lane_reward", &"bundle"]
	var triggers := [&"marked_lane_pass", &"marked_any_lane_pass", &"lane_pass", &"tables_at_least", &"all_tables_pass"]
	if _techniques.size() != 12:
		errors.append("engine slice must define 12 persistent techniques")
	if _tactics.size() != 10:
		errors.append("engine slice must define 10 temporary tactics")
	if _enemies.size() != 5:
		errors.append("engine slice must define four route enemies and one dealer")
	for definition in _techniques.values():
		if definition.id == &"" or definition.display_name.is_empty():
			errors.append("engine technique is incomplete")
		for profile in [definition.base_profile, definition.upgrade_a_profile, definition.upgrade_b_profile]:
			if not profile.has("name") or not profile.has("description") or not profile.has("returns_die"):
				errors.append("engine technique %s has incomplete effect profile" % definition.id)
			for effect in profile.get("activation", []):
				if not effect is Dictionary or StringName(effect.get("op", &"")) == &"":
					errors.append("engine technique %s has invalid declarative effect" % definition.id)
				elif StringName(effect.get("op", &"")) not in activation_ops:
					errors.append("engine technique %s has unknown activation op" % definition.id)
			for effect in profile.get("riders", []):
				if not effect is Dictionary or StringName(effect.get("op", &"")) not in rider_ops:
					errors.append("engine technique %s has unknown rider op" % definition.id)
					continue
				var trigger := StringName(effect.get("trigger", &""))
				if trigger not in triggers:
					errors.append("engine technique %s has unknown rider trigger" % definition.id)
				if trigger in [&"marked_lane_pass", &"lane_pass"] and StringName(effect.get("lane", &"")) not in [&"attack", &"guard", &"engine"]:
					errors.append("engine technique %s has invalid rider lane" % definition.id)
		if definition.upgrade_a_profile.is_empty() or definition.upgrade_b_profile.is_empty():
			errors.append("engine technique %s has incomplete A/B upgrades" % definition.id)
	for definition in _enemies.values():
		if definition.intent_ids.is_empty():
			errors.append("engine enemy %s has no intents" % definition.id)
		for intent_id in definition.intent_ids + definition.phase_two_intent_ids:
			if not _intents.has(intent_id):
				errors.append("engine enemy %s references unknown intent %s" % [definition.id, intent_id])
	return errors

func _tech(
	id: StringName,
	name: String,
	description: String,
	socket: EngineTechniqueDefinition.SocketType,
	lane_tags: Array,
	base_profile: Dictionary,
	upgrade_a_profile: Dictionary,
	upgrade_b_profile: Dictionary,
	socket_value: int = 0
) -> void:
	var definition := EngineTechniqueDefinition.new()
	definition.id = id
	definition.display_name = name
	definition.description = description
	definition.socket_type = socket
	definition.socket_value = socket_value
	definition.lane_tags.assign(lane_tags)
	definition.base_profile = base_profile
	definition.upgrade_a_profile = upgrade_a_profile
	definition.upgrade_b_profile = upgrade_b_profile
	_techniques[id] = definition

func _profile(name: String, description: String, returns_die: bool, activation: Array, riders: Array) -> Dictionary:
	return {
		"name": name,
		"description": description,
		"returns_die": returns_die,
		"activation": activation,
		"riders": riders,
	}

func _build_techniques() -> void:
	_tech(&"nudge_down", "拨码", "任意骰 −1并返回；标记骰使护契通过时追加格挡。", EngineTechniqueDefinition.SocketType.ANY, [&"guard"],
		_profile("拨码", "任意骰 −1并返回；该骰使护契通过时额外获得其当前点数的格挡。", true, [{"op": &"adjust_down", "amount": 1}], [{"op": &"add_block_die", "trigger": &"marked_lane_pass", "lane": &"guard"}]),
		_profile("深拨", "改为 −2；该骰使护契通过时额外获得当前点数+2格挡。", true, [{"op": &"adjust_down", "amount": 2}], [{"op": &"add_block_die", "trigger": &"marked_lane_pass", "lane": &"guard", "amount": 2}]),
		_profile("借力", "保持 −1和基础追加格挡；再追加等于当前点数的固定反击。", true, [{"op": &"adjust_down", "amount": 1}], [{"op": &"add_block_die", "trigger": &"marked_lane_pass", "lane": &"guard"}, {"op": &"add_counter_die", "trigger": &"marked_lane_pass", "lane": &"guard"}]))
	_tech(&"nudge_up", "推码", "任意骰 +1并返回；标记骰使破绽通过时追加伤害。", EngineTechniqueDefinition.SocketType.ANY, [&"attack"],
		_profile("推码", "任意骰 +1并返回；该骰使破绽通过时追加其当前点数伤害。", true, [{"op": &"adjust_up", "amount": 1}], [{"op": &"add_damage_die", "trigger": &"marked_lane_pass", "lane": &"attack", "multiplier": 1}]),
		_profile("连推", "改为 +2；该骰使破绽通过时追加其当前点数伤害。", true, [{"op": &"adjust_up", "amount": 2}], [{"op": &"add_damage_die", "trigger": &"marked_lane_pass", "lane": &"attack", "multiplier": 1}]),
		_profile("冒进", "保持 +1；追加伤害改为点数×2，但本轮敌方伤害+2。", true, [{"op": &"adjust_up", "amount": 1}, {"op": &"intent_pressure", "amount": 2}], [{"op": &"add_damage_die", "trigger": &"marked_lane_pass", "lane": &"attack", "multiplier": 2}]))
	_tech(&"flip_value", "翻面", "骰值变为7−当前值并返回；标记骰使引擎通过时获得充能。", EngineTechniqueDefinition.SocketType.ANY, [&"engine"],
		_profile("翻面", "骰值变为7−当前值并返回；进入通过的引擎台时+1充能。", true, [{"op": &"flip"}], [{"op": &"add_charge", "trigger": &"marked_lane_pass", "lane": &"engine", "amount": 1}]),
		_profile("镜面蓄能", "翻面并返回；进入通过的引擎台时+2充能。", true, [{"op": &"flip"}], [{"op": &"add_charge", "trigger": &"marked_lane_pass", "lane": &"engine", "amount": 2}]),
		_profile("反照泄压", "翻面并返回；+1充能，本轮发生爆破时下回合额外+1骰。", true, [{"op": &"flip"}], [{"op": &"add_charge", "trigger": &"marked_lane_pass", "lane": &"engine", "amount": 1}, {"op": &"burst_next_die", "trigger": &"marked_lane_pass", "lane": &"engine", "amount": 1}]))
	_tech(&"set_four", "定标", "奇数骰变为4并返回；按通过的所在台追加对应收益。", EngineTechniqueDefinition.SocketType.ODD, [&"attack", &"guard", &"engine"],
		_profile("定标", "奇数骰变为4并返回；所在台通过时，破绽+4伤害、护契+4格挡或引擎+1充能。", true, [{"op": &"set_four"}], [{"op": &"lane_reward", "trigger": &"marked_any_lane_pass", "damage": 4, "block": 4, "charge": 1}]),
		_profile("稳态标尺", "对应收益提高为破绽+6、护契+6或引擎+2充能。", true, [{"op": &"set_four"}], [{"op": &"lane_reward", "trigger": &"marked_any_lane_pass", "damage": 6, "block": 6, "charge": 2}]),
		_profile("三台校准", "基础收益不变；三台同时通过时额外+8伤害、+8格挡、+2充能。", true, [{"op": &"set_four"}], [{"op": &"lane_reward", "trigger": &"marked_any_lane_pass", "damage": 4, "block": 4, "charge": 1}, {"op": &"bundle", "trigger": &"all_tables_pass", "damage": 8, "block": 8, "charge": 2}]))
	_tech(&"odd_lift", "奇数跃迁", "奇数骰+2并返回；标记骰使破绽通过时追加伤害。", EngineTechniqueDefinition.SocketType.ODD, [&"attack"],
		_profile("奇数跃迁", "奇数骰+2并返回；进入通过的破绽台时+3伤害。", true, [{"op": &"adjust_up", "amount": 2}], [{"op": &"add_damage", "trigger": &"marked_lane_pass", "lane": &"attack", "amount": 3}]),
		_profile("登顶", "奇数骰+2并返回；最终为6时追加+8伤害，否则+3。", true, [{"op": &"adjust_up", "amount": 2}], [{"op": &"add_damage_die_conditional", "trigger": &"marked_lane_pass", "lane": &"attack", "required_value": 6, "amount": 8, "fallback": 3}]),
		_profile("越轨", "奇数骰+2并返回；固定+6伤害，但本轮敌方伤害+2。", true, [{"op": &"adjust_up", "amount": 2}, {"op": &"intent_pressure", "amount": 2}], [{"op": &"add_damage", "trigger": &"marked_lane_pass", "lane": &"attack", "amount": 6}]))
	_tech(&"even_drop", "偶数深降", "偶数骰−2并返回；标记骰使护契通过时保留格挡。", EngineTechniqueDefinition.SocketType.EVEN, [&"guard"],
		_profile("偶数深降", "偶数骰−2并返回；进入通过的护契台时保留3格挡到下回合。", true, [{"op": &"adjust_down", "amount": 2}], [{"op": &"retain_block", "trigger": &"marked_lane_pass", "lane": &"guard", "amount": 3}]),
		_profile("缓降", "偶数骰−2并返回；保留值提高到5。", true, [{"op": &"adjust_down", "amount": 2}], [{"op": &"retain_block", "trigger": &"marked_lane_pass", "lane": &"guard", "amount": 5}]),
		_profile("落差反击", "保留3格挡；额外获得6−当前点数的固定反击。", true, [{"op": &"adjust_down", "amount": 2}], [{"op": &"retain_block", "trigger": &"marked_lane_pass", "lane": &"guard", "amount": 3}, {"op": &"add_counter_gap", "trigger": &"marked_lane_pass", "lane": &"guard"}]))
	_tech(&"map_attack", "破绽映射", "用偶数骰提高破绽倍率。", EngineTechniqueDefinition.SocketType.EVEN, [&"attack"],
		_profile("破绽映射", "消耗偶数骰，本轮破绽倍率+1。", false, [{"op": &"attack_multiplier", "amount": 1}], []),
		_profile("余影映射", "骰子返回，破绽倍率仍+1。", true, [{"op": &"attack_multiplier", "amount": 1}], []),
		_profile("双倍映射", "消耗骰子，破绽倍率+2，本轮敌方伤害+2。", false, [{"op": &"attack_multiplier", "amount": 2}, {"op": &"intent_pressure", "amount": 2}], []))
	_tech(&"map_guard", "护契映射", "用奇数骰提高护契倍率与反击比例。", EngineTechniqueDefinition.SocketType.ODD, [&"guard"],
		_profile("护契映射", "消耗奇数骰，护契倍率+1，反击比例+50%。", false, [{"op": &"guard_multiplier", "amount": 1}, {"op": &"counter_percent", "amount": 50}], []),
		_profile("回流映射", "骰子返回，护契倍率+1，反击比例+50%。", true, [{"op": &"guard_multiplier", "amount": 1}, {"op": &"counter_percent", "amount": 50}], []),
		_profile("尖契映射", "消耗骰子，护契倍率+2，反击比例+100%。", false, [{"op": &"guard_multiplier", "amount": 2}, {"op": &"counter_percent", "amount": 100}], []))
	_tech(&"repeat_attack", "破绽复写", "用6点骰追加破绽结算次数。", EngineTechniqueDefinition.SocketType.EXACT, [&"attack"],
		_profile("破绽复写", "消耗6点骰，破绽额外结算1次。", false, [{"op": &"attack_repeat", "amount": 1}], []),
		_profile("留档复写", "骰子返回，破绽仍额外结算1次。", true, [{"op": &"attack_repeat", "amount": 1}], []),
		_profile("三联复写", "消耗骰子，破绽额外结算2次，本轮敌方伤害+4。", false, [{"op": &"attack_repeat", "amount": 2}, {"op": &"intent_pressure", "amount": 4}], []), 6)
	_tech(&"repeat_guard", "护契复写", "用1点骰追加护契结算与反击比例。", EngineTechniqueDefinition.SocketType.EXACT, [&"guard"],
		_profile("护契复写", "消耗1点骰，护契额外结算1次，反击比例+25%。", false, [{"op": &"guard_repeat", "amount": 1}, {"op": &"counter_percent", "amount": 25}], []),
		_profile("回单", "骰子返回，维持基础收益。", true, [{"op": &"guard_repeat", "amount": 1}, {"op": &"counter_percent", "amount": 25}], []),
		_profile("追索", "消耗骰子，护契额外结算2次，反击比例+50%。", false, [{"op": &"guard_repeat", "amount": 2}, {"op": &"counter_percent", "amount": 50}], []), 1)
	_tech(&"engine_charge", "蓄能并轨", "用偶数骰在引擎通过时获得充能。", EngineTechniqueDefinition.SocketType.EVEN, [&"engine"],
		_profile("蓄能并轨", "消耗偶数骰；引擎通过时+2充能。", false, [], [{"op": &"add_charge", "trigger": &"lane_pass", "lane": &"engine", "amount": 2}]),
		_profile("闭环", "骰子返回；引擎通过时仍+2充能。", true, [], [{"op": &"add_charge", "trigger": &"lane_pass", "lane": &"engine", "amount": 2}]),
		_profile("超额并轨", "消耗骰子；+3充能，本轮每次爆破额外+5伤害。", false, [], [{"op": &"add_charge", "trigger": &"lane_pass", "lane": &"engine", "amount": 3}, {"op": &"burst_bonus", "trigger": &"lane_pass", "lane": &"engine", "amount": 5}]))
	_tech(&"gold_stamp", "金线盖印", "按通过规则台数量追加三类收益。", EngineTechniqueDefinition.SocketType.ODD, [&"attack", &"guard", &"engine"],
		_profile("金线盖印", "消耗奇数骰；至少两台通过时+4伤害、+4格挡、+1充能。", false, [], [{"op": &"bundle", "trigger": &"tables_at_least", "count": 2, "damage": 4, "block": 4, "charge": 1}]),
		_profile("双印", "至少两台通过时+6伤害、+6格挡、+1充能。", false, [], [{"op": &"bundle", "trigger": &"tables_at_least", "count": 2, "damage": 6, "block": 6, "charge": 1}]),
		_profile("总账印", "仅三台全通过时触发+12伤害、+12格挡、+2充能。", false, [], [{"op": &"bundle", "trigger": &"all_tables_pass", "damage": 12, "block": 12, "charge": 2}]))

func _tactic(id: StringName, name: String, description: String, effect: StringName, amount: int) -> void:
	var definition := EngineTacticDefinition.new()
	definition.id = id
	definition.display_name = name
	definition.description = description
	definition.effect_id = effect
	definition.amount = amount
	_tactics[id] = definition

func _build_tactics() -> void:
	_tactic(&"focus_fire", "锁定破绽", "本轮破绽 +4。", &"flat_damage", 4)
	_tactic(&"emergency_guard", "紧急护契", "本轮护契 +6。", &"flat_block", 6)
	_tactic(&"second_wind", "缓冲条款", "立即恢复 3 点生命。", &"heal", 3)
	_tactic(&"guard_echo", "护契回声", "本轮护契倍率 +1。", &"guard_multiplier", 1)
	_tactic(&"overclock", "超额计数", "下回合额外投 1 颗骰子。", &"next_die", 1)
	_tactic(&"quick_ledger", "速记账页", "本轮引擎收益 +1。", &"engine_bonus", 1)
	_tactic(&"cancel_clause", "撤销条款", "本轮敌方伤害 −5。", &"intent_reduction", 5)
	_tactic(&"golden_margin", "金色余量", "本轮破绽与护契各 +3。", &"flat_both", 3)
	_tactic(&"refresh_seal", "重开印章", "刷新全部常驻手法。", &"refresh", 1)
	_tactic(&"double_entry", "复式记账", "破绽倍率 +1，敌方伤害 +2。", &"risky_attack", 1)

func _intent(id: StringName, name: String, description: String, damage: int, effect: StringName = &"", amount: int = 0) -> void:
	var definition := EngineIntentDefinition.new()
	definition.id = id
	definition.display_name = name
	definition.description = description
	definition.damage = damage
	definition.effect_id = effect
	definition.effect_amount = amount
	_intents[id] = definition

func _build_intents() -> void:
	_intent(&"probe", "试算", "造成 7 点伤害。", 7)
	_intent(&"levy", "征税", "造成 9 点伤害；引擎未通过时再 +3。", 9, &"engine_tax", 3)
	_intent(&"seal", "封签", "造成 8 点伤害；引擎未通过则下轮封锁一张手法。", 8, &"lock_technique", 1)
	_intent(&"drain", "抽离", "造成 10 点伤害；护契未通过则下轮少投一骰。", 10, &"drain_die", 1)
	_intent(&"compound", "复利", "造成 12 点伤害；破绽未通过时再 +4。", 12, &"attack_tax", 4)
	_intent(&"audit", "总账审计", "造成 14 点伤害，并提高本轮压力。", 14, &"pressure", 2)

func _enemy(
	id: StringName,
	name: String,
	subtitle: String,
	health: int,
	enrage: int,
	attack_rule: Dictionary,
	guard_rule: Dictionary,
	engine_rule: Dictionary,
	intent_ids: Array[StringName],
	phase_two: Array[StringName] = []
) -> void:
	var definition := EngineEnemyDefinition.new()
	definition.id = id
	definition.display_name = name
	definition.subtitle = subtitle
	definition.max_health = health
	definition.enrage_turn = enrage
	definition.attack_rule = attack_rule
	definition.guard_rule = guard_rule
	definition.engine_rule = engine_rule
	definition.intent_ids = intent_ids
	definition.phase_two_intent_ids = phase_two
	definition.portrait_path = (
		"res://resources/ui/dream_glass/engine_slice/iron_abacus.png"
		if id == &"dealer_iron_abacus_engine"
		else "res://resources/ui/dream_glass/feedback/seal_dealer.svg"
	)
	_enemies[id] = definition

func _build_enemies() -> void:
	_enemy(&"gold_precise_steps", "精确步阶", "金线试算员", 32, 5, _sum_rule("精确为 7", "exact", 7), _pair_rule("同奇偶", "same_parity"), _single_rule("高点蓄能", "min", 4), [&"probe", &"levy"])
	_enemy(&"gold_even_split", "偶数分流", "双轨征税员", 36, 5, _pair_rule("全偶", "all_even"), _sum_rule("至多为 7", "max", 7), _single_rule("奇数蓄能", "odd", 0), [&"levy", &"seal"])
	_enemy(&"gold_narrow_ledger", "窄幅账页", "金线校对官", 46, 6, _sum_rule("总和 8–10", "range", 8, 10), _pair_rule("固定差 2", "difference", 2), _single_rule("低点蓄能", "max", 3), [&"drain", &"levy", &"seal"])
	_enemy(&"gold_parallel_proof", "并行校核", "契据监理", 50, 6, _pair_rule("两枚互异", "distinct"), _sum_rule("精确为 8", "exact", 8), _single_rule("偶数蓄能", "even", 0), [&"seal", &"compound", &"drain"])
	_enemy(&"dealer_iron_abacus_engine", "铁算盘", "金线回廊庄家 · 两阶段总账", 100, 8, _sum_rule("精确为 9", "exact", 9), _sum_rule("至少为 8", "min", 8), _single_rule("高点蓄能", "min", 5), [&"levy", &"seal", &"compound"], [&"audit", &"drain", &"compound", &"seal", &"levy"])

func _sum_rule(name: String, kind: String, value: int, maximum: int = 0) -> Dictionary:
	return {"display_name": name, "kind": kind, "value": value, "maximum": maximum, "coefficient": 2}

func _pair_rule(name: String, kind: String, value: int = 0) -> Dictionary:
	return {"display_name": name, "kind": kind, "value": value, "coefficient": 2}

func _single_rule(name: String, kind: String, value: int) -> Dictionary:
	return {"display_name": name, "kind": kind, "value": value}
