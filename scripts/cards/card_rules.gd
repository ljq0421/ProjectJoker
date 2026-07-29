class_name CardRules
extends RefCounted

const MAX_CARDS_PER_ROUND := 2

static func play_card(
	state: RoundState,
	played_card: PlayedCard,
	context: ResolutionContext = null,
	encounter: EncounterDefinition = null
) -> ActionResult:
	if played_card.definition == null:
		return ActionResult.new(false, "手法牌定义缺失", state)
	if played_card.is_mirror_copy:
		return ActionResult.new(false, "镜像副本不能作为真实牌使用", state)
	var real_card_count := 0
	for existing_card in state.played_cards:
		if existing_card is PlayedCard and not existing_card.is_mirror_copy:
			real_card_count += 1
	if real_card_count >= MAX_CARDS_PER_ROUND:
		return ActionResult.new(false, "每轮最多使用两张手法牌", state)
	var target_error := _validate_targets(state, played_card)
	if not target_error.is_empty():
		return ActionResult.new(false, target_error, state)
	var effect_error := _validate_effect_guards(
		state,
		played_card,
		context,
		encounter
	)
	if not effect_error.is_empty():
		return ActionResult.new(false, effect_error, state)

	var original := played_card.clone()
	original.play_id = StringName("play_%d" % (real_card_count + 1))
	var mirror_result := MirrorCopyResolver.new().resolve(
		original,
		state,
		encounter
	)
	if not mirror_result.accepted:
		return ActionResult.new(false, mirror_result.reason, state)

	var next_state := state.clone()
	for effect in original.effective_effects():
		if effect.operation == EffectSpec.Operation.REFUND_CALIBRATION:
			next_state.calibration_points = mini(
				next_state.calibration_points + effect.amount,
				2
			)
	next_state.played_cards.append(original)
	if mirror_result.generated:
		next_state.played_cards.append(mirror_result.copy)
	if encounter != null:
		var report := RoundResolver.new().resolve(next_state, encounter, context)
		if not report.valid:
			return ActionResult.new(false, report.reason, state)
	return ActionResult.new(true, "", next_state)

static func _validate_targets(
	state: RoundState,
	played_card: PlayedCard
) -> String:
	match played_card.definition.target_type:
		CardDefinition.TargetType.GLOBAL:
			return ""
		CardDefinition.TargetType.DICE_PAIR:
			if (
				played_card.primary_target == &""
				or played_card.secondary_target == &""
			):
				return "双骰手法牌需要选择两颗骰子"
			if played_card.primary_target == played_card.secondary_target:
				return "双骰手法牌需要两颗不同的骰子"
			if (
				state.find_die(played_card.primary_target) == null
				or state.find_die(played_card.secondary_target) == null
			):
				return "双骰手法牌指向了未知骰子"
		CardDefinition.TargetType.GAP:
			if played_card.primary_target == &"":
				return "请选择手法牌目标"
			if played_card.secondary_target == &"":
				return "桌间手法牌需要两个相邻规则轨"
		CardDefinition.TargetType.DIE:
			if played_card.primary_target == &"":
				return "请选择手法牌目标"
			if state.find_die(played_card.primary_target) == null:
				return "手法牌指向了未知骰子"
		_:
			if played_card.primary_target == &"":
				return "请选择手法牌目标"
	return ""

static func _validate_effect_guards(
	state: RoundState,
	played_card: PlayedCard,
	context: ResolutionContext,
	encounter: EncounterDefinition
) -> String:
	var engraving_resolver := EngravingResolver.new()
	for die_id in played_card.modified_die_ids():
		var reason := engraving_resolver.modification_block_reason(
			state,
			die_id,
			context
		)
		if not reason.is_empty():
			return reason
	for die_id in played_card.locked_die_ids():
		var reason := engraving_resolver.modification_block_reason(
			state,
			die_id,
			context
		)
		if not reason.is_empty():
			return reason
	for effect in played_card.effective_effects():
		if (
			effect.operation == EffectSpec.Operation.REFUND_CALIBRATION
			and state.calibration_points >= 2
		):
			return "尚未消耗校准点，不能回收刻度"
		if effect.operation == EffectSpec.Operation.MODIFY_CONDITION:
			if encounter == null:
				return "条件手法牌需要当前遭遇规则"
			var rule := _find_rule(encounter, played_card.primary_target)
			if rule == null:
				return "条件手法牌指向了未知规则台"
			if not _modifier_matches_rule(effect.condition_modifier, rule):
				return "这张条件手法牌与目标规则台不匹配"
			if (
				effect.condition_modifier
				== EffectSpec.ConditionModifier.INCREASE_SLOT_COUNT
			):
				var next_slot_count := (
					effective_slot_count(
						state,
						encounter,
						played_card.primary_target
					)
					+ effect.amount
				)
				if (
					rule.template != null
					and next_slot_count > rule.template.maximum_slot_count
				):
					return (
						"规则模板最多允许 %d 个骰位"
						% rule.template.maximum_slot_count
					)
				if next_slot_count > 6:
					return "加严后单张规则台不能超过六个骰位"
				var next_total := effect.amount
				for encounter_rule in encounter.rules:
					next_total += effective_slot_count(
						state,
						encounter,
						encounter_rule.id
					)
				if next_total > state.dice.size():
					return "加严后整局所需骰位超过六颗骰子"
		if (
			effect.operation
			== EffectSpec.Operation.GRANT_INTEL_ON_CONDITION
			and (
				effect.intel_condition
				== EffectSpec.IntelCondition.TARGET_TABLE_PASSED
			)
			and (
				encounter == null
				or _find_rule(encounter, played_card.primary_target) == null
			)
		):
			return "情报手法牌指向了未知规则台"
	return ""

static func effective_slot_count(
	state: RoundState,
	encounter: EncounterDefinition,
	table_id: StringName
) -> int:
	var rule := _find_rule(encounter, table_id)
	if rule == null:
		return 0
	var slot_count := rule.slot_count
	for played_card in state.played_cards:
		if played_card is not PlayedCard or played_card.primary_target != table_id:
			continue
		for effect in played_card.effective_effects():
			if (
				effect.operation == EffectSpec.Operation.MODIFY_CONDITION
				and (
					effect.condition_modifier
					== EffectSpec.ConditionModifier.INCREASE_SLOT_COUNT
				)
			):
				slot_count += effect.amount
	return slot_count

static func condition_modifiers(
	state: RoundState,
	table_id: StringName
) -> Array:
	var modifiers: Array = []
	for played_card in state.played_cards:
		if played_card is not PlayedCard or played_card.primary_target != table_id:
			continue
		for effect in played_card.effective_effects():
			if effect.operation == EffectSpec.Operation.MODIFY_CONDITION:
				modifiers.append(effect.condition_modifier)
	return modifiers

static func _modifier_matches_rule(
	modifier: EffectSpec.ConditionModifier,
	rule: RuleDefinition
) -> bool:
	if rule.template != null:
		return rule.template.supports_condition_modifier(modifier)
	match modifier:
		EffectSpec.ConditionModifier.EXACT_TOLERANCE:
			return rule.condition_type == RuleDefinition.ConditionType.EXACT_SUM
		EffectSpec.ConditionModifier.ALLOW_ONE_ODD:
			return rule.condition_type == RuleDefinition.ConditionType.ALL_EVEN
		EffectSpec.ConditionModifier.ALLOW_ONE_GAP:
			return rule.condition_type == RuleDefinition.ConditionType.CONSECUTIVE
		EffectSpec.ConditionModifier.INCREASE_SLOT_COUNT:
			return true
	return false

static func _find_rule(
	encounter: EncounterDefinition,
	table_id: StringName
) -> RuleDefinition:
	if encounter == null:
		return null
	for rule in encounter.rules:
		if rule.id == table_id:
			return rule
	return null
