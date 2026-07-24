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
	var reverse_order := false

	for played_card in state.played_cards:
		for effect in played_card.definition.effects:
			match effect.operation:
				EffectSpec.Operation.ADJUST_DIE:
					if not die_values.has(played_card.primary_target):
						return _invalid("card targets an unknown die")
					die_values[played_card.primary_target] = clampi(
						die_values[played_card.primary_target] + effect.amount,
						1,
						6
					)
				EffectSpec.Operation.MODIFY_COEFFICIENT:
					if not table_ids.has(played_card.primary_target):
						return _invalid("card targets an unknown table")
					coefficient_modifiers[played_card.primary_target] = (
						coefficient_modifiers.get(played_card.primary_target, 0) + effect.amount
					)
				EffectSpec.Operation.REPEAT_TABLE:
					if not table_ids.has(played_card.primary_target):
						return _invalid("card targets an unknown table")
					repeat_counts[played_card.primary_target] = (
						repeat_counts.get(played_card.primary_target, 0) + effect.amount
					)
				EffectSpec.Operation.REVERSE_RESOLUTION:
					reverse_order = not reverse_order
		report.events.append(ResolutionEvent.new(
			played_card.definition.id,
			played_card.definition.display_name,
			0,
			report.total
		))

	var ordered_rules := encounter.rules.duplicate()
	if reverse_order:
		ordered_rules.reverse()

	for rule in ordered_rules:
		var assigned_ids: Array = state.assignments.get(rule.id, [])
		var values: Array[int] = []
		for die_id in assigned_ids:
			if not die_values.has(die_id):
				return _invalid("assignment references an unknown die")
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
	return report

func _invalid(reason: String) -> ResolutionReport:
	var report := ResolutionReport.new()
	report.valid = false
	report.reason = reason
	return report
