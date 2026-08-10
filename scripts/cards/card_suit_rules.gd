class_name CardSuitRules
extends RefCounted

const SUIT_COPY := {
	CardDefinition.Suit.CLUBS: "梅花｜改造骰值",
	CardDefinition.Suit.HEARTS: "红桃｜保护、宽限与恢复",
	CardDefinition.Suit.DIAMONDS: "方片｜情报与资源效率",
	CardDefinition.Suit.SPADES: "黑桃｜额外结算、顺序与传递",
}

static func meaning_copy(suit: CardDefinition.Suit) -> String:
	return SUIT_COPY.get(suit, "未知花色语义")

static func rank_calibration_value(rank_label: String) -> int:
	if not rank_label.is_valid_int():
		return 0
	var rank := int(rank_label)
	if rank < 1 or rank > 10:
		return 0
	if rank <= 3:
		return 1
	if rank <= 6:
		return 2
	return 3

static func semantic_suit(card: CardDefinition) -> CardDefinition.Suit:
	if card == null:
		return CardDefinition.Suit.CLUBS
	var operations: Array[EffectSpec.Operation] = []
	for effect in card.effects:
		operations.append(effect.operation)
	for effect in card.mirror_effects:
		operations.append(effect.operation)
	for operation in operations:
		if operation in [
			EffectSpec.Operation.ADJUST_DIE,
			EffectSpec.Operation.SWAP_DICE,
			EffectSpec.Operation.COPY_DIE,
			EffectSpec.Operation.FLIP_DIE,
			EffectSpec.Operation.LOCK_DIE_WITH_BONUS,
			EffectSpec.Operation.FAULT_DIE,
		]:
			return CardDefinition.Suit.CLUBS
	for effect in card.effects:
		if effect.operation in [
			EffectSpec.Operation.REFUND_CALIBRATION,
			EffectSpec.Operation.GRANT_UNDOS,
		]:
			return CardDefinition.Suit.HEARTS
		if (
			effect.operation == EffectSpec.Operation.MODIFY_CONDITION
			and effect.condition_modifier
				!= EffectSpec.ConditionModifier.INCREASE_SLOT_COUNT
		):
			return CardDefinition.Suit.HEARTS
	for operation in operations:
		if operation in [
			EffectSpec.Operation.REPEAT_TABLE,
			EffectSpec.Operation.REVERSE_RESOLUTION,
			EffectSpec.Operation.LINK_NEIGHBORS,
			EffectSpec.Operation.BURNED_REWRITE,
		]:
			return CardDefinition.Suit.SPADES
	for operation in operations:
		if operation in [
			EffectSpec.Operation.MODIFY_COEFFICIENT,
			EffectSpec.Operation.GRANT_INTEL_ON_CONDITION,
			EffectSpec.Operation.ALL_IN,
			EffectSpec.Operation.MODIFY_CONDITION,
		]:
			return CardDefinition.Suit.DIAMONDS
	if not card.effects.is_empty() and card.effects[0].operation == EffectSpec.Operation.QUEUE_SEARCH:
		return (
			CardDefinition.Suit.CLUBS
			if card.effects[0].search_identity == &"dice_control"
			else CardDefinition.Suit.SPADES
		)
	return card.suit

static func validation_error(card: CardDefinition) -> String:
	if card == null or card.effects.is_empty():
		return ""
	var expected := semantic_suit(card)
	if card.suit != expected:
		return "%s 的%s与主要效果语义不一致，应为%s" % [
			card.id,
			card.suit_copy(),
			CardDefinition.suit_copy_for(expected),
		]
	return ""
