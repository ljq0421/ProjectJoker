class_name RoundController
extends RefCounted

var state: RoundState
var encounter: EncounterDefinition
var committed: bool = false

var _history: ActionHistory
var _resolver := RoundResolver.new()
var _committed_report: ResolutionReport

func _init(p_state: RoundState, p_encounter: EncounterDefinition) -> void:
	state = p_state.clone()
	encounter = p_encounter
	_history = ActionHistory.new(state)

func adjust_die(die_id: StringName, delta: int) -> ActionResult:
	if committed:
		return ActionResult.new(false, "round is already committed", state)
	return _accept(RoundActions.adjust_die(state, die_id, delta))

func assign_die(die_id: StringName, table_id: StringName, slot_limit: int) -> ActionResult:
	if committed:
		return ActionResult.new(false, "round is already committed", state)
	return _accept(RoundActions.assign_die(state, die_id, table_id, slot_limit))

func unassign_die(die_id: StringName) -> ActionResult:
	if committed:
		return ActionResult.new(false, "round is already committed", state)
	return _accept(RoundActions.unassign_die(state, die_id))

func play_card(played_card: PlayedCard) -> ActionResult:
	if committed:
		return ActionResult.new(false, "round is already committed", state)
	return _accept(CardRules.play_card(state, played_card))

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
	return _resolver.resolve(state, encounter)

func commit() -> ResolutionReport:
	if committed:
		return _committed_report
	var report := _resolver.resolve(state, encounter)
	if report.valid:
		committed = true
		_committed_report = report
	return report

func _accept(result: ActionResult) -> ActionResult:
	if result.accepted:
		state = result.next_state
		_history.push(state)
	return result
