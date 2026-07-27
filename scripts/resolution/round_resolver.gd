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
	var reverse_order := (
		encounter.rule_profile != null
		and encounter.rule_profile.resolution_direction
			== EncounterRuleProfile.ResolutionDirection.RIGHT_TO_LEFT
	)

	for played_card in state.played_cards:
		for effect in played_card.effective_effects():
			var single_table_target: StringName = (
				played_card.secondary_target
				if (
					played_card.definition.target_type
					== CardDefinition.TargetType.GAP
				)
				else played_card.primary_target
			)
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
					if not table_ids.has(single_table_target):
						return _invalid("手法牌指向了未知规则轨")
					coefficient_modifiers[single_table_target] = (
						coefficient_modifiers.get(single_table_target, 0)
						+ effect.amount
					)
				EffectSpec.Operation.REPEAT_TABLE:
					if not table_ids.has(single_table_target):
						return _invalid("手法牌指向了未知规则轨")
					repeat_counts[single_table_target] = (
						repeat_counts.get(single_table_target, 0)
						+ effect.amount
					)
				EffectSpec.Operation.REVERSE_RESOLUTION:
					reverse_order = not reverse_order
				EffectSpec.Operation.LINK_NEIGHBORS:
					if (
						not table_ids.has(played_card.primary_target)
						or not table_ids.has(played_card.secondary_target)
					):
						return _invalid("桥接牌指向了未知规则轨")
					if not neighbor_links.has(played_card.secondary_target):
						neighbor_links[played_card.secondary_target] = []
					neighbor_links[played_card.secondary_target].append({
						"source_table": played_card.primary_target,
						"card_id": played_card.definition.id,
						"card_name": played_card.definition.display_name,
						"is_mirror_copy": played_card.is_mirror_copy,
						"source_card_id": played_card.source_card_id,
						"source_slot_id": played_card.source_slot_id,
						"mirror_slot_id": _gap_id(played_card),
					})
		var card_label: String = played_card.definition.display_name
		if played_card.is_mirror_copy:
			card_label = "镜像副本：%s｜%s｜%s" % [
				card_label,
				_target_arrow(played_card),
				_effect_copy(played_card.effective_effects()),
			]
		report.events.append(ResolutionEvent.new(
			played_card.definition.id,
			card_label,
			0,
			report.total,
			true,
			played_card.is_mirror_copy,
			played_card.source_card_id,
			played_card.source_slot_id,
			_gap_id(played_card)
		))

	var ordered_rules := encounter.rules.duplicate()
	if reverse_order:
		ordered_rules.reverse()
	var ordered_rule_ids: Array[StringName] = []
	for rule in ordered_rules:
		ordered_rule_ids.append(rule.id)
	report.resolution_direction = (
		EncounterRuleProfile.ResolutionDirection.RIGHT_TO_LEFT
		if reverse_order
		else EncounterRuleProfile.ResolutionDirection.LEFT_TO_RIGHT
	)
	report.ordered_rule_ids.assign(ordered_rule_ids)

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
			state, assigned_ids, rule.id, normalized_context
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
			elif resolved_table_totals.has(outcome.target_table_id):
				_append_outcome(report, outcome)
			elif ordered_rule_ids.find(outcome.target_table_id) < rule_index:
				_append_outcome(report, EngravingOutcome.new(
					outcome.source_id,
					"%s：目标规则台 %s 未通过" % [
						outcome.label,
						outcome.target_table_id,
					],
					0,
					&"",
					false
				))
			else:
				if not pending_bridges.has(outcome.target_table_id):
					pending_bridges[outcome.target_table_id] = []
				pending_bridges[outcome.target_table_id].append(outcome)

		if neighbor_links.has(rule.id):
			for link in neighbor_links[rule.id]:
				var linked_value: int = resolved_table_totals.get(
					link.source_table,
					0
				)
				report.total += linked_value
				report.events.append(ResolutionEvent.new(
					link.card_id,
					"%s%s：%s → %s" % [
						"镜像副本：" if link.is_mirror_copy else "",
						link.card_name,
						link.source_table,
						rule.id,
					],
					linked_value,
					report.total,
					true,
					link.is_mirror_copy,
					link.source_card_id,
					link.source_slot_id,
					link.mirror_slot_id
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

func _gap_id(played_card: PlayedCard) -> StringName:
	var targets := {
		played_card.primary_target: true,
		played_card.secondary_target: true,
	}
	if targets.has(&"left") and targets.has(&"middle"):
		return &"left_gap"
	if targets.has(&"middle") and targets.has(&"right"):
		return &"right_gap"
	return &""

func _target_arrow(played_card: PlayedCard) -> String:
	return "%s → %s" % [
		played_card.primary_target,
		played_card.secondary_target,
	]

func _effect_copy(effects: Array[EffectSpec]) -> String:
	var parts: Array[String] = []
	for effect in effects:
		match effect.operation:
			EffectSpec.Operation.MODIFY_COEFFICIENT:
				parts.append("系数 %+d" % effect.amount)
			EffectSpec.Operation.REPEAT_TABLE:
				parts.append("额外结算 %d 次" % effect.amount)
			EffectSpec.Operation.LINK_NEIGHBORS:
				parts.append("连接两端")
			_:
				parts.append("派生效果")
	return "、".join(parts)
