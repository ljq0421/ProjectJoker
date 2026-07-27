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
	if (
		played_card.definition.target_type != CardDefinition.TargetType.GLOBAL
		and played_card.primary_target == &""
	):
		return ActionResult.new(false, "请选择手法牌目标", state)
	if (
		played_card.definition.target_type == CardDefinition.TargetType.GAP
		and played_card.secondary_target == &""
	):
		return ActionResult.new(false, "桌间手法牌需要两个相邻规则轨", state)
	for effect in played_card.definition.effects:
		if effect.operation == EffectSpec.Operation.ADJUST_DIE:
			var reason := EngravingResolver.new().modification_block_reason(
				state, played_card.primary_target, context
			)
			if not reason.is_empty():
				return ActionResult.new(false, reason, state)

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
	next_state.played_cards.append(original)
	if mirror_result.generated:
		next_state.played_cards.append(mirror_result.copy)
	if encounter != null:
		var report := RoundResolver.new().resolve(next_state, encounter, context)
		if not report.valid:
			return ActionResult.new(false, report.reason, state)
	return ActionResult.new(true, "", next_state)
