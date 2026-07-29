extends "res://tests/test_case.gd"

func run() -> void:
	var template := RuleTableTemplate.new()
	assert_true(
		template.validate().size() >= 2,
		"an empty template should report missing identity and copy"
	)

	template.id = &"test_template"
	template.display_name = "测试规则"
	template.description = "用于验证模板约束。"
	template.category = RuleTableTemplate.Category.POINT
	template.condition_kind = RuleTableTemplate.ConditionKind.EXACT_SUM
	template.minimum_slot_count = 2
	template.maximum_slot_count = 2
	template.compatible_condition_modifiers = [
		EffectSpec.ConditionModifier.EXACT_TOLERANCE,
		EffectSpec.ConditionModifier.INCREASE_SLOT_COUNT,
	]
	assert_equal(template.validate(), [], "a complete point template should validate")
	assert_true(
		template.supports_condition_modifier(
			EffectSpec.ConditionModifier.EXACT_TOLERANCE
		),
		"declared condition modifiers should be supported"
	)
	assert_false(
		template.supports_condition_modifier(
			EffectSpec.ConditionModifier.ALLOW_ONE_ODD
		),
		"undeclared condition modifiers should be rejected"
	)

	template.minimum_slot_count = 4
	template.maximum_slot_count = 2
	assert_true(
		not template.validate().is_empty(),
		"minimum slots above maximum slots should fail"
	)

	template.minimum_slot_count = 1
	template.maximum_slot_count = 2
	template.category = RuleTableTemplate.Category.DISTORTION
	template.condition_kind = RuleTableTemplate.ConditionKind.ANY_FILLED
	template.post_pass_effect = RuleTableTemplate.PostPassEffect.NONE
	assert_true(
		not template.validate().is_empty(),
		"a distortion template should require a post-pass effect"
	)

	template.post_pass_effect = RuleTableTemplate.PostPassEffect.ECHO_SELF
	assert_equal(
		template.validate(),
		[],
		"a filled distortion template with an effect should validate"
	)
