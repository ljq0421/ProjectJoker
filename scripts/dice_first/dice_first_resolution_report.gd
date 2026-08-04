class_name DiceFirstResolutionReport
extends RefCounted

var valid := true
var reason := ""
var total := 0
var base_total := 0
var energy := 0
var energy_before_cost := 0
var reroll_score_cost := 0
var reroll_energy_cost := 0
var resonance_score := 0
var resonance_energy := 0
var resonances: Array[Dictionary] = []
var combo_candidates: Array[Dictionary] = []
var initial_combo_candidates: Array[Dictionary] = []
var preserved_candidates: Array[Dictionary] = []
var broken_candidates: Array[Dictionary] = []
var upgraded := false
var upgrade_energy := 0
var upgrade_label := ""
var upgraded_candidate: Dictionary = {}
var table_allocation_complete := false
var table_reason := ""
var table_rule_id: StringName = &"echo"
var table_display_name := ""
var table_rule_copy := ""
var left_table_die_ids: Array[StringName] = []
var right_table_die_ids: Array[StringName] = []
var table_matches: Array[Dictionary] = []
var table_detail_lines: Array[String] = []
var table_score := 0
var table_energy := 0
var cross_table_echo_values: Array[int] = []
var cross_table_echo_score := 0
var cross_table_echo_energy := 0
var effective_die_values: Dictionary = {}
var events: Array[ResolutionEvent] = []
var breakthrough_available := false
var breakthrough_requested := false
var breakthrough_applied := false
var breakthrough_die_id: StringName = &""
var breakthrough_delta := 0

func has_resonance(resonance_id: StringName) -> bool:
	return resonances.any(func(entry: Dictionary) -> bool: return StringName(entry.get("id", &"")) == resonance_id)

func resonance_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for entry in resonances: ids.append(StringName(entry.get("id", &"")))
	return ids

func resonant_die_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for entry in resonances:
		for raw_id in entry.get("die_ids", []):
			var die_id := StringName(raw_id)
			if die_id not in ids: ids.append(die_id)
	return ids

func find_combo_candidate(candidate_id: StringName) -> Dictionary:
	for candidate in combo_candidates:
		if StringName(candidate.get("id", &"")) == candidate_id: return candidate
	return {}

func event_signature() -> Array[String]:
	var result: Array[String] = []
	for event in events: result.append("%s|%s|%d|%d|%s" % [event.source_id, event.label, event.delta, event.running_total, str(event.effect_applied)])
	return result
