class_name CardDisplayFormatter
extends RefCounted

const Phase3SuitRules = preload("res://scripts/cards/card_suit_rules.gd")

const ICON_ROOT := "res://resources/ui/dream_glass/icons/"
const CARD_FACE_ROOT := "res://resources/ui/dream_glass/card_faces/prototypes/"

const CARD_FACE_FILES := {
	&"starter_nudge_down_1": "starter_nudge_down_1.svg",
	&"shop_precision_map": "shop_precision_map.svg",
	&"starter_link": "starter_link.svg",
	&"starter_reverse": "starter_reverse.svg",
	&"faceless_copy_value": "faceless_copy_value.svg",
	&"faceless_lock_bonus": "faceless_lock_bonus.svg",
	&"starter_nudge_up_1": "starter_nudge_up_1.svg",
	&"starter_nudge_down_2": "starter_nudge_down_2.svg",
	&"starter_nudge_up_2": "starter_nudge_up_2.svg",
	&"starter_map_1": "starter_map_1.svg",
	&"starter_map_2": "starter_map_2.svg",
	&"starter_repeat_1": "starter_repeat_1.svg",
	&"starter_repeat_2": "starter_repeat_2.svg",
	&"starter_stable_repeat": "starter_stable_repeat.svg",
	&"starter_amplified_repeat": "starter_amplified_repeat.svg",
	&"shop_triple_repeat": "shop_triple_repeat.svg",
	&"shop_long_push": "shop_long_push.svg",
	&"shop_deep_drop": "shop_deep_drop.svg",
	&"mirror_folded_map": "mirror_folded_map.svg",
	&"mirror_soft_echo": "mirror_soft_echo.svg",
	&"mirror_hinged_bridge": "mirror_hinged_bridge.svg",
	&"mirror_double_exposure": "mirror_double_exposure.svg",
	&"mirror_deep_echo": "mirror_deep_echo.svg",
	&"mirror_silver_bridge": "mirror_silver_bridge.svg",
	&"shop_amplified_chain": "shop_amplified_chain.svg",
	&"shop_reverse_backup": "shop_reverse_backup.svg",
	&"shop_dice_index": "shop_dice_index.svg",
	&"shop_chain_index": "shop_chain_index.svg",
	&"faceless_swap_values": "faceless_swap_values.svg",
	&"faceless_flip_value": "faceless_flip_value.svg",
	&"faceless_refund_calibration": "faceless_refund_calibration.svg",
	&"faceless_exact_tolerance": "faceless_exact_tolerance.svg",
	&"faceless_even_tolerance": "faceless_even_tolerance.svg",
	&"faceless_sequence_tolerance": "faceless_sequence_tolerance.svg",
	&"faceless_table_receipt": "faceless_table_receipt.svg",
	&"faceless_full_allocation": "faceless_full_allocation.svg",
	&"faceless_three_seats": "faceless_three_seats.svg",
	&"faceless_complete_dossier": "faceless_complete_dossier.svg",
	&"faceless_strict_mapping": "faceless_strict_mapping.svg",
	&"faceless_reverse_replay": "faceless_reverse_replay.svg",
	&"faceless_compressed_repeat": "faceless_compressed_repeat.svg",
	&"faceless_closed_circuit": "faceless_closed_circuit.svg",
	&"stage7_fault_die": "stage7_fault_die.svg",
	&"stage7_all_in": "stage7_all_in.svg",
	&"stage7_insurance_draft": "stage7_insurance_draft.svg",
	&"stage7_burned_rewrite": "stage7_burned_rewrite.svg",
}

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
	EffectSpec.Operation.QUEUE_SEARCH: "reverse_resolution.svg",
	EffectSpec.Operation.FAULT_DIE: "lock_die_with_bonus.svg",
	EffectSpec.Operation.ALL_IN: "grant_intel_on_condition.svg",
	EffectSpec.Operation.GRANT_UNDOS: "refund_calibration.svg",
	EffectSpec.Operation.BURNED_REWRITE: "repeat_table.svg",
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
	footer_parts.append(Phase3SuitRules.meaning_copy(card.suit))
	lines.append(" · ".join(footer_parts))
	return "\n".join(lines)

func detail_copy(card: CardDefinition, next_action: String = "") -> String:
	var lines: PackedStringArray = [
		"%s · %s" % [header_copy(card), card.rarity_copy()],
		"花色语义：%s" % Phase3SuitRules.meaning_copy(card.suit),
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

func compact_identity_copy(card: CardDefinition) -> String:
	return "%s%s" % [suit_mark_copy(card.suit), card.rank_label]

func suit_mark_copy(suit: CardDefinition.Suit) -> String:
	match suit:
		CardDefinition.Suit.CLUBS:
			return "♣"
		CardDefinition.Suit.HEARTS:
			return "♥"
		CardDefinition.Suit.DIAMONDS:
			return "♦"
		CardDefinition.Suit.SPADES:
			return "♠"
	return "?"

func effect_short_copy(card: CardDefinition) -> String:
	if card != null and card.id == &"starter_link":
		return "复制左台结算分"
	if card != null and card.effects.size() > 1:
		var parts: PackedStringArray = []
		for combined_effect in card.effects:
			match combined_effect.operation:
				EffectSpec.Operation.MODIFY_COEFFICIENT:
					parts.append("系数 %s" % _signed(combined_effect.amount))
				EffectSpec.Operation.REPEAT_TABLE:
					parts.append("结算 +%d 次" % combined_effect.amount)
				EffectSpec.Operation.LINK_NEIGHBORS:
					parts.append("连接")
				EffectSpec.Operation.REVERSE_RESOLUTION:
					parts.append("反转顺序")
				EffectSpec.Operation.MODIFY_CONDITION:
					parts.append(_condition_short_copy(combined_effect))
				_:
					parts.append(_effect_copy(combined_effect))
		return " · ".join(parts)
	var effect := _primary_effect(card)
	if effect == null:
		return card.rule_text
	match effect.operation:
		EffectSpec.Operation.ADJUST_DIE:
			return "骰值 %s" % _signed(effect.amount)
		EffectSpec.Operation.MODIFY_COEFFICIENT:
			return "系数 %s" % _signed(effect.amount)
		EffectSpec.Operation.REPEAT_TABLE:
			return "额外结算 %d 次" % effect.amount
		EffectSpec.Operation.REVERSE_RESOLUTION:
			return "反转顺序"
		EffectSpec.Operation.LINK_NEIGHBORS:
			return "连接相邻台"
		EffectSpec.Operation.SWAP_DICE:
			return (
				"换值 · 台系数 %s" % _signed(effect.amount)
				if effect.amount != 0
				else "交换两颗骰值"
			)
		EffectSpec.Operation.COPY_DIE:
			return "复制第一颗"
		EffectSpec.Operation.FLIP_DIE:
			return "骰值翻面"
		EffectSpec.Operation.LOCK_DIE_WITH_BONUS:
			return "锁定骰值"
		EffectSpec.Operation.REFUND_CALIBRATION:
			return "返还 %d 校准点" % effect.amount
		EffectSpec.Operation.MODIFY_CONDITION:
			return _condition_short_copy(effect)
		EffectSpec.Operation.GRANT_INTEL_ON_CONDITION:
			return "情报券 +%d" % effect.amount
		EffectSpec.Operation.QUEUE_SEARCH:
			return "下轮定向检索"
		EffectSpec.Operation.FAULT_DIE:
			return "固定为 1 · 所在台 +3"
		EffectSpec.Operation.ALL_IN:
			return "全过复制卡牌情报"
		EffectSpec.Operation.GRANT_UNDOS:
			return "两类撤销各 +%d" % effect.amount
		EffectSpec.Operation.BURNED_REWRITE:
			return "降 1 系数复写"
	return _effect_copy(effect)

func effect_detail_copy(card: CardDefinition) -> String:
	if card == null:
		return ""
	if card.id == &"starter_link":
		return "左台先通过 · 右台也通过"
	var parts: PackedStringArray = []
	for direct_effect in card.effects:
		var direct_detail := _effect_detail_for(direct_effect)
		if card.effects.size() > 1 and direct_detail == "传递已解析结果":
			direct_detail = "传递结果"
		if not direct_detail.is_empty() and direct_detail not in parts:
			parts.append(direct_detail)
	if not card.mirror_effects.is_empty():
		parts.erase("本轮生效")
		parts.erase("传递已解析结果")
		parts.erase("传递结果")
		var mirror_parts: PackedStringArray = []
		for mirror_effect in card.mirror_effects:
			mirror_parts.append(_effect_copy(mirror_effect))
		parts.append("镜像：%s" % " · ".join(mirror_parts))
	return " · ".join(parts)

func _effect_detail_for(effect: EffectSpec) -> String:
	if effect == null:
		return ""
	match effect.operation:
		EffectSpec.Operation.ADJUST_DIE:
			return "范围 1–6"
		EffectSpec.Operation.MODIFY_COEFFICIENT:
			return "最低 1" if effect.amount < 0 else ""
		EffectSpec.Operation.REPEAT_TABLE:
			return "本轮生效"
		EffectSpec.Operation.REVERSE_RESOLUTION:
			return "本轮生效"
		EffectSpec.Operation.LINK_NEIGHBORS:
			return "传递已解析结果"
		EffectSpec.Operation.SWAP_DICE:
			return (
				"异值目标 · 按最终摆位"
				if effect.amount != 0
				else "当前有效点数"
			)
		EffectSpec.Operation.COPY_DIE:
			return "当前有效点数"
		EffectSpec.Operation.FLIP_DIE:
			return "7 - 当前值"
		EffectSpec.Operation.LOCK_DIE_WITH_BONUS:
			return "每次结算 %s" % _signed(effect.amount)
		EffectSpec.Operation.REFUND_CALIBRATION:
			return "校准点上限 2"
		EffectSpec.Operation.MODIFY_CONDITION:
			return _condition_detail_copy(effect)
		EffectSpec.Operation.GRANT_INTEL_ON_CONDITION:
			return _intel_condition_trigger_copy(effect)
		EffectSpec.Operation.FAULT_DIE:
			return "整次远征持久生效"
		EffectSpec.Operation.ALL_IN:
			return "普通房与庄家基础奖励不翻倍"
		EffectSpec.Operation.GRANT_UNDOS:
			return "需弃置 1 张其他手牌"
		EffectSpec.Operation.BURNED_REWRITE:
			return "需弃置 2 张；不计桥接次数"
	return ""

func has_card_face_art(card: CardDefinition) -> bool:
	return card != null and CARD_FACE_FILES.has(card.id)

func card_art_path(card: CardDefinition) -> String:
	if has_card_face_art(card):
		return "%s%s" % [CARD_FACE_ROOT, CARD_FACE_FILES[card.id]]
	return effect_icon_path(card)

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
			return (
				"交换两颗不同骰值；最终所在的每张规则台系数 %s"
				% _signed(effect.amount)
				if effect.amount != 0
				else "交换两颗骰子的骰值"
			)
		EffectSpec.Operation.COPY_DIE:
			return "第二颗复制第一颗骰值"
		EffectSpec.Operation.FLIP_DIE:
			return "骰值变为 7 − 当前值"
		EffectSpec.Operation.LOCK_DIE_WITH_BONUS:
			return "锁定骰值；所在台每次成功结算 %s" % _signed(effect.amount)
		EffectSpec.Operation.REFUND_CALIBRATION:
			return "返还 %d 校准点（上限 2）" % effect.amount
		EffectSpec.Operation.MODIFY_CONDITION:
			return _condition_modifier_copy(effect)
		EffectSpec.Operation.GRANT_INTEL_ON_CONDITION:
			return _intel_condition_copy(effect)
		EffectSpec.Operation.QUEUE_SEARCH:
			return "下轮优先检索%s" % BuildIdentityCatalog.new().display_name(
				effect.search_identity
			)
		EffectSpec.Operation.FAULT_DIE:
			return "固定最终值为 1；所在台系数 +3"
		EffectSpec.Operation.ALL_IN:
			return "耗尽校准；三台全过时复制卡牌情报"
		EffectSpec.Operation.GRANT_UNDOS:
			return "弃置 1 张；校准与卡牌撤销各 +%d" % effect.amount
		EffectSpec.Operation.BURNED_REWRITE:
			return "弃置 2 张；按原系数 −1 复写一次"
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

func _condition_short_copy(effect: EffectSpec) -> String:
	match effect.condition_modifier:
		EffectSpec.ConditionModifier.EXACT_TOLERANCE:
			return "精确条件放宽"
		EffectSpec.ConditionModifier.ALLOW_ONE_ODD:
			return "全偶条件放宽"
		EffectSpec.ConditionModifier.ALLOW_ONE_GAP:
			return "连续条件放宽"
		EffectSpec.ConditionModifier.INCREASE_SLOT_COUNT:
			return "所需骰位 +%d" % effect.amount
	return "修改规则条件"

func _condition_detail_copy(effect: EffectSpec) -> String:
	match effect.condition_modifier:
		EffectSpec.ConditionModifier.EXACT_TOLERANCE:
			return "允许 ±%d" % effect.amount
		EffectSpec.ConditionModifier.ALLOW_ONE_ODD:
			return "允许 %d 颗奇数" % effect.amount
		EffectSpec.ConditionModifier.ALLOW_ONE_GAP:
			return "允许 %d 个差2缺口" % effect.amount
		EffectSpec.ConditionModifier.INCREASE_SLOT_COUNT:
			return "骰位上限 6"
	return "本轮生效"

func _intel_condition_copy(effect: EffectSpec) -> String:
	return "%s：情报 +%d" % [
		_intel_condition_trigger_copy(effect),
		effect.amount,
	]

func _intel_condition_trigger_copy(effect: EffectSpec) -> String:
	var condition_copy := "满足条件时"
	match effect.intel_condition:
		EffectSpec.IntelCondition.TARGET_TABLE_PASSED:
			condition_copy = "目标台通过时"
		EffectSpec.IntelCondition.ALL_DICE_ASSIGNED:
			condition_copy = "分配全部骰子时"
		EffectSpec.IntelCondition.ALL_TABLES_OCCUPIED:
			condition_copy = "三台均有骰时"
		EffectSpec.IntelCondition.ALL_TABLES_PASSED:
			condition_copy = "三台均通过时"
	return condition_copy

func _primary_effect(card: CardDefinition) -> EffectSpec:
	if card == null:
		return null
	if not card.effects.is_empty():
		return card.effects[0]
	if not card.mirror_effects.is_empty():
		return card.mirror_effects[0]
	return null

func _signed(value: int) -> String:
	return "+%d" % value if value >= 0 else str(value)
