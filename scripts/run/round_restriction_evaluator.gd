class_name RoundRestrictionEvaluator
extends RefCounted

const Modifiers = preload("res://scripts/run/area_run_modifier_catalog.gd")

func validate_card_play(
	state: RoundState,
	restriction: FinalRestrictionDefinition,
	context: ResolutionContext = null
) -> OperationResult:
	if restriction == null:
		return OperationResult.new(true)
	if (
		restriction.operation
		!= FinalRestrictionDefinition.Operation.MAX_REAL_CARDS
	):
		return OperationResult.new(true)

	var real_card_count := 0
	for played_card in state.played_cards:
		if played_card is PlayedCard and not played_card.is_mirror_copy:
			real_card_count += 1
	var effective_limit := restriction.amount
	if (
		context != null
		and context.has_area_modifier(Modifiers.FACELESS_OPEN_HAND)
	):
		effective_limit += 1
	if real_card_count >= effective_limit:
		return OperationResult.new(
			false,
			"%s：本轮最多使用 %d 张真实手法牌" % [
				restriction.display_name,
				effective_limit,
			]
		)
	return OperationResult.new(true)

func evaluate_commit(
	state: RoundState,
	encounter: EncounterDefinition,
	restriction: FinalRestrictionDefinition,
	context: ResolutionContext = null
) -> OperationResult:
	if restriction == null:
		return OperationResult.new(true)
	match restriction.operation:
		FinalRestrictionDefinition.Operation.MAX_REAL_CARDS:
			var real_card_count := 0
			for played_card in state.played_cards:
				if played_card is PlayedCard and not played_card.is_mirror_copy:
					real_card_count += 1
			var effective_limit := restriction.amount
			if (
				context != null
				and context.has_area_modifier(Modifiers.FACELESS_OPEN_HAND)
			):
				effective_limit += 1
			if real_card_count > effective_limit:
				return OperationResult.new(
					false,
					"%s：本轮最多使用 %d 张真实手法牌" % [
						restriction.display_name,
						effective_limit,
					]
				)
		FinalRestrictionDefinition.Operation.REQUIRE_ALL_TABLES_OCCUPIED:
			var missing_tables: Array[String] = []
			for rule_index in encounter.rules.size():
				var rule := encounter.rules[rule_index]
				if not state.has_occupied_slot(rule.id):
					missing_tables.append(_table_copy(rule.id, rule_index))
			var allowed_missing := (
				1
				if (
					context != null
					and context.has_area_modifier(Modifiers.FACELESS_RULE_VEIL)
				)
				else 0
			)
			if missing_tables.size() > allowed_missing:
				return OperationResult.new(
					false,
					"%s：%s尚未分配骰子" % [
						restriction.display_name,
						"、".join(missing_tables),
					]
				)
	return OperationResult.new(true)

func coverage_copy(
	state: RoundState,
	encounter: EncounterDefinition
) -> String:
	var occupied_count := 0
	for rule in encounter.rules:
		if state.has_occupied_slot(rule.id):
			occupied_count += 1
	return "已覆盖 %d/%d 张规则台" % [
		occupied_count,
		encounter.rules.size(),
	]

func _table_copy(table_id: StringName, rule_index: int) -> String:
	match table_id:
		&"left":
			return "左侧规则台"
		&"middle":
			return "中间规则台"
		&"right":
			return "右侧规则台"
	match rule_index:
		0:
			return "左侧规则台"
		1:
			return "中间规则台"
		2:
			return "右侧规则台"
	return "规则台“%s”" % table_id
