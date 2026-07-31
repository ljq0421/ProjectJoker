class_name RoundController
extends RefCounted

var state: RoundState
var encounter: EncounterDefinition
var resolution_context: ResolutionContext
var active_restriction: FinalRestrictionDefinition
var active_restrictions: Array[FinalRestrictionDefinition] = []
var committed: bool = false

var _history: ActionHistory
var _resolver := RoundResolver.new()
var _restriction_evaluator := RoundRestrictionEvaluator.new()
var _committed_report: ResolutionReport

func _init(
	p_state: RoundState,
	p_encounter: EncounterDefinition,
	p_context: ResolutionContext = null,
	p_restriction: FinalRestrictionDefinition = null,
	p_additional_restrictions: Array[FinalRestrictionDefinition] = []
) -> void:
	state = p_state.clone()
	encounter = p_encounter
	resolution_context = p_context if p_context != null else ResolutionContext.empty()
	active_restriction = p_restriction
	if p_restriction != null:
		active_restrictions.append(p_restriction)
	for restriction in p_additional_restrictions:
		if restriction != null:
			active_restrictions.append(restriction)
	if active_restriction == null and not active_restrictions.is_empty():
		active_restriction = active_restrictions[0]
	_history = ActionHistory.new(state)

func adjust_die(die_id: StringName, delta: int) -> ActionResult:
	if committed:
		return ActionResult.new(false, "本轮已经结算", state)
	return _accept(RoundActions.adjust_die(state, die_id, delta, resolution_context))

func assign_die(die_id: StringName, table_id: StringName, slot_limit: int) -> ActionResult:
	if committed:
		return ActionResult.new(false, "本轮已经结算", state)
	return _accept(RoundActions.assign_die(state, die_id, table_id, slot_limit))

func assign_die_to_slot(
	die_id: StringName,
	table_id: StringName,
	slot_index: int,
	slot_limit: int
) -> ActionResult:
	if committed:
		return ActionResult.new(false, "本轮已经结算", state)
	return _accept(RoundActions.assign_die_to_slot(
		state,
		die_id,
		table_id,
		slot_index,
		slot_limit
	))

func unassign_die(die_id: StringName) -> ActionResult:
	if committed:
		return ActionResult.new(false, "本轮已经结算", state)
	return _accept(RoundActions.unassign_die(state, die_id))

func play_card(played_card: PlayedCard) -> ActionResult:
	var validation := validate_card_play(played_card)
	if not validation.accepted:
		return validation
	return _accept(validation)

func validate_card_start() -> OperationResult:
	if committed:
		return OperationResult.new(false, "本轮已经结算")
	for restriction in active_restrictions:
		var restriction_result := _restriction_evaluator.validate_card_play(
			state,
			restriction
		)
		if not restriction_result.accepted:
			return restriction_result
	return OperationResult.new(true)

func validate_card_play(played_card: PlayedCard) -> ActionResult:
	var start_result := validate_card_start()
	if not start_result.accepted:
		return ActionResult.new(false, start_result.reason, state)
	return CardRules.play_card(
		state,
		played_card,
		resolution_context,
		encounter
	)

func effective_slot_count(table_id: StringName) -> int:
	return CardRules.effective_slot_count(state, encounter, table_id)

func condition_summary(table_id: StringName) -> String:
	var parts: Array[String] = []
	for modifier in CardRules.condition_modifiers(state, table_id):
		match modifier:
			EffectSpec.ConditionModifier.EXACT_TOLERANCE:
				parts.append("精确值允许 ±1")
			EffectSpec.ConditionModifier.ALLOW_ONE_ODD:
				parts.append("允许 1 颗奇数")
			EffectSpec.ConditionModifier.ALLOW_ONE_GAP:
				parts.append("允许 1 个差二缺口")
			EffectSpec.ConditionModifier.INCREASE_SLOT_COUNT:
				parts.append("所需骰位 +1")
	return "；".join(parts)

func undo() -> bool:
	if committed:
		return false
	var previous := _history.undo()
	if previous == null:
		return false
	state = previous
	return true

func preview() -> ResolutionReport:
	if committed:
		return _committed_report
	var report := _resolver.resolve(state, encounter, resolution_context)
	_attach_restriction(report)
	return report

func commit() -> ResolutionReport:
	if committed:
		return _committed_report
	var report := _resolver.resolve(state, encounter, resolution_context)
	_attach_restriction(report)
	if not report.restriction_satisfied:
		report.valid = false
		report.reason = report.restriction_reason
		return report
	if report.valid:
		committed = true
		_committed_report = report
	return report

func _attach_restriction(report: ResolutionReport) -> void:
	report.restriction_satisfied = true
	report.restriction_reason = ""
	for restriction in active_restrictions:
		var restriction_result := _restriction_evaluator.evaluate_commit(
			state,
			encounter,
			restriction
		)
		if not restriction_result.accepted:
			report.restriction_satisfied = false
			report.restriction_reason = restriction_result.reason
			return

func _accept(result: ActionResult) -> ActionResult:
	if result.accepted:
		state = result.next_state
		_history.push(state)
	return result
