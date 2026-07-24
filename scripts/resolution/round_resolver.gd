class_name RoundResolver
extends RefCounted

var _evaluator := RuleEvaluator.new()

func resolve(state: RoundState, encounter: EncounterDefinition) -> ResolutionReport:
	var report := ResolutionReport.new()
	var die_values: Dictionary = {}
	for die in state.dice:
		die_values[die.id] = die.value

	var table_ids: Dictionary = {}
	for rule in encounter.rules:
		table_ids[rule.id] = true

	var coefficient_modifiers: Dictionary = {}
	var repeat_counts: Dictionary = {}
	var neighbor_links: Dictionary = {}
	var reverse_order := false

	for played_card in state.played_cards:
		for effect in played_card.definition.effects:
			match effect.operation:
				EffectSpec.Operation.ADJUST_DIE:
					if not die_values.has(played_card.primary_target):
						return _invalid("手法牌指向了未知骰子")
					die_values[played_card.primary_target] = clampi(
						die_values[played_card.primary_target] + effect.amount,
						1,
						6
					)
				EffectSpec.Operation.MODIFY_COEFFICIENT:
					if not table_ids.has(played_card.primary_target):
						return _invalid("手法牌指向了未知规则轨")
					coefficient_modifiers[played_card.primary_target] = (
						coefficient_modifiers.get(played_card.primary_target, 0) + effect.amount
					)
				EffectSpec.Operation.REPEAT_TABLE:
					if not table_ids.has(played_card.primary_target):
						return _invalid("手法牌指向了未知规则轨")
					repeat_counts[played_card.primary_target] = (
						repeat_counts.get(played_card.primary_target, 0) + effect.amount
					)
				EffectSpec.Operation.REVERSE_RESOLUTION:
					reverse_order = not reverse_order
				EffectSpec.Operation.LINK_NEIGHBORS:
					if (
						not table_ids.has(played_card.primary_target)
						or not table_ids.has(played_card.secondary_target)
					):
						return _invalid("桥接牌指向了未知规则轨")
					neighbor_links[played_card.secondary_target] = {
						"source_table": played_card.primary_target,
						"card_id": played_card.definition.id,
						"card_name": played_card.definition.display_name,
					}
		report.events.append(ResolutionEvent.new(
			played_card.definition.id,
			played_card.definition.display_name,
			0,
			report.total
		))

	var ordered_rules := encounter.rules.duplicate()
	if reverse_order:
		ordered_rules.reverse()

	var resolved_table_totals: Dictionary = {}
	for rule in ordered_rules:
		var assigned_ids: Array = state.assignments.get(rule.id, [])
		var values: Array[int] = []
		for die_id in assigned_ids:
			if not die_values.has(die_id):
				return _invalid("规则轨包含未知骰子")
			values.append(die_values[die_id])

		var result := _evaluator.evaluate(
			rule,
			values,
			coefficient_modifiers.get(rule.id, 0)
		)
		if not result.valid:
			report.events.append(ResolutionEvent.new(rule.id, result.reason, 0, report.total))
			continue

		var resolution_count: int = 1 + repeat_counts.get(rule.id, 0)
		for repeat_index in range(resolution_count):
			report.total += result.total
			var label: String = rule.display_name
			if label.is_empty():
				label = String(rule.id)
			if repeat_index > 0:
				label += "（重复）"
			report.events.append(ResolutionEvent.new(
				rule.id,
				label,
				result.total,
				report.total
			))
		resolved_table_totals[rule.id] = result.total * resolution_count
		if neighbor_links.has(rule.id):
			var link: Dictionary = neighbor_links[rule.id]
			var linked_value: int = resolved_table_totals.get(link.source_table, 0)
			report.total += linked_value
			report.events.append(ResolutionEvent.new(
				link.card_id,
				"%s：%s → %s" % [link.card_name, link.source_table, rule.id],
				linked_value,
				report.total
			))
	return report

func _invalid(reason: String) -> ResolutionReport:
	var report := ResolutionReport.new()
	report.valid = false
	report.reason = reason
	return report
