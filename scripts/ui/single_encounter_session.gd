class_name SingleEncounterSession
extends RefCounted

var controller: RoundController
var hand: Array[CardDefinition]
var selection := InteractionState.new()
var last_error: String = ""
var undo_allowed := true

func _init(
	state: RoundState,
	encounter: EncounterDefinition,
	p_hand: Array[CardDefinition],
	p_context: ResolutionContext = null,
	p_restriction: FinalRestrictionDefinition = null,
	p_additional_restrictions: Array[FinalRestrictionDefinition] = [],
	p_undo_allowed: bool = true
) -> void:
	controller = RoundController.new(
		state,
		encounter,
		p_context,
		p_restriction,
		p_additional_restrictions
	)
	hand = p_hand
	undo_allowed = p_undo_allowed

func activate_die(die_id: StringName) -> bool:
	if selection.kind == InteractionState.Kind.CARD:
		var card := hand[selection.card_index]
		if card.target_type == CardDefinition.TargetType.DICE_PAIR:
			if selection.card_primary_target == &"":
				if controller.state.find_die(die_id) == null:
					return _fail("双骰手法牌指向了未知骰子")
				var source_reason := _dice_pair_source_reason(
					selection.card_index,
					die_id
				)
				if not source_reason.is_empty():
					return _fail(source_reason)
				selection.select_card_primary(die_id)
				last_error = ""
				return true
			return _accept(
				controller.play_card(PlayedCard.new(
					card,
					selection.card_primary_target,
					die_id
				)),
				true
			)
		if card.target_type != CardDefinition.TargetType.DIE:
			return _fail("当前手法牌需要其他类型的目标")
		return _accept(
			controller.play_card(PlayedCard.new(card, die_id)),
			true
		)
	selection.select_die(die_id)
	last_error = ""
	return true

func activate_card(card_index: int) -> bool:
	if card_index < 0 or card_index >= hand.size():
		return _fail("手法牌不在当前手牌中")
	if is_card_used(card_index):
		return _fail("这张手法牌已经使用")
	var card := hand[card_index]
	var start_result := controller.validate_card_start()
	if not start_result.accepted:
		return _fail(start_result.reason)
	if card.target_type == CardDefinition.TargetType.GLOBAL:
		return _accept(controller.play_card(PlayedCard.new(card)), true)
	selection.select_card(card_index)
	last_error = ""
	return true

func cancel_selection() -> bool:
	if selection.kind == InteractionState.Kind.NONE:
		return false
	selection.clear()
	last_error = ""
	return true

func card_start_block_reason() -> String:
	var result := controller.validate_card_start()
	return "" if result.accepted else result.reason

func selected_card_target_hint() -> String:
	if selection.kind != InteractionState.Kind.CARD:
		return ""
	var card := hand[selection.card_index]
	match card.target_type:
		CardDefinition.TargetType.DICE_PAIR:
			return (
				"选择来源骰子"
				if selection.card_primary_target == &""
				else "已选来源 %s；请选择另一颗目标骰子" % (
					selection.card_primary_target
				)
			)
		CardDefinition.TargetType.DIE:
			return "请选择一颗合法骰子"
		CardDefinition.TargetType.TABLE:
			return "请选择一张合法规则台"
		CardDefinition.TargetType.GAP:
			return "请选择一个合法桌间槽"
	return ""

func is_legal_die_card_target(die_id: StringName) -> bool:
	if selection.kind != InteractionState.Kind.CARD:
		return false
	var card := hand[selection.card_index]
	if card.target_type == CardDefinition.TargetType.DIE:
		return card_target_block_reason(
			selection.card_index,
			die_id
		).is_empty()
	if card.target_type != CardDefinition.TargetType.DICE_PAIR:
		return false
	if selection.card_primary_target == &"":
		return _dice_pair_source_reason(
			selection.card_index,
			die_id
		).is_empty()
	return card_target_block_reason(
		selection.card_index,
		selection.card_primary_target,
		die_id
	).is_empty()

func is_legal_table_card_target(table_id: StringName) -> bool:
	if (
		selection.kind != InteractionState.Kind.CARD
		or hand[selection.card_index].target_type
		!= CardDefinition.TargetType.TABLE
	):
		return false
	return card_target_block_reason(
		selection.card_index,
		table_id
	).is_empty()

func is_legal_gap_card_target(
	left_id: StringName,
	right_id: StringName
) -> bool:
	if (
		selection.kind != InteractionState.Kind.CARD
		or hand[selection.card_index].target_type
		!= CardDefinition.TargetType.GAP
	):
		return false
	return card_target_block_reason(
		selection.card_index,
		left_id,
		right_id
	).is_empty()

func card_target_block_reason(
	card_index: int,
	primary_target: StringName,
	secondary_target: StringName = &""
) -> String:
	if card_index < 0 or card_index >= hand.size():
		return "手法牌不在当前手牌中"
	if is_card_used(card_index):
		return "这张手法牌已经使用"
	var result := controller.validate_card_play(PlayedCard.new(
		hand[card_index],
		primary_target,
		secondary_target
	))
	return "" if result.accepted else result.reason

func _dice_pair_source_reason(card_index: int, die_id: StringName) -> String:
	if controller.state.find_die(die_id) == null:
		return "双骰手法牌指向了未知骰子"
	var fallback_reason := "这颗骰子没有可用的第二目标"
	for candidate in controller.state.dice:
		if candidate.id == die_id:
			continue
		var reason := card_target_block_reason(
			card_index,
			die_id,
			candidate.id
		)
		if reason.is_empty():
			return ""
		fallback_reason = reason
	return fallback_reason

func activate_table(table_id: StringName) -> bool:
	if selection.kind == InteractionState.Kind.DIE:
		var rule := _find_rule(table_id)
		if rule == null:
			return _fail("规则轨不存在")
		return _accept(
			controller.assign_die(
				selection.die_id,
				table_id,
				controller.effective_slot_count(table_id)
			),
			true
		)
	if selection.kind == InteractionState.Kind.CARD:
		var card := hand[selection.card_index]
		if card.target_type != CardDefinition.TargetType.TABLE:
			return _fail("当前手法牌不能作用于规则轨")
		return _accept(controller.play_card(PlayedCard.new(card, table_id)), true)
	return _fail("请先选择骰子或手法牌")

func activate_slot(table_id: StringName, slot_index: int) -> bool:
	if selection.kind == InteractionState.Kind.CARD:
		return activate_table(table_id)
	if selection.kind != InteractionState.Kind.DIE:
		return _fail("请先选择一颗骰子")
	var rule := _find_rule(table_id)
	if rule == null:
		return _fail("规则轨不存在")
	return _accept(
		controller.assign_die_to_slot(
			selection.die_id,
			table_id,
			slot_index,
			controller.effective_slot_count(table_id)
		),
		true
	)

func activate_gap(left_id: StringName, right_id: StringName) -> bool:
	if selection.kind != InteractionState.Kind.CARD:
		return _fail("请先选择桌间手法牌")
	var card := hand[selection.card_index]
	if card.target_type != CardDefinition.TargetType.GAP:
		return _fail("当前手法牌不能作用于桌间槽")
	return _accept(
		controller.play_card(PlayedCard.new(card, left_id, right_id)),
		true
	)

func assign_dropped_die(die_id: StringName, table_id: StringName) -> bool:
	var rule := _find_rule(table_id)
	if rule == null:
		return _fail("规则轨不存在")
	return _accept(
		controller.assign_die(
			die_id,
			table_id,
			controller.effective_slot_count(table_id)
		),
		false
	)

func assign_dropped_die_to_slot(
	die_id: StringName,
	table_id: StringName,
	slot_index: int
) -> bool:
	var rule := _find_rule(table_id)
	if rule == null:
		return _fail("规则轨不存在")
	return _accept(
		controller.assign_die_to_slot(
			die_id,
			table_id,
			slot_index,
			controller.effective_slot_count(table_id)
		),
		false
	)

func return_die_to_tray(die_id: StringName) -> bool:
	return _accept(controller.unassign_die(die_id), false)

func calibrate_die(die_id: StringName, delta: int) -> bool:
	return _accept(controller.adjust_die(die_id, delta), false)

func undo() -> bool:
	if not undo_allowed:
		return _fail("落子无悔：本次远征禁止撤销")
	var accepted := controller.undo()
	if not accepted:
		return _fail("当前没有可撤销的操作")
	selection.clear()
	last_error = ""
	return true

func preview() -> ResolutionReport:
	return controller.preview()

func commit() -> ResolutionReport:
	return controller.commit()

func is_card_used(card_index: int) -> bool:
	var id := hand[card_index].id
	return controller.state.played_cards.any(
		func(played_card) -> bool:
			return (
				not played_card.is_mirror_copy
				and played_card.definition.id == id
			)
	)

func _find_rule(table_id: StringName) -> RuleDefinition:
	for rule in controller.encounter.rules:
		if rule.id == table_id:
			return rule
	return null

func _accept(result: ActionResult, clear_selection: bool) -> bool:
	if not result.accepted:
		return _fail(result.reason)
	if clear_selection:
		selection.clear()
	last_error = ""
	return true

func _fail(reason: String) -> bool:
	last_error = reason
	return false
