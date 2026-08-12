class_name EngineBattleResolver
extends RefCounted

const EngineBattleState = preload("res://scripts/engine_slice/engine_battle_state.gd")
const EngineBattleReport = preload("res://scripts/engine_slice/engine_battle_report.gd")
const EngineEnemyDefinition = preload("res://scripts/engine_slice/engine_enemy_definition.gd")
const EngineIntentDefinition = preload("res://scripts/engine_slice/engine_intent_definition.gd")

func resolve(state: EngineBattleState, enemy: EngineEnemyDefinition, intent: EngineIntentDefinition, catalog) -> EngineBattleReport:
	var report := EngineBattleReport.new()
	if state == null or enemy == null or intent == null or catalog == null:
		report.valid = false
		report.reason = "战斗解析缺少必要定义"
		return report
	var attack_values := _values(state, &"attack")
	var guard_values := _values(state, &"guard")
	var engine_values := _values(state, &"engine")
	report.attack_passed = _passes(enemy.attack_rule, attack_values, 2)
	report.guard_passed = _passes(enemy.guard_rule, guard_values, 2)
	report.engine_passed = _passes(enemy.engine_rule, engine_values, 1)
	var lane_passes := {&"attack": report.attack_passed, &"guard": report.guard_passed, &"engine": report.engine_passed}
	var passed_count := int(report.attack_passed) + int(report.guard_passed) + int(report.engine_passed)
	report.attack_damage = _sum(attack_values) * state.attack_multiplier * (1 + state.attack_repeats) if report.attack_passed else 0
	report.attack_damage += state.flat_damage
	report.block = state.carried_block + (_sum(guard_values) * state.guard_multiplier * (1 + state.guard_repeats) if report.guard_passed else 0)
	report.block += state.flat_block
	report.engine_dice = mini(2, 1 + state.engine_bonus) if report.engine_passed else 0
	report.engine_charge_before = state.engine_charge
	var rider_totals := {
		"damage": 0, "block": 0, "charge": 0, "flat_counter": 0,
		"retained_block": 0, "burst_bonus": 0, "burst_next_die": 0,
	}
	for technique_id in state.activated_technique_counts:
		var definition = catalog.technique(technique_id)
		if definition == null:
			continue
		var branch: StringName = state.technique_upgrades.get(technique_id, &"")
		var profile: Dictionary = definition.profile_for(branch)
		for activation_index in int(state.activated_technique_counts[technique_id]):
			for rider in profile.get("riders", []):
				_apply_rider(rider_totals, rider, technique_id, state, lane_passes, passed_count, activation_index)
	report.attack_damage += int(rider_totals.damage)
	report.block += int(rider_totals.block)
	report.retained_block_after = int(rider_totals.retained_block)
	report.engine_charge_gained = int(rider_totals.charge)
	var charge_total := report.engine_charge_before + report.engine_charge_gained
	report.burst_count = charge_total / 3
	report.engine_charge_after = charge_total % 3
	report.engine_damage = report.burst_count * (15 + int(rider_totals.burst_bonus))
	if report.burst_count > 0:
		report.engine_dice = mini(2, report.engine_dice + int(rider_totals.burst_next_die))
	report.damage = report.attack_damage + report.engine_damage
	report.total_damage = report.damage
	report.enemy_health_after = maxi(0, state.enemy_health - report.damage)
	report.enemy_defeated = report.enemy_health_after <= 0
	report.intent_id = intent.id
	report.intent_copy = intent.display_name
	if report.enemy_defeated:
		report.intent_cancelled = true
		report.player_health_after = state.player_health
		report.events.append("行动前击破，%s 已取消" % intent.display_name)
		return report
	var rage := maxi(0, state.turn - enemy.enrage_turn + 1) * 2
	report.incoming_before_block = intent.damage + rage + state.intent_pressure - state.intent_reduction
	if intent.effect_id == &"engine_tax" and not report.engine_passed:
		report.incoming_before_block += intent.effect_amount
		report.events.append("引擎未通过：征税 +%d" % intent.effect_amount)
	if intent.effect_id == &"attack_tax" and not report.attack_passed:
		report.incoming_before_block += intent.effect_amount
		report.events.append("破绽未通过：复利 +%d" % intent.effect_amount)
	report.incoming_before_block = maxi(0, report.incoming_before_block)
	report.block_absorbed = mini(report.block, report.incoming_before_block)
	report.incoming_damage = maxi(0, report.incoming_before_block - report.block)
	report.player_health_after = maxi(0, state.player_health - report.incoming_damage)
	report.player_defeated = report.player_health_after <= 0
	if report.guard_passed and not report.player_defeated:
		report.counter_damage = floori(float(report.block_absorbed * state.counter_percent) / 100.0) + int(rider_totals.flat_counter)
		report.enemy_health_after = maxi(0, report.enemy_health_after - report.counter_damage)
		report.total_damage += report.counter_damage
		report.enemy_defeated = report.enemy_health_after <= 0
	return report

func _apply_rider(totals: Dictionary, rider: Dictionary, technique_id: StringName, state: EngineBattleState, lane_passes: Dictionary, passed_count: int, activation_index: int) -> void:
	var trigger := StringName(rider.get("trigger", &""))
	var lane := StringName(rider.get("lane", &""))
	var die = null
	match trigger:
		&"lane_pass":
			if not bool(lane_passes.get(lane, false)):
				return
		&"tables_at_least":
			if passed_count < int(rider.get("count", 0)):
				return
		&"all_tables_pass":
			if passed_count != 3:
				return
		&"marked_lane_pass":
			die = _marked_die_in_lane(state, technique_id, lane, activation_index)
			if die == null or not bool(lane_passes.get(lane, false)):
				return
		&"marked_any_lane_pass":
			var marked := _marked_die_and_lane(state, technique_id, activation_index)
			if marked.is_empty() or not bool(lane_passes.get(marked.lane, false)):
				return
			die = marked.die
			lane = marked.lane
		_:
			return
	var op := StringName(rider.get("op", &""))
	match op:
		&"add_block_die": totals.block += die.value + int(rider.get("amount", 0))
		&"add_counter_die": totals.flat_counter += die.value
		&"add_damage_die": totals.damage += die.value * int(rider.get("multiplier", 1))
		&"add_damage": totals.damage += int(rider.get("amount", 0))
		&"add_damage_die_conditional": totals.damage += int(rider.get("amount", 0)) if die.value == int(rider.get("required_value", 0)) else int(rider.get("fallback", 0))
		&"add_charge": totals.charge += int(rider.get("amount", 0))
		&"retain_block": totals.retained_block += int(rider.get("amount", 0))
		&"add_counter_gap": totals.flat_counter += maxi(0, 6 - die.value)
		&"burst_bonus": totals.burst_bonus += int(rider.get("amount", 0))
		&"burst_next_die": totals.burst_next_die += int(rider.get("amount", 0))
		&"lane_reward":
			if lane == &"attack": totals.damage += int(rider.get("damage", 0))
			elif lane == &"guard": totals.block += int(rider.get("block", 0))
			elif lane == &"engine": totals.charge += int(rider.get("charge", 0))
		&"bundle":
			totals.damage += int(rider.get("damage", 0))
			totals.block += int(rider.get("block", 0))
			totals.charge += int(rider.get("charge", 0))

func _marked_die_in_lane(state: EngineBattleState, technique_id: StringName, lane_id: StringName, occurrence: int = 0):
	var matched := 0
	for die_id in state.assignments.get(lane_id, []):
		if technique_id in state.die_technique_marks.get(die_id, []):
			if matched == occurrence:
				return state.find_die(die_id)
			matched += 1
	return null

func _marked_die_and_lane(state: EngineBattleState, technique_id: StringName, occurrence: int = 0) -> Dictionary:
	var matched := 0
	for lane_id in state.assignments:
		for die_id in state.assignments.get(lane_id, []):
			if technique_id in state.die_technique_marks.get(die_id, []):
				if matched == occurrence:
					return {"die": state.find_die(die_id), "lane": lane_id}
				matched += 1
	return {}

func _values(state: EngineBattleState, lane_id: StringName) -> Array[int]:
	var result: Array[int] = []
	for die_id in state.assignments.get(lane_id, []):
		var die := state.find_die(die_id)
		if die != null:
			result.append(die.value)
	return result

func _passes(rule: Dictionary, values: Array[int], slots: int) -> bool:
	if values.size() != slots:
		return false
	var kind := String(rule.get("kind", ""))
	var total := _sum(values)
	match kind:
		"exact": return total == int(rule.get("value", 0))
		"min": return (values[0] if slots == 1 else total) >= int(rule.get("value", 0))
		"max": return (values[0] if slots == 1 else total) <= int(rule.get("value", 0))
		"range": return total >= int(rule.get("value", 0)) and total <= int(rule.get("maximum", 0))
		"all_even": return values.all(func(value: int) -> bool: return value % 2 == 0)
		"same_parity": return values[0] % 2 == values[1] % 2
		"distinct": return values[0] != values[1]
		"difference": return absi(values[0] - values[1]) == int(rule.get("value", 0))
		"odd": return values[0] % 2 == 1
		"even": return values[0] % 2 == 0
	return false

func _sum(values: Array[int]) -> int:
	var total := 0
	for value in values:
		total += value
	return total
