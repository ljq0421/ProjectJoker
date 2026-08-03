class_name CardDisplayFormatter
extends RefCounted

const ICON_ROOT := "res://resources/ui/dream_glass/icons/"

const EFFECT_ICON_FILES := {
	EffectSpec.Operation.ADJUST_DIE: "adjust_die.svg",
	EffectSpec.Operation.MODIFY_COEFFICIENT: "modify_coefficient.svg",
	EffectSpec.Operation.REPEAT_TABLE: "repeat_table.svg",
	EffectSpec.Operation.REVERSE_RESOLUTION: "reverse_resolution.svg",
	EffectSpec.Operation.LINK_NEIGHBORS: "link_neighbors.svg",
	EffectSpec.Operation.SWAP_DICE: "swap_dice.svg",
	EffectSpec.Operation.COPY_DIE: "copy_die.svg",
	EffectSpec.Operation.FLIP_DIE: "flip_die.svg",
	EffectSpec.Operation.LOCK_DIE_WITH_BONUS: "lock_die_with_bonus.svg",
	EffectSpec.Operation.REFUND_CALIBRATION: "refund_calibration.svg",
	EffectSpec.Operation.MODIFY_CONDITION: "modify_condition.svg",
	EffectSpec.Operation.GRANT_INTEL_ON_CONDITION: (
		"grant_intel_on_condition.svg"
	),
}

const TARGET_ICON_FILES := {
	CardDefinition.TargetType.DIE: "die.svg",
	CardDefinition.TargetType.TABLE: "table.svg",
	CardDefinition.TargetType.GAP: "gap.svg",
	CardDefinition.TargetType.GLOBAL: "global.svg",
	CardDefinition.TargetType.DICE_PAIR: "dice_pair.svg",
}

func compact_copy(card: CardDefinition) -> String:
	var lines: PackedStringArray = [header_copy(card)]
	lines.append_array(effect_summary_lines(card))
	lines.append("目标：%s" % target_copy_for(card))
	return "\n".join(lines)

func shop_compact_copy(
	card: CardDefinition,
	identity_copy: String,
	price: int = -1
) -> String:
	var lines: PackedStringArray = [header_copy(card)]
	lines.append_array(effect_summary_lines(card))
	var footer_parts: PackedStringArray = [target_copy_for(card)]
	if not identity_copy.is_empty():
		footer_parts.append(identity_copy)
	if price >= 0:
		footer_parts.append("%d 情报券" % price)
	lines.append(" · ".join(footer_parts))
	return "\n".join(lines)

func detail_copy(card: CardDefinition, next_action: String = "") -> String:
	var lines: PackedStringArray = [
		"%s · %s" % [header_copy(card), card.rarity_copy()],
		"规则：%s" % card.rule_text,
		"目标：%s" % target_copy_for(card),
	]
	if not next_action.is_empty():
		lines.append("下一步：%s" % next_action)
	return "\n".join(lines)

func comparison_copy(label: String, card: CardDefinition) -> String:
	if card == null:
		return "%s｜未选择" % label
	return "%s｜%s · %s｜%s" % [
		label,
		card.display_name,
		target_copy_for(card),
		card.rule_text,
	]

func header_copy(card: CardDefinition) -> String:
	return "%s %s · %s" % [
		card.suit_copy(),
		card.rank_label,
		card.display_name,
	]

func effect_summary_lines(card: CardDefinition) -> PackedStringArray:
	var lines: PackedStringArray = []
	var direct_parts: PackedStringArray = []
	for effect in card.effects:
		direct_parts.append(_effect_copy(effect))
	if direct_parts.is_empty():
		direct_parts.append(card.rule_text)
	lines.append("；".join(direct_parts))
	if not card.mirror_effects.is_empty():
		var mirror_parts: PackedStringArray = []
		for effect in card.mirror_effects:
			mirror_parts.append(_effect_copy(effect))
		lines.append("镜像：%s" % "；".join(mirror_parts))
	return lines

func effect_icon_path(card: CardDefinition) -> String:
	var effect: EffectSpec = null
	if not card.effects.is_empty():
		effect = card.effects[0]
	elif not card.mirror_effects.is_empty():
		effect = card.mirror_effects[0]
	if effect == null or not EFFECT_ICON_FILES.has(effect.operation):
		return target_icon_path(card.target_type)
	return "%seffects/%s" % [ICON_ROOT, EFFECT_ICON_FILES[effect.operation]]

func target_icon_path(target_type: CardDefinition.TargetType) -> String:
	if not TARGET_ICON_FILES.has(target_type):
		return "%stargets/global.svg" % ICON_ROOT
	return "%stargets/%s" % [ICON_ROOT, TARGET_ICON_FILES[target_type]]

func target_copy_for(card: CardDefinition) -> String:
	var copy := target_copy(card.target_type)
	if (
		card.target_type == CardDefinition.TargetType.GAP
		and not card.mirror_effects.is_empty()
	):
		copy += " · 可镜像"
	return copy

func target_copy(target_type: CardDefinition.TargetType) -> String:
	match target_type:
		CardDefinition.TargetType.DIE:
			return "1 颗骰子"
		CardDefinition.TargetType.TABLE:
			return "1 张规则台"
		CardDefinition.TargetType.GAP:
			return "桌间槽"
		CardDefinition.TargetType.GLOBAL:
			return "全局"
		CardDefinition.TargetType.DICE_PAIR:
			return "2 颗骰子"
	return "未知目标"

func _effect_copy(effect: EffectSpec) -> String:
	match effect.operation:
		EffectSpec.Operation.ADJUST_DIE:
			return "骰值 %s（范围 1–6）" % _signed(effect.amount)
		EffectSpec.Operation.MODIFY_COEFFICIENT:
			var coefficient_copy := "系数 %s" % _signed(effect.amount)
			if effect.amount < 0:
				coefficient_copy += "（最低 1）"
			return coefficient_copy
		EffectSpec.Operation.REPEAT_TABLE:
			return "额外结算 %d 次" % effect.amount
		EffectSpec.Operation.REVERSE_RESOLUTION:
			return "反转本轮结算方向"
		EffectSpec.Operation.LINK_NEIGHBORS:
			return "连接相邻规则台"
		EffectSpec.Operation.SWAP_DICE:
			return "交换两颗骰子的骰值"
		EffectSpec.Operation.COPY_DIE:
			return "第二颗复制第一颗骰值"
		EffectSpec.Operation.FLIP_DIE:
			return "骰值变为 7 − 当前值"
		EffectSpec.Operation.LOCK_DIE_WITH_BONUS:
			return "锁定骰值；通过奖励 %s" % _signed(effect.amount)
		EffectSpec.Operation.REFUND_CALIBRATION:
			return "返还 %d 校准点（上限 2）" % effect.amount
		EffectSpec.Operation.MODIFY_CONDITION:
			return _condition_modifier_copy(effect)
		EffectSpec.Operation.GRANT_INTEL_ON_CONDITION:
			return _intel_condition_copy(effect)
	return "查看完整规则"

func _condition_modifier_copy(effect: EffectSpec) -> String:
	match effect.condition_modifier:
		EffectSpec.ConditionModifier.EXACT_TOLERANCE:
			return "精确条件允许 ±%d" % effect.amount
		EffectSpec.ConditionModifier.ALLOW_ONE_ODD:
			return "全偶条件允许 %d 颗奇数" % effect.amount
		EffectSpec.ConditionModifier.ALLOW_ONE_GAP:
			return "连续条件允许 %d 个差 2 缺口" % effect.amount
		EffectSpec.ConditionModifier.INCREASE_SLOT_COUNT:
			return "所需骰位 +%d（上限 6）" % effect.amount
	return "修改规则条件"

func _intel_condition_copy(effect: EffectSpec) -> String:
	var condition_copy := "满足条件"
	match effect.intel_condition:
		EffectSpec.IntelCondition.TARGET_TABLE_PASSED:
			condition_copy = "目标台通过"
		EffectSpec.IntelCondition.ALL_DICE_ASSIGNED:
			condition_copy = "分配全部骰子"
		EffectSpec.IntelCondition.ALL_TABLES_OCCUPIED:
			condition_copy = "三台均有骰"
		EffectSpec.IntelCondition.ALL_TABLES_PASSED:
			condition_copy = "三台均通过"
	return "%s：情报 +%d" % [condition_copy, effect.amount]

func _signed(value: int) -> String:
	return "+%d" % value if value >= 0 else str(value)
