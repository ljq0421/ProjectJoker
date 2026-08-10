class_name RoundController
extends RefCounted

const SnapshotCodec = preload("res://scripts/run/run_snapshot_codec.gd")

enum UndoMode {
	SPLIT,
	GLOBAL_ONE,
}

const MAX_CATEGORY_UNDOS := 1

var state: RoundState
var encounter: EncounterDefinition
var resolution_context: ResolutionContext
var active_restriction: FinalRestrictionDefinition
var active_restrictions: Array[FinalRestrictionDefinition] = []
var committed: bool = false
var undo_mode: UndoMode = UndoMode.GLOBAL_ONE

var _history: ActionHistory
var _resolver := RoundResolver.new()
var _restriction_evaluator := RoundRestrictionEvaluator.new()
var _committed_report: ResolutionReport
var _calibration_undo_count := 0
var _card_undo_count := 0
var _global_undo_count := 0
var _calibration_action_count := 0

func _init(
	p_state: RoundState,
	p_encounter: EncounterDefinition,
	p_context: ResolutionContext = null,
	p_restriction: FinalRestrictionDefinition = null,
	p_additional_restrictions: Array[FinalRestrictionDefinition] = [],
	p_undo_mode: UndoMode = UndoMode.GLOBAL_ONE
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
	undo_mode = p_undo_mode

func adjust_die(die_id: StringName, delta: int) -> ActionResult:
	if committed:
		return ActionResult.new(false, "本轮已经结算", state)
	return _accept(
		RoundActions.adjust_die(state, die_id, delta, resolution_context),
		ActionHistory.Kind.CALIBRATION
	)

func assign_die(die_id: StringName, table_id: StringName, slot_limit: int) -> ActionResult:
	if committed:
		return ActionResult.new(false, "本轮已经结算", state)
	return _accept(
		RoundActions.assign_die(state, die_id, table_id, slot_limit),
		ActionHistory.Kind.PLACEMENT
	)

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
	), ActionHistory.Kind.PLACEMENT)

func unassign_die(die_id: StringName) -> ActionResult:
	if committed:
		return ActionResult.new(false, "本轮已经结算", state)
	return _accept(
		RoundActions.unassign_die(state, die_id),
		ActionHistory.Kind.PLACEMENT
	)

func play_card(played_card: PlayedCard) -> ActionResult:
	var validation := validate_card_play(played_card)
	if not validation.accepted:
		return validation
	return _accept(validation, ActionHistory.Kind.CARD)

func apply_paid_reroll(die_id: StringName, rolled_value: int) -> OperationResult:
	if committed:
		return OperationResult.new(false, "本轮已经结算")
	if rolled_value < 1 or rolled_value > 6:
		return OperationResult.new(false, "重投点数必须在一到六之间")
	var die := state.find_die(die_id)
	if die == null:
		return OperationResult.new(false, "重投目标骰子不存在")
	if die_id in state.locked_die_ids():
		return OperationResult.new(false, "已锁定骰子不能重投")
	if die.faulted:
		return OperationResult.new(false, "故障骰子最终值固定为 1，不能重投")
	_history.transform_all_states(
		func(snapshot: RoundState) -> RoundState:
			var target := snapshot.find_die(die_id)
			if target != null:
				var calibration_delta := target.value - target.rolled_value
				target.rolled_value = rolled_value
				target.value = clampi(rolled_value + calibration_delta, 1, 6)
			return snapshot
	)
	state = _history.current_state()
	return OperationResult.new(true)

func apply_paid_calibration() -> OperationResult:
	if committed:
		return OperationResult.new(false, "本轮已经结算")
	if state.calibration_locked:
		return OperationResult.new(false, "孤注一掷已锁定本轮校准")
	_history.transform_all_states(
		func(snapshot: RoundState) -> RoundState:
			snapshot.calibration_points += 1
			return snapshot
	)
	state = _history.current_state()
	return OperationResult.new(true)

func convert_rank_card(card_id: StringName, amount: int) -> ActionResult:
	if committed:
		return ActionResult.new(false, "本轮已经结算", state)
	if state.rank_conversion_used:
		return ActionResult.new(false, "本轮已经折算过一张数字牌", state)
	if state.calibration_locked:
		return ActionResult.new(false, "孤注一掷已锁定本轮校准", state)
	if amount < 1 or amount > 3:
		return ActionResult.new(false, "这张牌不能折作校准", state)
	if card_id == &"" or card_id in state.discarded_card_ids:
		return ActionResult.new(false, "这张牌已经离开手牌", state)
	var next_state := state.clone()
	next_state.discarded_card_ids.append(card_id)
	next_state.rank_conversion_used = true
	next_state.calibration_points += amount
	return _accept(
		ActionResult.new(true, "", next_state),
		ActionHistory.Kind.CARD
	)

func validate_card_start() -> OperationResult:
	if committed:
		return OperationResult.new(false, "本轮已经结算")
	for restriction in active_restrictions:
		var restriction_result := _restriction_evaluator.validate_card_play(
			state,
			restriction,
			resolution_context
		)
		if not restriction_result.accepted:
			return restriction_result
	return CardRules.validate_card_start(state, resolution_context)

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
	if not can_undo():
		return false
	_last_undone_kind = _history.last_kind()
	var previous := _history.undo()
	if previous == null:
		return false
	state = previous
	var kind := _last_undone_kind
	if undo_mode == UndoMode.GLOBAL_ONE:
		_global_undo_count += 1
	elif kind == ActionHistory.Kind.CALIBRATION:
		_calibration_undo_count += 1
	elif kind == ActionHistory.Kind.CARD:
		_card_undo_count += 1
	return true

func can_undo() -> bool:
	return undo_block_reason().is_empty()

var _last_undone_kind: ActionHistory.Kind = ActionHistory.Kind.SYSTEM

func undo_remaining() -> int:
	if undo_mode == UndoMode.GLOBAL_ONE:
		return maxi(1 - _global_undo_count, 0)
	match _history.last_kind():
		ActionHistory.Kind.CALIBRATION:
			return calibration_undos_remaining()
		ActionHistory.Kind.CARD:
			return card_undos_remaining()
		ActionHistory.Kind.PLACEMENT:
			return 1
	return 0

func calibration_undos_remaining() -> int:
	return maxi(
		MAX_CATEGORY_UNDOS + state.extra_calibration_undos - _calibration_undo_count,
		0
	)

func card_undos_remaining() -> int:
	return maxi(
		MAX_CATEGORY_UNDOS + state.extra_card_undos - _card_undo_count,
		0
	)

func placement_undo_copy() -> String:
	return "落子不限" if undo_mode == UndoMode.SPLIT else "全局 %d" % undo_remaining()

func undo_status_copy() -> String:
	if undo_mode == UndoMode.GLOBAL_ONE:
		return "落子无悔：全局撤销 %d/1" % undo_remaining()
	return "落子不限 · 校准撤销 %d/%d · 卡牌撤销 %d/%d" % [
		calibration_undos_remaining(),
		MAX_CATEGORY_UNDOS + state.extra_calibration_undos,
		card_undos_remaining(),
		MAX_CATEGORY_UNDOS + state.extra_card_undos,
	]

func undo_block_reason() -> String:
	if committed:
		return "本轮已经结算"
	if not _history.can_undo():
		return "当前没有可撤销的操作"
	if undo_remaining() <= 0:
		if undo_mode == UndoMode.GLOBAL_ONE:
			return "落子无悔：本回合的全局撤销已经用完"
		match _history.last_kind():
			ActionHistory.Kind.CALIBRATION:
				return "本回合的校准撤销已经用完"
			ActionHistory.Kind.CARD:
				return "本回合的卡牌撤销已经用完"
	return ""

func preview() -> ResolutionReport:
	if committed:
		return _committed_report
	var report := _resolver.resolve(state, encounter, resolution_context)
	report.calibration_actions = _calibration_action_count
	_attach_restriction(report)
	return report

func commit() -> ResolutionReport:
	if committed:
		return _committed_report
	var report := _resolver.resolve(state, encounter, resolution_context)
	report.calibration_actions = _calibration_action_count
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
			restriction,
			resolution_context
		)
		if not restriction_result.accepted:
			report.restriction_satisfied = false
			report.restriction_reason = restriction_result.reason
			return

func _accept(
	result: ActionResult,
	kind: ActionHistory.Kind = ActionHistory.Kind.SYSTEM
) -> ActionResult:
	if result.accepted:
		state = result.next_state
		_history.push(state, kind)
		if kind == ActionHistory.Kind.CALIBRATION:
			_calibration_action_count += 1
	return result

func to_snapshot() -> Dictionary:
	return {
		"history": _history.to_snapshot(),
		"committed": committed,
		"committed_report": (
			SnapshotCodec.report_to_snapshot(_committed_report)
			if _committed_report != null
			else {}
		),
		"calibration_undo_count": _calibration_undo_count,
		"card_undo_count": _card_undo_count,
		"global_undo_count": _global_undo_count,
		"calibration_action_count": _calibration_action_count,
		"undo_mode": undo_mode,
	}

func restore_snapshot(snapshot: Dictionary, catalog: CardCatalog) -> OperationResult:
	var history_result := _history.restore_snapshot(
		snapshot.get("history", []),
		catalog
	)
	if not history_result.accepted:
		return history_result
	state = _history.current_state()
	committed = bool(snapshot.get("committed", false))
	undo_mode = snapshot.get("undo_mode", undo_mode)
	_calibration_undo_count = int(snapshot.get("calibration_undo_count", 0))
	_card_undo_count = int(snapshot.get("card_undo_count", 0))
	_global_undo_count = int(snapshot.get("global_undo_count", 0))
	_calibration_action_count = int(snapshot.get("calibration_action_count", 0))
	var report_snapshot: Dictionary = snapshot.get("committed_report", {})
	_committed_report = (
		SnapshotCodec.report_from_snapshot(report_snapshot)
		if not report_snapshot.is_empty()
		else null
	)
	return OperationResult.new(true)
