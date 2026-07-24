class_name CardRules
extends RefCounted

const MAX_CARDS_PER_ROUND := 2

static func play_card(state: RoundState, played_card: PlayedCard) -> ActionResult:
	if played_card.definition == null:
		return ActionResult.new(false, "card definition is required", state)
	if state.played_cards.size() >= MAX_CARDS_PER_ROUND:
		return ActionResult.new(false, "at most two cards may be played per round", state)
	if (
		played_card.definition.target_type != CardDefinition.TargetType.GLOBAL
		and played_card.primary_target == &""
	):
		return ActionResult.new(false, "card target is required", state)
	if (
		played_card.definition.target_type == CardDefinition.TargetType.GAP
		and played_card.secondary_target == &""
	):
		return ActionResult.new(false, "gap cards require two neighboring tables", state)

	var next_state := state.clone()
	next_state.played_cards.append(played_card.clone())
	return ActionResult.new(true, "", next_state)
