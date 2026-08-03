class_name RuleCopyFormatter
extends RefCounted

static func formula(rule: RuleDefinition) -> String:
	if rule.template == null:
		match rule.condition_type:
			RuleDefinition.ConditionType.EXACT_SUM:
				return "Σ = %d" % rule.target_value
			RuleDefinition.ConditionType.ALL_EVEN:
				return "全部偶数"
			RuleDefinition.ConditionType.CONSECUTIVE:
				return "连续数列"
		return rule.display_name
	match rule.template.condition_kind:
		RuleTableTemplate.ConditionKind.ANY_FILLED:
			return distortion_formula(rule.template.post_pass_effect)
		RuleTableTemplate.ConditionKind.EXACT_SUM:
			return "Σ = %d" % rule.target_value
		RuleTableTemplate.ConditionKind.MINIMUM_SUM:
			return "Σ ≥ %d" % rule.target_value
		RuleTableTemplate.ConditionKind.MAXIMUM_SUM:
			return "Σ ≤ %d" % rule.target_value
		RuleTableTemplate.ConditionKind.SUM_RANGE:
			return "%d ≤ Σ ≤ %d" % [rule.minimum_value, rule.maximum_value]
		RuleTableTemplate.ConditionKind.ALL_EQUAL:
			return "全部同点"
		RuleTableTemplate.ConditionKind.ALL_DISTINCT:
			return "互不相同"
		RuleTableTemplate.ConditionKind.ALL_EVEN:
			return "全部偶数"
		RuleTableTemplate.ConditionKind.ALL_ODD:
			return "全部奇数"
		RuleTableTemplate.ConditionKind.SAME_PARITY:
			return "同一奇偶"
		RuleTableTemplate.ConditionKind.CONSECUTIVE:
			return "连续数列"
		RuleTableTemplate.ConditionKind.FIXED_DIFFERENCE:
			return "相邻差 = %d" % rule.difference
		RuleTableTemplate.ConditionKind.STRICT_ASCENDING:
			return "严格递增 ↗"
		RuleTableTemplate.ConditionKind.STRICT_DESCENDING:
			return "严格递减 ↘"
		RuleTableTemplate.ConditionKind.MIRRORED:
			return "首尾镜像"
		RuleTableTemplate.ConditionKind.SLOT_TARGETS:
			return "指定槽位 %s" % str(Array(rule.slot_targets))
	return rule.display_name

static func distortion_formula(effect: RuleTableTemplate.PostPassEffect) -> String:
	match effect:
		RuleTableTemplate.PostPassEffect.ECHO_SELF:
			return "通过 → 重复结算"
		RuleTableTemplate.PostPassEffect.REVERSE_DIRECTION:
			return "通过 → 反转方向"
		RuleTableTemplate.PostPassEffect.BRIDGE_FORWARD:
			return "通过 → 传递相邻台"
	return "填入即通过"

static func category_label(template: RuleTableTemplate) -> String:
	if template == null:
		return "基础规则"
	match template.category:
		RuleTableTemplate.Category.POINT:
			return "点数阈值"
		RuleTableTemplate.Category.RELATION:
			return "集合与序列"
		RuleTableTemplate.Category.POSITION:
			return "槽位秩序"
		RuleTableTemplate.Category.DISTORTION:
			return "空间扭曲"
	return "公开规则"

static func timing_copy(template: RuleTableTemplate) -> String:
	if template == null or template.post_pass_effect == RuleTableTemplate.PostPassEffect.NONE:
		return "满足条件后，按本轮最终方向产生一次基础计分事件。"
	match template.post_pass_effect:
		RuleTableTemplate.PostPassEffect.ECHO_SELF:
			return "本台基础得分结算后，立即公开复制一次本台基础得分。"
		RuleTableTemplate.PostPassEffect.REVERSE_DIRECTION:
			return "全部规则台预判完成后、计分事件开始前，翻转一次最终结算方向。"
		RuleTableTemplate.PostPassEffect.BRIDGE_FORWARD:
			return "全部基础台结算后，沿最终方向向下一张已通过的相邻台传递一次基础得分。"
	return "满足条件后触发公开效果。"
