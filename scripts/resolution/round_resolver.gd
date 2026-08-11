class_name RoundResolver
extends RefCounted

const Phase3EngravingSetResolver = preload(
	"res://scripts/engravings/engraving_set_resolver.gd"
)

const Modifiers = preload("res://scripts/run/area_run_modifier_catalog.gd")

var _evaluator := RuleEvaluator.new()
var _engraving_resolver := EngravingResolver.new()
var _engraving_set_resolver = Phase3EngravingSetResolver.new()

func resolve(
	state: RoundState,
	encounter: EncounterDefinition,
	context: ResolutionContext = null
) -> ResolutionReport:
	var normalized_context := context if context != null else ResolutionContext.empty()
	var report := ResolutionReport.new()
	var die_values: Dictionary = {}
	for die in state.dice:
		die_values[die.id] = 1 if die.faulted else die.value

	var table_ids: Dictionary = {}
	for rule in encounter.rules:
		table_ids[rule.id] = true

	var coefficient_modifiers: Dictionary = {}
	var repeat_counts: Dictionary = {}
	var neighbor_links: Dictionary = {}
	var burned_rewrite_targets: Dictionary = {}
	var all_in_active := false
	var passed_rule_ids: Dictionary = {}
	var reverse_order := (
		encounter.rule_profile != null
		and encounter.rule_profile.resolution_direction
			== EncounterRuleProfile.ResolutionDirection.RIGHT_TO_LEFT
	)
	if (
		normalized_context.has_area_modifier(Modifiers.MIRROR_REVERSED_FLOW)
	):
		reverse_order = not reverse_order
		report.events.append(ResolutionEvent.new(
			Modifiers.MIRROR_REVERSED_FLOW,
			"区域异变·错位联动：初始结算方向已翻转",
			0,
			report.total,
			true
		))

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
				EffectSpec.Operation.SWAP_DICE:
					if (
						not die_values.has(played_card.primary_target)
						or not die_values.has(played_card.secondary_target)
					):
						return _invalid("换值手法牌指向了未知骰子")
					var first_value: int = die_values[played_card.primary_target]
					var second_value: int = die_values[played_card.secondary_target]
					if effect.amount != 0 and first_value == second_value:
						return _invalid(
							"换值联动需要选择当前有效点数不同的两颗骰子"
						)
					die_values[played_card.primary_target] = (
						second_value
					)
					die_values[played_card.secondary_target] = first_value
					if effect.amount != 0:
						var bonus_table_ids: Dictionary = {}
						for die_id in [
							played_card.primary_target,
							played_card.secondary_target,
						]:
							var assignment := state.find_assignment(die_id)
							var table_id: StringName = assignment.get("table_id", &"")
							if table_id == &"":
								continue
							if not table_ids.has(table_id):
								return _invalid("换值联动指向了未知规则台")
							bonus_table_ids[table_id] = true
						for table_id in bonus_table_ids:
							coefficient_modifiers[table_id] = (
								coefficient_modifiers.get(table_id, 0)
								+ effect.amount
							)
				EffectSpec.Operation.COPY_DIE:
					if (
						not die_values.has(played_card.primary_target)
						or not die_values.has(played_card.secondary_target)
					):
						return _invalid("复刻手法牌指向了未知骰子")
					die_values[played_card.secondary_target] = (
						die_values[played_card.primary_target]
					)
				EffectSpec.Operation.FLIP_DIE:
					if not die_values.has(played_card.primary_target):
						return _invalid("翻面手法牌指向了未知骰子")
					die_values[played_card.primary_target] = (
						7 - die_values[played_card.primary_target]
					)
				EffectSpec.Operation.LOCK_DIE_WITH_BONUS:
					if not die_values.has(played_card.primary_target):
						return _invalid("定格手法牌指向了未知骰子")
				EffectSpec.Operation.REFUND_CALIBRATION:
					pass
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
				EffectSpec.Operation.BURNED_REWRITE:
					if not table_ids.has(single_table_target):
						return _invalid("焚稿复写指向了未知规则轨")
					burned_rewrite_targets[single_table_target] = played_card.definition.id
				EffectSpec.Operation.ALL_IN:
					all_in_active = true
				EffectSpec.Operation.FAULT_DIE, EffectSpec.Operation.GRANT_UNDOS:
					pass
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
	report.effective_die_values = die_values.duplicate(true)

	var precomputed_results: Dictionary = {}
	var reverse_table_rules: Array[RuleDefinition] = []
	for rule in encounter.rules:
		var precomputed_assigned_ids: Array = state.assigned_die_ids(rule.id)
		var precomputed_values: Array[int] = []
		for die_id in precomputed_assigned_ids:
			if not die_values.has(die_id):
				return _invalid("规则轨包含未知骰子")
			precomputed_values.append(die_values[die_id])
		var category_bonus := 0
		if rule.template != null:
			category_bonus = int(
				normalized_context.category_coefficient_bonuses.get(
					int(rule.template.category), 0
				)
			)
		var fault_bonus := 0
		for die_id in precomputed_assigned_ids:
			var assigned_die := state.find_die(die_id)
			if assigned_die != null and assigned_die.faulted:
				fault_bonus += 3
		var requested_modifier: int = (
			coefficient_modifiers.get(rule.id, 0) + category_bonus + fault_bonus
		)
		var minimum_modifier: int = 1 - rule.coefficient
		var effective_modifier: int = maxi(requested_modifier, minimum_modifier)
		report.effective_table_coefficients[rule.id] = (
			rule.coefficient + effective_modifier
		)
		report.table_resolution_counts[rule.id] = (
			1 + repeat_counts.get(rule.id, 0)
		)
		var precomputed_result := _evaluator.evaluate(
			rule,
			precomputed_values,
			effective_modifier,
			_engraving_resolver.parity_overrides(
				state,
				precomputed_assigned_ids,
				rule.id,
				normalized_context
			),
			CardRules.condition_modifiers(state, rule.id),
			CardRules.effective_slot_count(state, encounter, rule.id),
			_engraving_resolver.sequence_overrides(
				state,
				precomputed_assigned_ids,
				normalized_context
			)
		)
		precomputed_results[rule.id] = precomputed_result
		report.rule_diagnostics[rule.id] = precomputed_result.diagnostics.duplicate(true)
		if (
			rule.template != null
			and rule.template.post_pass_effect
				== RuleTableTemplate.PostPassEffect.REVERSE_DIRECTION
		):
			reverse_table_rules.append(rule)
			if precomputed_result.valid:
				reverse_order = not reverse_order

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

	for rule in reverse_table_rules:
		var reverse_result: RuleResult = precomputed_results[rule.id]
		var reverse_label := (
			"%s：已通过，最终结算方向已翻转" % rule.display_name
			if reverse_result.valid
			else "%s：未填满，结算方向不变" % rule.display_name
		)
		report.events.append(ResolutionEvent.new(
			rule.template.id,
			reverse_label,
			0,
			report.total,
			reverse_result.valid
		))
		if not reverse_result.valid:
			report.rule_failures.append({
				"rule_id": rule.id,
				"display_name": rule.display_name,
				"reason": reverse_result.reason,
				"assigned_dice": state.assigned_die_ids(rule.id).size(),
			})
			_record_missed_effect(report, reverse_label)

	var resolved_table_totals: Dictionary = {}
	var pending_bridges: Dictionary = {}
	var bridge_rules: Array[RuleDefinition] = []
	for rule_index in range(ordered_rules.size()):
		var rule: RuleDefinition = ordered_rules[rule_index]
		if (
			rule.template != null
			and rule.template.post_pass_effect
				== RuleTableTemplate.PostPassEffect.BRIDGE_FORWARD
		):
			bridge_rules.append(rule)
		var assigned_ids: Array = state.assigned_die_ids(rule.id)
		var values: Array[int] = []
		for die_id in assigned_ids:
			if not die_values.has(die_id):
				return _invalid("规则轨包含未知骰子")
			values.append(die_values[die_id])

		var requested_modifier: int = coefficient_modifiers.get(rule.id, 0)
		var category_bonus := 0
		if rule.template != null:
			category_bonus = int(
				normalized_context.category_coefficient_bonuses.get(
					int(rule.template.category), 0
				)
			)
		var fault_bonus := 0
		for die_id in assigned_ids:
			var assigned_die := state.find_die(die_id)
			if assigned_die != null and assigned_die.faulted:
				fault_bonus += 3
		requested_modifier += category_bonus + fault_bonus
		var minimum_modifier: int = 1 - rule.coefficient
		var effective_modifier: int = maxi(requested_modifier, minimum_modifier)
		var parity_overrides := _engraving_resolver.parity_overrides(
			state, assigned_ids, rule.id, normalized_context
		)
		var result := _evaluator.evaluate(
			rule,
			values,
			effective_modifier,
			parity_overrides,
			CardRules.condition_modifiers(state, rule.id),
			CardRules.effective_slot_count(state, encounter, rule.id),
			_engraving_resolver.sequence_overrides(
				state,
				assigned_ids,
				normalized_context
			)
		)
		report.rule_diagnostics[rule.id] = result.diagnostics.duplicate(true)
		if not result.valid:
			report.events.append(ResolutionEvent.new(rule.id, result.reason, 0, report.total))
			report.rule_failures.append({
				"rule_id": rule.id,
				"display_name": (
					rule.display_name
					if not rule.display_name.is_empty()
					else String(rule.id)
				),
				"reason": result.reason,
				"assigned_dice": assigned_ids.size(),
			})
			if (
				rule.template != null
				and rule.template.post_pass_effect
					== RuleTableTemplate.PostPassEffect.ECHO_SELF
			):
				report.events.append(ResolutionEvent.new(
					rule.template.id,
					"%s：未通过，回声未触发" % rule.display_name,
					0,
					report.total,
					false
				))
				_record_missed_effect(
					report,
					"%s：未通过，回声未触发" % rule.display_name
				)
			for pending in pending_bridges.get(rule.id, []):
				_append_outcome(report, EngravingOutcome.new(
					pending.source_id,
					"%s：目标规则台 %s 未通过" % [pending.label, rule.id],
					0,
					&"",
					false,
					pending.source_table_id,
					pending.source_die_id
				))
			pending_bridges.erase(rule.id)
			_append_lock_rewards(
				report,
				state,
				assigned_ids,
				false
			)
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

		var table_total_before := report.total
		var lock_reward_total := 0
		var resolution_count: int = 1 + repeat_counts.get(rule.id, 0)
		for repeat_index in range(resolution_count):
			report.total += result.total
			if repeat_index == 0:
				report.record_score(
					ResolutionEvent.ScoreSource.BASE,
					result.base_sum + rule.flat_bonus
				)
				report.record_score(
					ResolutionEvent.ScoreSource.COEFFICIENT,
					result.base_sum * maxi(rule.coefficient - 1, 0)
				)
				report.record_score(
					ResolutionEvent.ScoreSource.CARD,
					result.base_sum * (
						coefficient_modifiers.get(rule.id, 0) + fault_bonus
					)
				)
				report.record_score(
					ResolutionEvent.ScoreSource.AREA_MODIFIER,
					result.base_sum * category_bonus
				)
			else:
				report.record_score(ResolutionEvent.ScoreSource.CARD, result.total)
			var label: String = rule.display_name
			if label.is_empty():
				label = String(rule.id)
			if repeat_index > 0:
				label += "（重复）"
			report.events.append(ResolutionEvent.new(
				rule.id,
				label,
				result.total,
				report.total,
				true,
				false,
				&"",
				&"",
				&"",
				(
					ResolutionEvent.ScoreSource.BASE
					if repeat_index == 0
					else ResolutionEvent.ScoreSource.CARD
				)
			))
			lock_reward_total += _append_lock_rewards(
				report,
				state,
				assigned_ids,
				true,
				label
			)
		if (
			rule.template != null
			and rule.template.post_pass_effect
				== RuleTableTemplate.PostPassEffect.ECHO_SELF
		):
			report.total += result.total
			report.record_score(ResolutionEvent.ScoreSource.RULE_CHAIN, result.total)
			report.events.append(ResolutionEvent.new(
				rule.template.id,
				"%s：回声重复本台基础得分" % rule.display_name,
				result.total,
				report.total
			))
			var echo_label := (
				rule.display_name
				if not rule.display_name.is_empty()
				else String(rule.id)
			)
			lock_reward_total += _append_lock_rewards(
				report,
				state,
				assigned_ids,
				true,
				"%s（回声）" % echo_label
			)
		if burned_rewrite_targets.has(rule.id):
			var rewrite_coefficient := maxi(
				int(report.effective_table_coefficients.get(rule.id, 1)) - 1,
				1
			)
			var rewrite_delta := result.base_sum * rewrite_coefficient + rule.flat_bonus
			report.add_score(ResolutionEvent.ScoreSource.CARD, rewrite_delta)
			report.events.append(ResolutionEvent.new(
				burned_rewrite_targets[rule.id],
				"焚稿复写：%s 以系数 %d 复写一次" % [
					rule.display_name, rewrite_coefficient,
				],
				rewrite_delta,
				report.total,
				true,
				false,
				&"",
				&"",
				&"",
				ResolutionEvent.ScoreSource.CARD,
				rule.id,
				rule.id,
				&"rewrite"
			))
		_append_lucky_face_outcomes(
			report,
			state,
			assigned_ids,
			die_values,
			report.effective_table_coefficients[rule.id],
			resolution_count,
			normalized_context,
			table_total_before
		)
		resolved_table_totals[rule.id] = (
			report.total - table_total_before - lock_reward_total
		)
		passed_rule_ids[rule.id] = true

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
					false,
					outcome.source_table_id,
					outcome.source_die_id
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
				report.record_score(ResolutionEvent.ScoreSource.CARD, linked_value)
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
					link.mirror_slot_id,
					ResolutionEvent.ScoreSource.CARD,
					link.source_table,
					rule.id,
					&"bridge"
				))
				if resolved_table_totals.has(link.source_table):
					report.successful_bridge_count += 1

	for bridge_rule in bridge_rules:
		var bridge_result: RuleResult = precomputed_results[bridge_rule.id]
		var bridge_index := ordered_rule_ids.find(bridge_rule.id)
		var target_id: StringName = (
			ordered_rule_ids[bridge_index + 1]
			if bridge_index >= 0 and bridge_index + 1 < ordered_rule_ids.size()
			else &""
		)
		var applied := (
			bridge_result.valid
			and target_id != &""
			and passed_rule_ids.has(target_id)
		)
		var delta := bridge_result.total if applied else 0
		report.total += delta
		report.record_score(ResolutionEvent.ScoreSource.RULE_CHAIN, delta)
		var reason := ""
		if not bridge_result.valid:
			reason = "本台未通过"
		elif target_id == &"":
			reason = "最终方向上没有相邻目标台"
		else:
			reason = "目标台 %s 未通过" % target_id
		report.events.append(ResolutionEvent.new(
			bridge_rule.template.id,
			(
				"%s：向 %s 传递本台基础得分"
				% [bridge_rule.display_name, target_id]
				if applied
				else "%s：桥接未触发，%s"
					% [bridge_rule.display_name, reason]
			),
			delta,
			report.total,
			applied,
			false,
			&"",
			&"",
			&"",
			ResolutionEvent.ScoreSource.RULE_CHAIN,
			bridge_rule.id,
			target_id,
			&"bridge"
		))
		if applied:
			report.successful_bridge_count += 1
		if not applied:
			_record_missed_effect(
				report,
				"%s：桥接未触发，%s" % [bridge_rule.display_name, reason]
			)
	if report.successful_bridge_count >= 3:
		report.storm_awarded = true
		report.add_score(ResolutionEvent.ScoreSource.RULE_CHAIN, 20)
		report.events.append(ResolutionEvent.new(
			&"bridge_storm",
			"风暴结算：本轮第三次成功桥接，固定 +20",
			20,
			report.total,
			true,
			false,
			&"",
			&"",
			&"",
			ResolutionEvent.ScoreSource.RULE_CHAIN,
			&"",
			&"",
			&"storm"
		))

	_append_area_modifier_outcome(
		report,
		state,
		die_values,
		resolved_table_totals,
		passed_rule_ids,
		normalized_context
	)
	for set_outcome in _engraving_set_resolver.bonus_outcomes(
		state, report, passed_rule_ids, normalized_context
	):
		_append_outcome(report, set_outcome)
		report.engraving_set_activations.append(set_outcome.source_id)

	_append_intel_outcomes(
		report,
		state,
		encounter,
		passed_rule_ids
	)
	if all_in_active and passed_rule_ids.size() == encounter.rules.size():
		var copied_intel := report.intel_delta
		report.intel_delta += copied_intel
		report.all_in_bonus_intel = copied_intel
		report.all_in_awarded = true
		report.events.append(ResolutionEvent.new(
			&"stage7_all_in",
			"孤注一掷：三台全过，本轮卡牌情报复制 +%d" % copied_intel,
			0,
			report.total,
			true
		))
	report.passed_rule_count = passed_rule_ids.size()
	var all_six_assigned := state.dice.size() == 6
	for die in state.dice:
		if not state.is_assigned(die.id):
			all_six_assigned = false
			break
	var full_clear := (
		all_six_assigned
		and encounter.rules.size() == 3
		and report.passed_rule_count == 3
	)
	report.full_clear_calibration_awarded = full_clear
	if full_clear and _all_values_share_parity(state.dice, die_values):
		var base_score := int(
			report.score_breakdown.get(ResolutionEvent.ScoreSource.BASE, 0)
		)
		var resonance_bonus := ceili(float(base_score) * 0.5)
		report.resonance_awarded = true
		report.add_score(ResolutionEvent.ScoreSource.RULE_CHAIN, resonance_bonus)
		report.events.append(ResolutionEvent.new(
			&"parity_resonance",
			"同调共鸣：六骰全分配、三台全过且最终值同奇偶，基础分追加 50%",
			resonance_bonus,
			report.total,
			true,
			false,
			&"",
			&"",
			&"",
			ResolutionEvent.ScoreSource.RULE_CHAIN,
			&"",
			&"",
			&"resonance"
		))
	if encounter.rules.size() == 3 and report.passed_rule_count == 0:
		report.consolation_awarded = true
		report.add_score(ResolutionEvent.ScoreSource.BASE, 5)
		report.events.append(ResolutionEvent.new(
			&"all_failed_consolation",
			"全败保底：三张规则台均未通过，安慰分 +5",
			5,
			report.total,
			true,
			false,
			&"",
			&"",
			&"",
			ResolutionEvent.ScoreSource.BASE,
			&"",
			&"",
			&"consolation"
		))

	var assigned: Dictionary = {}
	for table_id in state.assignments:
		for die_id in state.assigned_die_ids(table_id):
			assigned[die_id] = true
	report.assigned_dice = assigned.size()
	report.unassigned_dice = maxi(state.dice.size() - assigned.size(), 0)
	if normalized_context.dealer != null:
		var fixed_reward := normalized_context.dealer.fixed_reward
		if _all_six_dice_are_lucky(state, die_values, normalized_context):
			fixed_reward *= 2
			report.events.append(ResolutionEvent.new(
				&"expedition_fortune",
				"远征天运：六骰全部命中幸运面，庄家固定奖励翻倍",
				0,
				report.total,
				true
			))
		report.dealer_reward_lost = mini(
			fixed_reward,
			report.unassigned_dice * normalized_context.dealer.penalty_per_unassigned_die
		)
		report.dealer_reward = maxi(
			fixed_reward - report.dealer_reward_lost,
			0
		)
		report.total += report.dealer_reward
		report.record_score(
			ResolutionEvent.ScoreSource.DEALER,
			report.dealer_reward
		)
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

func _append_lucky_face_outcomes(
	report: ResolutionReport,
	state: RoundState,
	assigned_ids: Array,
	die_values: Dictionary,
	effective_coefficient: int,
	resolution_count: int,
	context: ResolutionContext,
	table_total_before: int
) -> void:
	if context.lucky_faces.is_empty():
		return
	var critical_ids: Array[StringName] = []
	var bonus := 0
	for die_id in assigned_ids:
		var die := state.find_die(die_id)
		if (
			die == null
			or context.lucky_faces.get(die_id, 0) != int(
				die_values.get(die_id, die.value)
			)
		):
			continue
		critical_ids.append(die_id)
		bonus += ceili(
			float(die_values.get(die_id, die.value) * effective_coefficient)
			* 0.5
		) * resolution_count
	if critical_ids.is_empty():
		return
	report.total += bonus
	report.record_score(ResolutionEvent.ScoreSource.LUCK, bonus)
	report.events.append(ResolutionEvent.new(
		&"lucky_critical",
		"幸运暴击：%s 命中幸运面，单骰贡献追加 50%%" % "、".join(critical_ids),
		bonus,
		report.total,
		true
	))
	if critical_ids.size() >= 3:
		var table_subtotal := report.total - table_total_before
		report.total += table_subtotal
		report.record_score(ResolutionEvent.ScoreSource.LUCK, table_subtotal)
		report.events.append(ResolutionEvent.new(
			&"full_table_critical",
			"满台爆击：同一规则台至少三颗暴击骰，本台结算翻倍",
			table_subtotal,
			report.total,
			true
		))

func _append_area_modifier_outcome(
	report: ResolutionReport,
	state: RoundState,
	die_values: Dictionary,
	resolved_table_totals: Dictionary,
	passed_rule_ids: Dictionary,
	context: ResolutionContext
) -> void:
	if context.area_modifier_ids.is_empty():
		return
	for modifier_id in context.area_modifier_ids:
		_append_single_area_modifier_outcome(
			report, state, die_values, resolved_table_totals,
			passed_rule_ids, context, modifier_id
		)

func _append_single_area_modifier_outcome(
	report: ResolutionReport,
	state: RoundState,
	die_values: Dictionary,
	resolved_table_totals: Dictionary,
	passed_rule_ids: Dictionary,
	context: ResolutionContext,
	modifier_id: StringName
) -> void:
	var passed_values: Array[int] = []
	for table_id in passed_rule_ids:
		for die_id in state.assigned_die_ids(table_id):
			passed_values.append(int(die_values.get(die_id, 0)))
	var delta := 0
	var applied := false
	var label := ""
	match modifier_id:
		Modifiers.GOLD_STRAIGHT_GIFT:
			applied = _longest_consecutive_run(passed_values) >= 3
			delta = 12 if applied else 0
			label = "区域异变·顺赐：通过台中的骰子形成三连顺子，额外 +12"
		Modifiers.GOLD_SAME_RADIANCE:
			var counts: Dictionary = {}
			for value in passed_values:
				counts[value] = counts.get(value, 0) + 1
			var pair_count := 0
			for value in counts:
				pair_count += int(counts[value]) / 2
			applied = pair_count > 0
			delta = pair_count * 4
			label = "区域异变·同辉：通过台组成 %d 对同点骰，额外 +%d" % [pair_count, delta]
		Modifiers.GOLD_EXTREME_GIFT:
			applied = not passed_values.is_empty()
			var maximum := 0
			for value in passed_values:
				maximum = maxi(maximum, value)
			delta = maximum * 2
			label = "区域异变·极值馈赠：最大点数 %d 额外结算两次" % maximum
		Modifiers.MIRROR_TWIN_ECHO:
			for played_card in state.played_cards:
				if played_card is PlayedCard and played_card.is_mirror_copy:
					applied = true
					break
			label = "区域异变·双生回响：镜像副本使用原牌完整效果"
		Modifiers.MIRROR_REVERSED_FLOW:
			return
		Modifiers.MIRROR_OVERFLOW_TRANSFER:
			applied = passed_rule_ids.size() == 3 and resolved_table_totals.size() == 3
			if applied:
				delta = 2147483647
				for table_id in resolved_table_totals:
					delta = mini(delta, int(resolved_table_totals[table_id]))
			label = "区域异变·缝隙溢分：三台通过，最低台结算分再传递一次"
		Modifiers.FACELESS_RULE_VEIL:
			applied = true
			label = "区域异变·规则虚化：全台占位限制放宽为至少两台"
		Modifiers.FACELESS_OPEN_HAND:
			applied = true
			label = "区域异变·无名通融：每轮真实手法牌上限 +1"
		_:
			return
	if applied:
		report.total += delta
		report.record_score(ResolutionEvent.ScoreSource.AREA_MODIFIER, delta)
	report.events.append(ResolutionEvent.new(
		modifier_id,
		label,
		delta if applied else 0,
		report.total,
		applied
	))
	if not applied:
		_record_missed_effect(report, label)

func _longest_consecutive_run(values: Array[int]) -> int:
	var unique: Dictionary = {}
	for value in values:
		unique[value] = true
	var sorted: Array = unique.keys()
	sorted.sort()
	var longest := 0
	var current := 0
	var previous := -99
	for value in sorted:
		current = current + 1 if int(value) == previous + 1 else 1
		longest = maxi(longest, current)
		previous = int(value)
	return longest

func _all_six_dice_are_lucky(
	state: RoundState,
	die_values: Dictionary,
	context: ResolutionContext
) -> bool:
	if state.dice.size() != 6 or context.lucky_faces.size() != 6:
		return false
	for die in state.dice:
		if context.lucky_faces.get(die.id, 0) != int(die_values.get(die.id, die.value)):
			return false
	return true

func _all_values_share_parity(dice: Array[DieState], die_values: Dictionary) -> bool:
	if dice.is_empty():
		return false
	var parity := int(die_values.get(dice[0].id, dice[0].value)) % 2
	for die in dice:
		if int(die_values.get(die.id, die.value)) % 2 != parity:
			return false
	return true

func _append_intel_outcomes(
	report: ResolutionReport,
	state: RoundState,
	encounter: EncounterDefinition,
	passed_rule_ids: Dictionary
) -> void:
	var assigned_die_ids: Dictionary = {}
	for table_id in state.assignments:
		for die_id in state.assigned_die_ids(table_id):
			assigned_die_ids[die_id] = true
	var all_tables_occupied := true
	for rule in encounter.rules:
		if not state.has_occupied_slot(rule.id):
			all_tables_occupied = false
			break

	for played_card in state.played_cards:
		if played_card is not PlayedCard:
			continue
		for effect in played_card.effective_effects():
			if (
				effect.operation
				!= EffectSpec.Operation.GRANT_INTEL_ON_CONDITION
			):
				continue
			var satisfied := false
			var condition_copy := ""
			match effect.intel_condition:
				EffectSpec.IntelCondition.TARGET_TABLE_PASSED:
					satisfied = passed_rule_ids.has(played_card.primary_target)
					condition_copy = "指定规则台已通过"
				EffectSpec.IntelCondition.ALL_DICE_ASSIGNED:
					satisfied = assigned_die_ids.size() == state.dice.size()
					condition_copy = "全部骰子已分配"
				EffectSpec.IntelCondition.ALL_TABLES_OCCUPIED:
					satisfied = all_tables_occupied
					condition_copy = "三张规则台均有骰子"
				EffectSpec.IntelCondition.ALL_TABLES_PASSED:
					satisfied = passed_rule_ids.size() == encounter.rules.size()
					condition_copy = "全部规则台已通过"
			if satisfied:
				report.intel_delta += effect.amount
			report.events.append(ResolutionEvent.new(
				played_card.definition.id,
				(
					"%s：%s，预计情报 +%d"
					% [
						played_card.definition.display_name,
						condition_copy,
						effect.amount,
					]
					if satisfied
					else "%s：%s未满足，情报 +0"
						% [played_card.definition.display_name, condition_copy]
				),
				0,
				report.total,
				satisfied
			))
			if not satisfied:
				_record_missed_effect(
					report,
					"%s：%s未满足，情报 +0"
					% [played_card.definition.display_name, condition_copy]
				)

func _append_lock_rewards(
	report: ResolutionReport,
	state: RoundState,
	assigned_ids: Array,
	table_passed: bool,
	trigger_label: String = ""
) -> int:
	var awarded_total := 0
	for played_card in state.played_cards:
		if played_card is not PlayedCard:
			continue
		if played_card.primary_target not in assigned_ids:
			continue
		for effect in played_card.effective_effects():
			if effect.operation != EffectSpec.Operation.LOCK_DIE_WITH_BONUS:
				continue
			var label := (
				"%s：%s成功结算，固定奖励 +%d"
				% [played_card.definition.display_name, trigger_label, effect.amount]
				if table_passed
				else "%s：定格骰所在规则台未通过"
					% played_card.definition.display_name
			)
			_append_outcome(report, EngravingOutcome.new(
				played_card.definition.id,
				label,
				effect.amount if table_passed else 0,
				&"",
				table_passed
			), ResolutionEvent.ScoreSource.CARD)
			if table_passed:
				awarded_total += effect.amount
	return awarded_total

func _append_outcome(
	report: ResolutionReport,
	outcome: EngravingOutcome,
	score_source: ResolutionEvent.ScoreSource = ResolutionEvent.ScoreSource.ENGRAVING
) -> void:
	if outcome.effect_applied:
		report.total += outcome.delta
		report.record_score(score_source, outcome.delta)
		if outcome.target_table_id != &"":
			report.successful_bridge_count += 1
	report.events.append(ResolutionEvent.new(
		outcome.source_id,
		outcome.label,
		outcome.delta if outcome.effect_applied else 0,
		report.total,
		outcome.effect_applied,
		false,
		&"",
		&"",
		&"",
		score_source,
		outcome.source_table_id,
		outcome.target_table_id,
		&"bridge" if outcome.target_table_id != &"" else &"",
		outcome.source_die_id
	))
	if not outcome.effect_applied:
		_record_missed_effect(report, outcome.label)

func _record_missed_effect(report: ResolutionReport, label: String) -> void:
	if label.is_empty() or label in report.missed_effects:
		return
	report.missed_effects.append(label)

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
