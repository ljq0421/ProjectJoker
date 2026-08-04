class_name DiceFirstResolver
extends RefCounted

const ReportScript = preload("res://scripts/dice_first/dice_first_resolution_report.gd")
const RESONANCE_DEFINITIONS := [
	{"id": &"triplet", "display_name": "三个相同", "energy": 2, "score": 10},
	{"id": &"pair", "display_name": "一个对子", "energy": 1, "score": 4},
	{"id": &"straight", "display_name": "四个连续", "energy": 2, "score": 8},
	{"id": &"polar_loop", "display_name": "三对都凑成 7", "energy": 3, "score": 12},
]
const TABLE_RULE_DEFINITIONS := {
	&"echo": {
		"display_name": "跨台共振",
		"copy": "左右出现同一点数：该点数再计一次，每组 +1能量",
	},
	&"polar": {
		"display_name": "极性回路",
		"copy": "左右骰子之和为 7：较高点再计一次，每组 +1能量",
	},
	&"charge": {
		"display_name": "蓄能台",
		"copy": "右台骰子不计基础分；每种不同点数 +1能量，全异时左台最高点再计一次",
	},
}
const BREAKTHROUGH_THRESHOLD := 2
const REROLL_SCORE_PER_DIE := 2
const REROLL_ENERGY_PER_DIE := 1

func resolve(state):
	if state == null: return _invalid("骰子状态不存在")
	var report = ReportScript.new()
	var values: Dictionary = {}
	for die in state.dice: values[die.id] = die.value
	for played_card in state.played_cards:
		if played_card == null or played_card.definition == null: return _invalid("改骰定义不存在")
		for effect in played_card.effective_effects():
			var error := _apply_instruction(values, played_card, effect)
			if not error.is_empty(): return _invalid(error)
		report.events.append(ResolutionEvent.new(played_card.definition.id, "改骰：%s" % played_card.definition.display_name, 0, report.total))
	report.effective_die_values = values.duplicate(true)
	var die_ids := _all_die_ids(state, values)
	report.combo_candidates = _build_combo_candidates(die_ids, values)
	for candidate in state.initial_combo_candidates:
		report.initial_combo_candidates.append(candidate.duplicate(true))
	for die_id in die_ids: report.base_total += int(values[die_id])
	report.total = report.base_total
	report.events.append(ResolutionEvent.new(&"base_dice", "六颗骰子", report.base_total, report.total))
	report.resonances = _detect_resonances(die_ids, values)
	for entry in report.resonances:
		report.resonance_score += int(entry["score"])
		report.resonance_energy += int(entry["energy"])
		report.total += int(entry["score"])
		report.events.append(ResolutionEvent.new(StringName(entry["id"]), String(entry["display_name"]), int(entry["score"]), report.total))
	_resolve_combo_changes(report, state, values)
	_resolve_table_rule(report, state, values, die_ids)
	report.reroll_score_cost = state.rerolled_die_ids.size() * REROLL_SCORE_PER_DIE
	report.reroll_energy_cost = state.rerolled_die_ids.size() * REROLL_ENERGY_PER_DIE
	if report.reroll_score_cost > 0:
		report.total -= report.reroll_score_cost
		report.events.append(ResolutionEvent.new(&"risk_reroll", "重投 %d 颗" % state.rerolled_die_ids.size(), -report.reroll_score_cost, report.total))
	report.energy_before_cost = report.resonance_energy + report.upgrade_energy + report.table_energy
	report.energy = maxi(report.energy_before_cost - report.reroll_energy_cost, 0)
	report.breakthrough_available = report.energy >= BREAKTHROUGH_THRESHOLD and not report.resonant_die_ids().is_empty()
	report.breakthrough_requested = state.breakthrough_requested
	if report.breakthrough_available:
		report.breakthrough_die_id = _highest_resonant_die(report.resonant_die_ids(), values)
		report.breakthrough_delta = int(values[report.breakthrough_die_id])
	if state.breakthrough_requested and report.breakthrough_available:
		report.breakthrough_applied = true
		report.total += report.breakthrough_delta
		report.events.append(ResolutionEvent.new(&"breakthrough", "破局：%s 再计一次" % String(report.breakthrough_die_id).to_upper(), report.breakthrough_delta, report.total))
	return report

func _resolve_table_rule(report, state, values: Dictionary, die_ids: Array[StringName]) -> void:
	report.table_rule_id = state.table_rule_id if TABLE_RULE_DEFINITIONS.has(state.table_rule_id) else &"echo"
	var definition: Dictionary = TABLE_RULE_DEFINITIONS[report.table_rule_id]
	report.table_display_name = String(definition["display_name"])
	report.table_rule_copy = String(definition["copy"])
	report.left_table_die_ids.assign(state.left_table_die_ids)
	report.right_table_die_ids.assign(state.right_table_die_ids)
	var assigned: Array[StringName] = []
	for raw_id in report.left_table_die_ids:
		var die_id := StringName(raw_id)
		if die_id not in die_ids or die_id in assigned:
			report.table_reason = "规则台包含无效或重复骰子"
			return
		assigned.append(die_id)
	for raw_id in report.right_table_die_ids:
		var die_id := StringName(raw_id)
		if die_id not in die_ids or die_id in assigned:
			report.table_reason = "规则台包含无效或重复骰子"
			return
		assigned.append(die_id)
	if report.left_table_die_ids.size() != 3 or report.right_table_die_ids.size() != 3:
		report.table_reason = "左台 3 颗 · 右台 3 颗"
		return
	if assigned.size() != die_ids.size():
		report.table_reason = "六颗骰子都必须进入规则台"
		return
	report.table_allocation_complete = true
	report.table_reason = "分配完成"
	match report.table_rule_id:
		&"polar": _resolve_relation_table(report, values, &"polar")
		&"charge": _resolve_charge_table(report, values)
		_: _resolve_relation_table(report, values, &"echo")

func _resolve_relation_table(report, values: Dictionary, rule_id: StringName) -> void:
	report.table_matches = _best_relation_pairs(
		report.left_table_die_ids,
		report.right_table_die_ids,
		values,
		rule_id
	)
	for pair in report.table_matches:
		var left_value := int(pair["left_value"])
		var right_value := int(pair["right_value"])
		var bonus := int(pair["bonus"])
		report.table_score += bonus
		report.table_energy += 1
		report.total += bonus
		var source_id := (
			StringName("polar_link_%d_%d" % [mini(left_value, right_value), maxi(left_value, right_value)])
			if rule_id == &"polar"
			else StringName("cross_table_echo_%d" % left_value)
		)
		var label := (
			"极性连接 %d + %d：较高点再计" % [left_value, right_value]
			if rule_id == &"polar"
			else "跨台同值 %d：再计一次" % left_value
		)
		report.events.append(ResolutionEvent.new(source_id, label, bonus, report.total))
		report.table_detail_lines.append("%s=%d ↔ %s=%d · +%d分" % [
			String(pair["left_id"]).to_upper(), left_value,
			String(pair["right_id"]).to_upper(), right_value,
			bonus,
		])

func _best_relation_pairs(
	left_ids: Array[StringName],
	right_ids: Array[StringName],
	values: Dictionary,
	rule_id: StringName
) -> Array[Dictionary]:
	var left: Array[StringName] = []
	var right: Array[StringName] = []
	left.assign(left_ids)
	right.assign(right_ids)
	left.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	right.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	var best: Array[Dictionary] = []
	var best_score := -1
	var best_signature := ""
	for first in right:
		for second in right:
			if second == first: continue
			for third in right:
				if third == first or third == second: continue
				var permutation: Array[StringName] = [first, second, third]
				var pairs: Array[Dictionary] = []
				var score := 0
				for index in range(3):
					var left_id := left[index]
					var right_id := permutation[index]
					var left_value := int(values[left_id])
					var right_value := int(values[right_id])
					var matches := left_value + right_value == 7 if rule_id == &"polar" else left_value == right_value
					if not matches: continue
					var bonus := maxi(left_value, right_value)
					pairs.append({
						"left_id": left_id, "right_id": right_id,
						"left_value": left_value, "right_value": right_value,
						"bonus": bonus,
					})
					score += bonus
				var signature := ",".join(pairs.map(func(pair: Dictionary) -> String: return "%s-%s" % [pair["left_id"], pair["right_id"]]))
				if pairs.size() > best.size() or (pairs.size() == best.size() and score > best_score) or (pairs.size() == best.size() and score == best_score and (best_signature.is_empty() or signature < best_signature)):
					best = pairs
					best_score = score
					best_signature = signature
	return best

func _resolve_charge_table(report, values: Dictionary) -> void:
	var stored_total := 0
	var distinct_values: Dictionary = {}
	for die_id in report.right_table_die_ids:
		var value := int(values[die_id])
		stored_total += value
		distinct_values[value] = true
	report.table_score -= stored_total
	report.table_energy = distinct_values.size()
	report.total -= stored_total
	report.events.append(ResolutionEvent.new(&"charge_store", "蓄能台：右台骰子封存", -stored_total, report.total))
	report.table_detail_lines.append("右台封存 −%d分 · %d种点数 +%d能量" % [stored_total, distinct_values.size(), report.table_energy])
	if distinct_values.size() != 3: return
	var release_id := _highest_die(report.left_table_die_ids, values)
	var release_value := int(values[release_id])
	report.table_score += release_value
	report.total += release_value
	report.events.append(ResolutionEvent.new(&"charge_release", "蓄能充满：左台最高点再计", release_value, report.total))
	report.table_detail_lines.append("右台全异 · %s 再计 +%d分" % [String(release_id).to_upper(), release_value])

func _highest_die(die_ids: Array[StringName], values: Dictionary) -> StringName:
	var best: StringName = &""
	for die_id in die_ids:
		if best == &"" or int(values[die_id]) > int(values[best]) or (int(values[die_id]) == int(values[best]) and String(die_id) < String(best)): best = die_id
	return best

func _build_combo_candidates(die_ids: Array[StringName], values: Dictionary) -> Array[Dictionary]:
	var counts: Dictionary = {}
	var ids_by_value: Dictionary = {}
	for die_id in die_ids:
		var value := int(values[die_id])
		counts[value] = int(counts.get(value, 0)) + 1
		if not ids_by_value.has(value): ids_by_value[value] = []
		ids_by_value[value].append(die_id)
	var result: Array[Dictionary] = []
	for value in range(1, 7):
		var count := int(counts.get(value, 0))
		if count >= 2:
			result.append({
				"id": StringName("same_%d" % value), "kind": &"same", "value": value,
				"initial_size": count, "die_ids": ids_by_value[value].duplicate(),
				"label": "%s %d" % ["一对" if count == 2 else "%d 个" % count, value],
				"goal": "再得到一个 %d，就会升级" % value,
			})
	var run_values := _longest_straight_values(counts)
	if run_values.size() >= 4:
		var run_ids: Array[StringName] = []
		var required_values: Dictionary = {}
		for value in run_values:
			var run_id := StringName(ids_by_value[value][0])
			run_ids.append(run_id)
			required_values[run_id] = value
		result.append({
			"id": StringName("run_%d_%d" % [run_values[0], run_values[-1]]), "kind": &"run",
			"initial_size": run_values.size(), "die_ids": run_ids,
			"start_value": run_values[0], "end_value": run_values[-1], "required_values": required_values,
			"label": "%d–%d 连续" % [run_values[0], run_values[-1]], "goal": "把连续长度再增加 1",
		})
	if die_ids.size() == 6 and _is_polar_loop(counts):
		result.append({"id": &"sum_seven", "kind": &"polar", "initial_size": 6, "die_ids": die_ids.duplicate(), "label": "三对都凑成 7", "goal": "已达到该组合上限"})
	return result

func _resolve_combo_changes(report, state, values: Dictionary) -> void:
	var candidates: Array[Dictionary] = report.combo_candidates if state.initial_combo_candidates.is_empty() else report.initial_combo_candidates
	var affected_ids: Array[StringName] = state.selected_reroll_die_ids if state.initial_combo_candidates.is_empty() else state.rerolled_die_ids
	for candidate in candidates:
		if _candidate_touches(candidate, affected_ids):
			report.broken_candidates.append(candidate.duplicate(true))
			continue
		report.preserved_candidates.append(candidate.duplicate(true))
		if not report.upgraded and not state.initial_combo_candidates.is_empty():
			var upgrade_label := _candidate_upgrade_label(candidate, values)
			if not upgrade_label.is_empty():
				report.upgraded = true
				report.upgraded_candidate = candidate.duplicate(true)
				report.upgrade_label = upgrade_label
	if report.upgraded:
		report.upgrade_energy = 1
		report.events.append(ResolutionEvent.new(&"combo_upgrade", "组合升级：%s，能量 +1" % report.upgrade_label, 0, report.total))

func _candidate_touches(candidate: Dictionary, die_ids: Array[StringName]) -> bool:
	for raw_id in candidate.get("die_ids", []):
		if StringName(raw_id) in die_ids: return true
	return false

func _candidate_upgrade_label(candidate: Dictionary, values: Dictionary) -> String:
	var initial_size := int(candidate.get("initial_size", 0))
	match StringName(candidate.get("kind", &"")):
		&"same":
			var target_value := int(candidate.get("value", 0))
			for raw_id in candidate.get("die_ids", []):
				if int(values.get(StringName(raw_id), 0)) != target_value: return ""
			var final_size := 0
			for value in values.values():
				if int(value) == target_value: final_size += 1
			if final_size > initial_size:
				return "%s → %d 个 %d" % [candidate.get("label", "组合"), final_size, target_value]
		&"run":
			var required_values: Dictionary = candidate.get("required_values", {})
			for raw_id in candidate.get("die_ids", []):
				var die_id := StringName(raw_id)
				if int(values.get(die_id, 0)) != int(required_values.get(die_id, 0)): return ""
			var counts: Dictionary = {}
			for value in values.values(): counts[int(value)] = true
			var final_size := _run_size_containing(counts, int(candidate.get("start_value", 0)), int(candidate.get("end_value", 0)))
			if final_size > initial_size:
				return "%s → %d 个连续" % [candidate.get("label", "连续"), final_size]
	return ""

func _run_size_containing(counts: Dictionary, start_value: int, end_value: int) -> int:
	if start_value <= 0 or end_value <= 0: return 0
	for value in range(start_value, end_value + 1):
		if int(counts.get(value, 0)) <= 0: return 0
	var left := start_value
	var right := end_value
	while left > 1 and int(counts.get(left - 1, 0)) > 0: left -= 1
	while right < 6 and int(counts.get(right + 1, 0)) > 0: right += 1
	return right - left + 1

func _detect_resonances(die_ids: Array[StringName], values: Dictionary) -> Array[Dictionary]:
	var counts: Dictionary = {}
	var ids_by_value: Dictionary = {}
	for die_id in die_ids:
		var value := int(values[die_id])
		counts[value] = int(counts.get(value, 0)) + 1
		if not ids_by_value.has(value): ids_by_value[value] = []
		ids_by_value[value].append(die_id)
	var matches: Dictionary = {}
	var triplet_ids: Array[StringName] = []
	var pair_ids: Array[StringName] = []
	for value in range(1, 7):
		var count := int(counts.get(value, 0))
		if count >= 3:
			for raw_id in ids_by_value[value]: triplet_ids.append(StringName(raw_id))
		elif count == 2:
			for raw_id in ids_by_value[value]: pair_ids.append(StringName(raw_id))
	if not triplet_ids.is_empty(): matches[&"triplet"] = triplet_ids
	if not pair_ids.is_empty(): matches[&"pair"] = pair_ids
	var run_values := _longest_straight_values(counts)
	if run_values.size() >= 4:
		var run_ids: Array[StringName] = []
		for value in run_values:
			for raw_id in ids_by_value[value]: run_ids.append(StringName(raw_id))
		matches[&"straight"] = run_ids
	if die_ids.size() == 6 and _is_polar_loop(counts): matches[&"polar_loop"] = die_ids.duplicate()
	var result: Array[Dictionary] = []
	for definition in RESONANCE_DEFINITIONS:
		var resonance_id := StringName(definition["id"])
		if matches.has(resonance_id):
			var entry: Dictionary = definition.duplicate(true)
			entry["die_ids"] = matches[resonance_id]
			result.append(entry)
	return result

func _apply_instruction(values: Dictionary, played_card: PlayedCard, effect: EffectSpec) -> String:
	match effect.operation:
		EffectSpec.Operation.ADJUST_DIE:
			if not values.has(played_card.primary_target): return "改骰指向未知骰子"
			values[played_card.primary_target] = clampi(int(values[played_card.primary_target]) + effect.amount, 1, 6)
		EffectSpec.Operation.FLIP_DIE:
			if not values.has(played_card.primary_target): return "改骰指向未知骰子"
			values[played_card.primary_target] = 7 - int(values[played_card.primary_target])
		_:
			return "原型不支持该改骰方式"
	return ""

func _all_die_ids(state, values: Dictionary) -> Array[StringName]:
	var ids: Array[StringName] = []
	for die in state.dice:
		if values.has(die.id): ids.append(die.id)
	return ids

func _longest_straight_values(counts: Dictionary) -> Array[int]:
	var best: Array[int] = []
	var current: Array[int] = []
	for value in range(1, 7):
		if int(counts.get(value, 0)) > 0:
			current.append(value)
			if current.size() > best.size(): best = current.duplicate()
		else: current.clear()
	return best

func _is_polar_loop(counts: Dictionary) -> bool:
	return int(counts.get(1, 0)) == int(counts.get(6, 0)) and int(counts.get(2, 0)) == int(counts.get(5, 0)) and int(counts.get(3, 0)) == int(counts.get(4, 0))

func _highest_resonant_die(die_ids: Array[StringName], values: Dictionary) -> StringName:
	var best: StringName = &""
	for die_id in die_ids:
		if best == &"" or int(values[die_id]) > int(values[best]) or (int(values[die_id]) == int(values[best]) and String(die_id) < String(best)): best = die_id
	return best

func _invalid(reason: String):
	var report = ReportScript.new()
	report.valid = false
	report.reason = reason
	return report
