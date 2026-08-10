class_name BuildIdentityCatalog
extends RefCounted

const DICE_CONTROL := &"dice_control"
const TABLE_CHAIN := &"table_chain"
const INTEL_ECONOMY := &"intel_economy"

const IDS: Array[StringName] = [
	DICE_CONTROL,
	TABLE_CHAIN,
	INTEL_ECONOMY,
]

func all_ids() -> Array[StringName]:
	return IDS.duplicate()

func display_name(identity_id: StringName) -> String:
	match identity_id:
		DICE_CONTROL:
			return "骰值控制"
		TABLE_CHAIN:
			return "规则台连锁"
		INTEL_ECONOMY:
			return "情报经济"
	return "未分类"

func identity_for_card(card: CardDefinition) -> StringName:
	if card == null:
		return &""
	for effect in card.effects:
		if effect.operation == EffectSpec.Operation.QUEUE_SEARCH:
			return effect.search_identity
	for effect in card.effects:
		if effect.operation in [
			EffectSpec.Operation.REFUND_CALIBRATION,
			EffectSpec.Operation.GRANT_INTEL_ON_CONDITION,
		]:
			return INTEL_ECONOMY
	for effect in card.effects:
		if effect.operation in [
			EffectSpec.Operation.ADJUST_DIE,
			EffectSpec.Operation.SWAP_DICE,
			EffectSpec.Operation.COPY_DIE,
			EffectSpec.Operation.FLIP_DIE,
			EffectSpec.Operation.LOCK_DIE_WITH_BONUS,
		]:
			return DICE_CONTROL
	return TABLE_CHAIN

func deck_counts(
	deck_ids: Array[StringName],
	card_catalog: CardCatalog
) -> Dictionary:
	var counts := {
		DICE_CONTROL: 0,
		TABLE_CHAIN: 0,
		INTEL_ECONOMY: 0,
	}
	if card_catalog == null:
		return counts
	for card_id in deck_ids:
		var identity_id := identity_for_card(card_catalog.find_card(card_id))
		if counts.has(identity_id):
			counts[identity_id] += 1
	return counts

func route_identity_copy(
	identity_id: StringName,
	counts: Dictionary
) -> String:
	var deck_size := 0
	for value in counts.values():
		deck_size += int(value)
	return "%s · 当前牌组 %d / %d" % [
		display_name(identity_id),
		int(counts.get(identity_id, 0)),
		deck_size,
	]
