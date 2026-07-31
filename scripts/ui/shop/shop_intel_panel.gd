class_name ShopIntelPanel
extends Control

signal closed

func _ready() -> void:
	%CloseIntelButton.pressed.connect(close)
	close()

func bind_snapshot(
	snapshot: ShopIntelSnapshot,
	area_definition: AreaDefinition,
	deck_ids: Array[StringName],
	card_catalog: CardCatalog,
	dealer_catalog: DealerCatalog,
	challenge_ids: Array[StringName] = []
) -> bool:
	if snapshot == null:
		return _fail_closed("情报快照不可用")
	var validation_error := snapshot.validate(area_definition, dealer_catalog)
	if not validation_error.is_empty():
		return _fail_closed(validation_error)
	if card_catalog == null:
		return _fail_closed("手法牌目录不可用")
	for card_id in deck_ids:
		if card_catalog.find_card(card_id) == null:
			return _fail_closed("当前牌组包含未知手法牌：%s" % card_id)

	%IntelErrorLabel.text = ""
	if snapshot.kind == ShopIntelSnapshot.Kind.ROUTE_PAIR:
		if not _bind_routes(
			snapshot.route_ids,
			area_definition,
			deck_ids,
			card_catalog,
			challenge_ids
		):
			return false
	else:
		if not _bind_dealer(
			snapshot,
			area_definition,
			dealer_catalog,
			challenge_ids
		):
			return false
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	return true

func close() -> void:
	var was_visible := visible
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if was_visible:
		closed.emit()

func _bind_routes(
	route_ids: Array[StringName],
	area_definition: AreaDefinition,
	deck_ids: Array[StringName],
	card_catalog: CardCatalog,
	challenge_ids: Array[StringName]
) -> bool:
	var left := area_definition.find_room(route_ids[0])
	var right := area_definition.find_room(route_ids[1])
	if left == null or right == null:
		return _fail_closed("路线情报包含未知房间")
	if left.encounter == null or left.encounter.rules.size() != 3:
		return _fail_closed("左侧路线必须包含三张规则台")
	if right.encounter == null or right.encounter.rules.size() != 3:
		return _fail_closed("右侧路线必须包含三张规则台")
	%IntelTitle.text = "%s · 下一组路线情报" % area_definition.display_name
	%IntelSubtitle.text = "路线与顺序已经固定；查看情报不会改变后续结果。"
	_bind_route_page("Left", left, deck_ids, card_catalog, challenge_ids)
	_bind_route_page("Right", right, deck_ids, card_catalog, challenge_ids)
	%RouteMode.visible = true
	%RouteIntelPages.visible = true
	%DealerMode.visible = false
	%DealerIntelScroll.visible = false
	return true

func _bind_route_page(
	prefix: String,
	room: RoomDefinition,
	deck_ids: Array[StringName],
	card_catalog: CardCatalog,
	challenge_ids: Array[StringName]
) -> void:
	get_node("%sIntelName" % ["%" + prefix]).text = room.display_name
	get_node("%sIntelBody" % ["%" + prefix]).text = "%s\n%s" % [
		room.description,
		RouteBriefFormatter.activity_text(room, card_catalog),
	]
	var challenge_rules = preload(
		"res://scripts/run/expedition_challenge_rules.gd"
	).new(challenge_ids)
	get_node("%sIntelGoal" % ["%" + prefix]).text = "累计目标：%d（%d 回合）" % [
		challenge_rules.target_total(room.target_total),
		room.round_count,
	]
	get_node("%sIntelReward" % ["%" + prefix]).text = (
		"成功奖励：%d 张情报券" % challenge_rules.intel_reward(
			room.success_intel_reward
		)
	)
	get_node("%sIntelTags" % ["%" + prefix]).text = (
		"%s　房间特征｜%s" % [
			RouteBriefFormatter.identity_text(room, deck_ids, card_catalog),
			" · ".join(room.tags),
		]
	)
	get_node("%sIntelSynergy" % ["%" + prefix]).text = (
		"牌组呼应｜%s" % RouteBriefFormatter.synergy_text(
			RouteBriefFormatter.matching_card_names(
				room,
				deck_ids,
				card_catalog
			)
		)
	)
	var rule_names := ["RuleOne", "RuleTwo", "RuleThree"]
	for index in range(3):
		get_node(
			"%sIntel%s" % ["%" + prefix, rule_names[index]]
		).text = RouteBriefFormatter.rule_text(room.encounter.rules[index])

func _bind_dealer(
	snapshot: ShopIntelSnapshot,
	area_definition: AreaDefinition,
	dealer_catalog: DealerCatalog,
	challenge_ids: Array[StringName]
) -> bool:
	var dealer := dealer_catalog.find_dealer(snapshot.dealer_id)
	if dealer == null:
		return _fail_closed("庄家情报包含未知庄家")
	if (
		area_definition.dealer_round_schedule != null
		and area_definition.dealer_round_schedule.round_plans.size() != 3
	):
		return _fail_closed("庄家日程必须包含三轮")
	if (
		area_definition.dealer_round_schedule == null
		and (
			area_definition.dealer_encounter == null
			or area_definition.dealer_encounter.rules.size() != 3
		)
	):
		return _fail_closed("庄家固定规则必须包含三张规则台")
	%IntelTitle.text = "%s · 庄家完整情报" % area_definition.display_name
	%IntelSubtitle.text = "仅公开规则、三轮日程与限制；不预告未来骰面、手牌或结算结果。"
	%DealerIntelName.text = dealer.display_name
	%DealerIntelTarget.text = "三轮累计目标：%d" % preload(
		"res://scripts/run/expedition_challenge_rules.gd"
	).new(challenge_ids).target_total(snapshot.dealer_target)
	%DealerIntelMechanism.text = "庄家机制\n%s" % dealer.rule_text
	%DealerIntelSchedule.text = "三轮公开日程"
	_bind_dealer_rounds(area_definition)
	%DealerIntelRestrictions.text = _dealer_restriction_text(area_definition)
	%RouteMode.visible = false
	%RouteIntelPages.visible = false
	%DealerMode.visible = true
	%DealerIntelScroll.visible = true
	return true

func _bind_dealer_rounds(area_definition: AreaDefinition) -> void:
	var titles: Array[String] = []
	var directions: Array[String] = []
	var rules: Array[String] = []
	if area_definition.dealer_round_schedule != null:
		for index in range(3):
			var plan := area_definition.dealer_round_schedule.round_plans[index]
			titles.append("第 %d 轮 · %s" % [index + 1, plan.display_name])
			directions.append(plan.public_summary)
			var rule_lines: Array[String] = []
			for rule in plan.encounter.rules:
				rule_lines.append(RouteBriefFormatter.rule_text(rule))
			rules.append("\n".join(rule_lines))
	else:
		var direction := _direction_text(area_definition.dealer_encounter)
		var rule_lines: Array[String] = []
		for rule in area_definition.dealer_encounter.rules:
			rule_lines.append(RouteBriefFormatter.rule_text(rule))
		for index in range(3):
			titles.append("第 %d 轮 · 固定规则" % (index + 1))
			directions.append(direction)
			rules.append("\n".join(rule_lines))
	var words := ["One", "Two", "Three"]
	for index in range(3):
		get_node(
			"%" + ("DealerRound%sTitle" % words[index])
		).text = titles[index]
		get_node(
			"%" + ("DealerRound%sDirection" % words[index])
		).text = (
			directions[index]
		)
		get_node(
			"%" + ("DealerRound%sRules" % words[index])
		).text = rules[index]

func _direction_text(encounter: EncounterDefinition) -> String:
	var profile := encounter.rule_profile
	var direction := (
		"从右向左结算"
		if (
			profile != null
			and profile.resolution_direction
			== EncounterRuleProfile.ResolutionDirection.RIGHT_TO_LEFT
		)
		else "从左向右结算"
	)
	if profile != null and profile.mirror_first_table_card:
		direction += "；第一张合格桌间牌生成弱化镜像副本"
	return direction

func _dealer_restriction_text(area_definition: AreaDefinition) -> String:
	var schedule := area_definition.dealer_round_schedule
	if schedule == null:
		return "最终限制\n无额外最终限制。"
	var lines: Array[String] = ["第二轮后公开选择一种最终限制"]
	for restriction in schedule.restriction_options():
		lines.append("\n%s\n%s" % [
			restriction.display_name,
			restriction.rule_text,
		])
	return "\n".join(lines)

func _fail_closed(message: String) -> bool:
	%IntelErrorLabel.text = message
	close()
	return false
