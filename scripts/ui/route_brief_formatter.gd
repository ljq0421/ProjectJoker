class_name RouteBriefFormatter
extends RefCounted

const BuildIdentities = preload("res://scripts/run/build_identity_catalog.gd")

static func rule_text(rule: RuleDefinition) -> String:
	if rule == null:
		return "规则资料不可用"
	return "%s\n%d 个骰位 · 系数 ×%d · %s" % [
		rule.display_name,
		rule.slot_count,
		rule.coefficient,
		_condition_hint(rule),
	]

static func matching_card_names(
	room: RoomDefinition,
	deck_ids: Array[StringName],
	card_catalog: CardCatalog
) -> Array[String]:
	var names: Array[String] = []
	if room == null or card_catalog == null:
		return names
	for card_id in deck_ids:
		var card := card_catalog.find_card(card_id)
		if card == null:
			continue
		for tag in card.tags:
			if tag in room.synergy_tags:
				names.append(card.display_name)
				break
	names.sort()
	return names

static func synergy_text(names: Array[String]) -> String:
	if names.is_empty():
		return "当前牌组无直接标签匹配"
	var visible_names := names.slice(0, 4)
	var copy := "、".join(visible_names)
	if names.size() > 4:
		copy += " 等 %d 张" % names.size()
	return copy

static func goal_text(room: RoomDefinition) -> String:
	return "%d 轮累计目标：%d" % [room.round_count, room.target_total]

static func pressure_label(
	room: RoomDefinition,
	all_rooms: Array[RoomDefinition]
) -> String:
	if room == null or all_rooms.is_empty():
		return "进阶"
	var values: Array[float] = []
	for candidate in all_rooms:
		if candidate != null:
			values.append(
				float(candidate.target_total) / float(maxi(candidate.round_count, 1))
			)
	if values.is_empty():
		return "进阶"
	var low: float = values.min()
	var high: float = values.max()
	if is_equal_approx(low, high):
		return "进阶"
	var per_round := float(room.target_total) / float(maxi(room.round_count, 1))
	var relative := (per_round - low) / (high - low)
	if relative <= 0.34:
		return "稳健"
	if relative >= 0.67:
		return "高压"
	return "进阶"

static func activity_text(
	room: RoomDefinition,
	card_catalog: CardCatalog
) -> String:
	match room.activity_kind:
		RoomDefinition.ActivityKind.SINGLE_ROUND_CONTRACT:
			return "活动｜单轮高压契约 · 一次结算决定成败"
		RoomDefinition.ActivityKind.FIXED_HAND_PUZZLE:
			var names: Array[String] = []
			for card_id in room.fixed_hand_ids:
				var card := card_catalog.find_card(card_id)
				names.append(card.display_name if card != null else String(card_id))
			return "活动｜公开固定手牌 · %s" % " / ".join(names)
		RoomDefinition.ActivityKind.RULE_MUTATION:
			var summaries: Array[String] = []
			for plan in room.round_plans:
				summaries.append("%s：%s" % [plan.display_name, plan.public_summary])
			return "活动｜逐轮规则突变 · %s" % "；".join(summaries)
	return "活动｜标准三轮试局"

static func identity_text(
	room: RoomDefinition,
	deck_ids: Array[StringName],
	card_catalog: CardCatalog
) -> String:
	var identities := BuildIdentities.new()
	return "构筑｜%s" % identities.route_identity_copy(
		room.build_identity_id,
		identities.deck_counts(deck_ids, card_catalog)
	)

static func _condition_hint(rule: RuleDefinition) -> String:
	if rule.template == null:
		match rule.condition_type:
			RuleDefinition.ConditionType.EXACT_SUM:
				return "总和精确为 %d" % rule.target_value
			RuleDefinition.ConditionType.ALL_EVEN:
				return "全部为偶数"
			RuleDefinition.ConditionType.CONSECUTIVE:
				return "组成连续数列"
		return "公开条件"

	match rule.template.condition_kind:
		RuleTableTemplate.ConditionKind.ANY_FILLED:
			return rule.template.description
		RuleTableTemplate.ConditionKind.EXACT_SUM:
			return "总和精确为 %d" % rule.target_value
		RuleTableTemplate.ConditionKind.MINIMUM_SUM:
			return "总和至少为 %d" % rule.target_value
		RuleTableTemplate.ConditionKind.MAXIMUM_SUM:
			return "总和至多为 %d" % rule.target_value
		RuleTableTemplate.ConditionKind.SUM_RANGE:
			return "总和为 %d–%d" % [
				rule.minimum_value,
				rule.maximum_value,
			]
		RuleTableTemplate.ConditionKind.ALL_EQUAL:
			return rule.template.display_name
		RuleTableTemplate.ConditionKind.ALL_DISTINCT:
			return rule.template.display_name
		RuleTableTemplate.ConditionKind.ALL_EVEN:
			return rule.template.display_name
		RuleTableTemplate.ConditionKind.ALL_ODD:
			return rule.template.display_name
		RuleTableTemplate.ConditionKind.SAME_PARITY:
			return rule.template.display_name
		RuleTableTemplate.ConditionKind.CONSECUTIVE:
			return rule.template.display_name
		RuleTableTemplate.ConditionKind.FIXED_DIFFERENCE:
			return "相邻差值固定为 %d" % rule.difference
		RuleTableTemplate.ConditionKind.STRICT_ASCENDING:
			return rule.template.display_name
		RuleTableTemplate.ConditionKind.STRICT_DESCENDING:
			return rule.template.display_name
		RuleTableTemplate.ConditionKind.MIRRORED:
			return rule.template.display_name
		RuleTableTemplate.ConditionKind.SLOT_TARGETS:
			var targets: Array[String] = []
			for target in rule.slot_targets:
				targets.append(str(target))
			return "各槽目标：%s" % " / ".join(targets)
	return rule.template.display_name
