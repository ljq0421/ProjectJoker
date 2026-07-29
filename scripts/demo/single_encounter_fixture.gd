class_name SingleEncounterFixture
extends RefCounted

const EXACT_SUM_TEMPLATE = preload(
	"res://resources/rules/templates/rule_exact_sum.tres"
)
const ALL_EVEN_TEMPLATE = preload(
	"res://resources/rules/templates/rule_all_even.tres"
)
const CONSECUTIVE_TEMPLATE = preload(
	"res://resources/rules/templates/rule_consecutive.tres"
)

static func make_state() -> RoundState:
	var state := RoundState.new()
	for value in range(1, 7):
		state.dice.append(DieState.new(StringName("d%d" % value), value))
	return state

static func make_encounter() -> EncounterDefinition:
	var encounter := EncounterDefinition.new()
	encounter.id = &"neon_training_room"
	encounter.rules = [
		_rule(
			&"left",
			"精确为 7",
			RuleDefinition.ConditionType.EXACT_SUM,
			2,
			2,
			7
		),
		_rule(
			&"middle",
			"连续三数",
			RuleDefinition.ConditionType.CONSECUTIVE,
			3,
			2
		),
		_rule(
			&"right",
			"单枚偶数",
			RuleDefinition.ConditionType.ALL_EVEN,
			1,
			3
		),
	]
	return encounter

static func make_hand() -> Array[CardDefinition]:
	return [
		_card(
			&"club_nudge",
			"拨码",
			CardDefinition.TargetType.DIE,
			EffectSpec.Operation.ADJUST_DIE,
			-1,
			"令一颗骰子的点数 -1，最终点数限制在 1..6。",
			PackedStringArray(["骰值", "校准"])
		),
		_card(
			&"diamond_map",
			"映射",
			CardDefinition.TargetType.TABLE,
			EffectSpec.Operation.MODIFY_COEFFICIENT,
			1,
			"令一张规则台的系数 +1。",
			PackedStringArray(["规则台", "系数"])
		),
		_card(
			&"spade_link",
			"桥接",
			CardDefinition.TargetType.GAP,
			EffectSpec.Operation.LINK_NEIGHBORS,
			1,
			"把左侧规则台的已解析结果传递到右侧规则台。",
			PackedStringArray(["桌间", "传递"])
		),
		_card(
			&"heart_reverse",
			"倒序",
			CardDefinition.TargetType.GLOBAL,
			EffectSpec.Operation.REVERSE_RESOLUTION,
			0,
			"反转本轮规则台的解析顺序。",
			PackedStringArray(["全局", "顺序"])
		),
	]

static func _rule(
	id: StringName,
	display_name: String,
	condition_type: RuleDefinition.ConditionType,
	slot_count: int,
	coefficient: int,
	target_value: int = 0
) -> RuleDefinition:
	var rule := RuleDefinition.new()
	rule.id = id
	rule.display_name = display_name
	rule.condition_type = condition_type
	match condition_type:
		RuleDefinition.ConditionType.EXACT_SUM:
			rule.template = EXACT_SUM_TEMPLATE
		RuleDefinition.ConditionType.ALL_EVEN:
			rule.template = ALL_EVEN_TEMPLATE
		RuleDefinition.ConditionType.CONSECUTIVE:
			rule.template = CONSECUTIVE_TEMPLATE
	rule.slot_count = slot_count
	rule.coefficient = coefficient
	rule.target_value = target_value
	return rule

static func _card(
	id: StringName,
	display_name: String,
	target_type: CardDefinition.TargetType,
	operation: EffectSpec.Operation,
	amount: int,
	rule_text: String,
	tags: PackedStringArray
) -> CardDefinition:
	var effect := EffectSpec.new()
	effect.operation = operation
	effect.amount = amount
	var card := CardDefinition.new()
	card.id = id
	card.display_name = display_name
	card.target_type = target_type
	card.effects = [effect]
	card.rule_text = rule_text
	card.tags = tags
	card.suit = _suit_for(id)
	card.rank_label = "1"
	card.rarity = CardDefinition.Rarity.COMMON
	return card

static func _suit_for(card_id: StringName) -> CardDefinition.Suit:
	var prefix := String(card_id).get_slice("_", 0)
	match prefix:
		"heart":
			return CardDefinition.Suit.HEARTS
		"diamond":
			return CardDefinition.Suit.DIAMONDS
		"spade":
			return CardDefinition.Suit.SPADES
	return CardDefinition.Suit.CLUBS
