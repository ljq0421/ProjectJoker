class_name RoundController
extends RefCounted

var state: RoundState
var encounter: EncounterDefinition
var resolution_context: ResolutionContext
var active_restriction: FinalRestrictionDefinition
var committed: bool = false

var _history: ActionHistory
var _resolver := RoundResolver.new()
var _restriction_evaluator := RoundRestrictionEvaluator.new()
var _committed_report: ResolutionReport

func _init(
	p_state: RoundState,
	p_encounter: EncounterDefinition,
	p_context: ResolutionContext = null,
	p_restriction: FinalRestrictionDefinition = null
) -> void:
	state = p_state.clone()
	encounter = p_encounter
	resolution_context = p_context if p_context != null else ResolutionContext.empty()
	active_restriction = p_restriction
	_history = ActionHistory.new(state)

func adjust_die(die_id: StringName, delta: int) -> ActionResult:
	if committed:
		return ActionResult.new(false, "本轮已经结算", state)
	return _accept(RoundActions.adjust_die(state, die_id, delta, resolution_context))

func assign_die(die_id: StringName, table_id: StringName, slot_limit: int) -> ActionResult:
	if committed:
		return ActionResult.new(false, "本轮已经结算", state)
	return _accept(RoundActions.assign_die(state, die_id, table_id, slot_limit))

func unassign_die(die_id: StringName) -> ActionResult:
	if committed:
		return ActionResult.new(false, "本轮已经结算", state)
	return _accept(RoundActions.unassign_die(state, die_id))

func play_card(played_card: PlayedCard) -> ActionResult:
	if committed:
		return ActionResult.new(false, "本轮已经结算", state)
	var restriction_result := _restriction_evaluator.validate_card_play(
		state,
		active_restriction
	)
	if not restriction_result.accepted:
		return ActionResult.new(false, restriction_result.reason, state)
	return _accept(CardRules.play_card(
		state,
		played_card,
		resolution_context,
		encounter
	))

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
	var restriction_result := _restriction_evaluator.evaluate_commit(
		state,
		encounter,
		active_restriction
	)
	report.restriction_satisfied = restriction_result.accepted
	report.restriction_reason = restriction_result.reason

func _accept(result: ActionResult) -> ActionResult:
	if result.accepted:
		state = result.next_state
		_history.push(state)
	return result
