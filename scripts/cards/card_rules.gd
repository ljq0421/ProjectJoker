class_name CardRules
extends RefCounted

const MAX_CARDS_PER_ROUND := 2

static func play_card(state: RoundState, played_card: PlayedCard) -> ActionResult:
	if played_card.definition == null:
		return ActionResult.new(false, "手法牌定义缺失", state)
	if state.played_cards.size() >= MAX_CARDS_PER_ROUND:
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

	var next_state := state.clone()
	next_state.played_cards.append(played_card.clone())
	return ActionResult.new(true, "", next_state)
