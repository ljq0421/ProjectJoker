class_name RoundResolver
extends RefCounted

var _evaluator := RuleEvaluator.new()
var _engraving_resolver := EngravingResolver.new()

func resolve(
	state: RoundState,
	encounter: EncounterDefinition,
	context: ResolutionContext = null
) -> ResolutionReport:
	var normalized_context := context if context != null else ResolutionContext.empty()
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
	var ordered_rule_ids: Array[StringName] = []
	for rule in ordered_rules:
		ordered_rule_ids.append(rule.id)

	var resolved_table_totals: Dictionary = {}
	var pending_bridges: Dictionary = {}
	for rule_index in range(ordered_rules.size()):
		var rule: RuleDefinition = ordered_rules[rule_index]
		var assigned_ids: Array = state.assignments.get(rule.id, [])
		var values: Array[int] = []
		for die_id in assigned_ids:
			if not die_values.has(die_id):
				return _invalid("规则轨包含未知骰子")
			values.append(die_values[die_id])

		var requested_modifier: int = coefficient_modifiers.get(rule.id, 0)
		var minimum_modifier: int = 1 - rule.coefficient
		var effective_modifier: int = maxi(requested_modifier, minimum_modifier)
		var parity_overrides := _engraving_resolver.parity_overrides(
			state, assigned_ids, normalized_context
		)
		var result := _evaluator.evaluate(
			rule, values, effective_modifier, parity_overrides
		)
		if not result.valid:
			report.events.append(ResolutionEvent.new(rule.id, result.reason, 0, report.total))
			for pending in pending_bridges.get(rule.id, []):
				_append_outcome(report, EngravingOutcome.new(
					pending.source_id,
					"%s：目标规则台 %s 未通过" % [pending.label, rule.id],
					0,
					&"",
					false
				))
			pending_bridges.erase(rule.id)
			for outcome in _engraving_resolver.table_outcomes(
				state,
				assigned_ids,
				false,
				ordered_rule_ids,
				rule_index,
				die_values,
				normalized_context
			):
				_append_outcome(report, outcome)
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

		for pending in pending_bridges.get(rule.id, []):
			_append_outcome(report, pending)
		pending_bridges.erase(rule.id)

		for outcome in _engraving_resolver.table_outcomes(
			state,
			assigned_ids,
			true,
			ordered_rule_ids,
			rule_index,
			die_values,
			normalized_context
		):
			if outcome.target_table_id == &"":
				_append_outcome(report, outcome)
			else:
				if not pending_bridges.has(outcome.target_table_id):
					pending_bridges[outcome.target_table_id] = []
				pending_bridges[outcome.target_table_id].append(outcome)

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

	if normalized_context.dealer != null:
		var assigned: Dictionary = {}
		for table_id in state.assignments:
			for die_id in state.assignments[table_id]:
				assigned[die_id] = true
		report.assigned_dice = assigned.size()
		report.unassigned_dice = maxi(state.dice.size() - assigned.size(), 0)
		report.dealer_reward_lost = mini(
			normalized_context.dealer.fixed_reward,
			report.unassigned_dice * normalized_context.dealer.penalty_per_unassigned_die
		)
		report.dealer_reward = maxi(
			normalized_context.dealer.fixed_reward - report.dealer_reward_lost,
			0
		)
		report.total += report.dealer_reward
		report.events.append(ResolutionEvent.new(
			normalized_context.dealer.id,
			"%s：已分配 %d，未分配 %d，奖励 %d" % [
				normalized_context.dealer.display_name,
				report.assigned_dice,
				report.unassigned_dice,
				report.dealer_reward,
			],
			report.dealer_reward,
			report.total
		))
	return report

func _append_outcome(report: ResolutionReport, outcome: EngravingOutcome) -> void:
	if outcome.effect_applied:
		report.total += outcome.delta
	report.events.append(ResolutionEvent.new(
		outcome.source_id,
		outcome.label,
		outcome.delta if outcome.effect_applied else 0,
		report.total,
		outcome.effect_applied
	))

func _invalid(reason: String) -> ResolutionReport:
	var report := ResolutionReport.new()
	report.valid = false
	report.reason = reason
	return report
