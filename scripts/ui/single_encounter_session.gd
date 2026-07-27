class_name SingleEncounterSession
extends RefCounted

var controller: RoundController
var hand: Array[CardDefinition]
var selection := InteractionState.new()
var last_error: String = ""

func _init(
	state: RoundState,
	encounter: EncounterDefinition,
	p_hand: Array[CardDefinition],
	p_context: ResolutionContext = null
) -> void:
	controller = RoundController.new(state, encounter, p_context)
	hand = p_hand

func activate_die(die_id: StringName) -> bool:
	if selection.kind == InteractionState.Kind.CARD:
		var card := hand[selection.card_index]
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
	if card.target_type == CardDefinition.TargetType.GLOBAL:
		return _accept(controller.play_card(PlayedCard.new(card)), true)
	selection.select_card(card_index)
	last_error = ""
	return true

func activate_table(table_id: StringName) -> bool:
	if selection.kind == InteractionState.Kind.DIE:
		var rule := _find_rule(table_id)
		if rule == null:
			return _fail("规则轨不存在")
		return _accept(
			controller.assign_die(selection.die_id, table_id, rule.slot_count),
			true
		)
	if selection.kind == InteractionState.Kind.CARD:
		var card := hand[selection.card_index]
		if card.target_type != CardDefinition.TargetType.TABLE:
			return _fail("当前手法牌不能作用于规则轨")
		return _accept(controller.play_card(PlayedCard.new(card, table_id)), true)
	return _fail("请先选择骰子或手法牌")

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
	return _accept(controller.assign_die(die_id, table_id, rule.slot_count), false)

func return_die_to_tray(die_id: StringName) -> bool:
	return _accept(controller.unassign_die(die_id), false)

func calibrate_die(die_id: StringName, delta: int) -> bool:
	return _accept(controller.adjust_die(die_id, delta), false)

func undo() -> bool:
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
