extends "res://tests/test_case.gd"

const ContentValidatorScript = preload("res://scripts/validation/content_validator.gd")
const RuleDefinitionScript = preload("res://scripts/rules/rule_definition.gd")
const CardDefinitionScript = preload("res://scripts/cards/card_definition.gd")
const EffectSpecScript = preload("res://scripts/cards/effect_spec.gd")
const FinalRestrictionDefinitionScript = preload(
	"res://scripts/run/final_restriction_definition.gd"
)
const DealerDefinitionScript = preload("res://scripts/dealers/dealer_definition.gd")

func run() -> void:
	var valid_rule := RuleDefinitionScript.new()
	valid_rule.id = &"left"
	valid_rule.display_name = "精确为七"
	valid_rule.slot_count = 2
	valid_rule.target_value = 7
	valid_rule.coefficient = 2

	var valid_effect := EffectSpecScript.new()
	valid_effect.operation = EffectSpecScript.Operation.MODIFY_COEFFICIENT
	valid_effect.amount = 1
	var valid_card := CardDefinitionScript.new()
	valid_card.id = &"diamond_boost"
	valid_card.display_name = "映射"
	valid_card.rule_text = "令一张规则台的系数 +1。"
	valid_card.tags = PackedStringArray(["规则台", "系数"])
	valid_card.target_type = CardDefinitionScript.TargetType.TABLE
	valid_card.suit = CardDefinitionScript.Suit.DIAMONDS
	valid_card.rank_label = "1"
	valid_card.rarity = CardDefinitionScript.Rarity.COMMON
	valid_card.effects = [valid_effect]

	var validator := ContentValidatorScript.new()
	assert_equal(
		validator.validate([valid_rule], [valid_card]),
		[],
		"well-formed content should pass"
	)

	var duplicate_rule = valid_rule.duplicate()
	var duplicate_errors = validator.validate([valid_rule, duplicate_rule], [valid_card])
	assert_true(
		duplicate_errors.any(func(error: String) -> bool: return "duplicate rule ID" in error),
		"duplicate rule IDs should be reported"
	)

	var empty_card := CardDefinitionScript.new()
	var empty_errors = validator.validate([valid_rule], [empty_card])
	assert_true(
		empty_errors.any(func(error: String) -> bool: return "card ID is empty" in error),
		"empty card IDs should be reported"
	)
	assert_true(
		empty_errors.any(
			func(error: String) -> bool: return "has no rank label" in error
		),
		"empty card rank labels should be reported"
	)

	var enhanced_swap := CardDefinitionScript.new()
	enhanced_swap.id = &"enhanced_swap"
	enhanced_swap.display_name = "换值联动"
	enhanced_swap.rule_text = "交换不同点数并强化最终所在规则台。"
	enhanced_swap.tags = PackedStringArray(["骰值"])
	enhanced_swap.target_type = CardDefinitionScript.TargetType.DICE_PAIR
	enhanced_swap.suit = CardDefinitionScript.Suit.CLUBS
	enhanced_swap.rank_label = "7"
	var enhanced_swap_effect := EffectSpecScript.new()
	enhanced_swap_effect.operation = EffectSpecScript.Operation.SWAP_DICE
	enhanced_swap_effect.amount = 1
	enhanced_swap.effects = [enhanced_swap_effect]
	assert_equal(
		validator.validate([], [enhanced_swap]),
		[],
		"swap amount may carry a non-negative final-table coefficient bonus"
	)
	enhanced_swap_effect.amount = -1
	assert_true(
		"card enhanced_swap swap coefficient bonus cannot be negative"
		in validator.validate([], [enhanced_swap]),
		"negative swap coefficient bonuses are rejected"
	)

	var restriction = FinalRestrictionDefinitionScript.new()
	restriction.id = &"invalid_limit"
	restriction.display_name = "无效上限"
	restriction.rule_text = "最多使用零张牌。"
	restriction.amount = 0
	assert_true(
		validator.validate_restriction(restriction).any(
			func(error: String) -> bool: return "positive card limit" in error
		),
		"restriction validation should delegate to the resource contract"
	)

	var dealer := DealerDefinitionScript.new()
	dealer.id = &"silent_dealer"
	dealer.display_name = "沉默庄家"
	dealer.rule_text = "公开规则"
	dealer.fixed_reward = 6
	dealer.penalty_per_unassigned_die = 1
	dealer.tags = PackedStringArray(["庄家"])
	assert_true(
		validator.validate_dealers([dealer]).any(
			func(error: String) -> bool: return "has no opening text" in error
		),
		"dealers without opening narrative should be rejected"
	)
