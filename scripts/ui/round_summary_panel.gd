class_name RoundSummaryPanel
extends Control

signal next_round_requested
signal shop_requested
signal retry_requested
signal return_requested
signal dealer_requested
signal dealer_retry_requested
signal verification_retry_requested

@onready var title_label: Label = %SummaryTitle
@onready var detail_label: Label = %SummaryDetail
@onready var next_button: Button = %NextRoundButton
@onready var shop_button: Button = %EnterShopButton
@onready var retry_button: Button = %RetryRunButton
@onready var return_button: Button = %ReturnTeachingButton
@onready var dealer_button: Button = %ChallengeDealerButton
@onready var dealer_retry_button: Button = %RetryDealerButton
@onready var verification_retry_button: Button = %RetryVerificationButton

func _ready() -> void:
	visible = false
	next_button.pressed.connect(func() -> void: next_round_requested.emit())
	shop_button.pressed.connect(func() -> void: shop_requested.emit())
	retry_button.pressed.connect(func() -> void: retry_requested.emit())
	return_button.pressed.connect(func() -> void: return_requested.emit())
	dealer_button.pressed.connect(func() -> void: dealer_requested.emit())
	dealer_retry_button.pressed.connect(func() -> void: dealer_retry_requested.emit())
	verification_retry_button.pressed.connect(
		func() -> void: verification_retry_requested.emit()
	)

func show_run_state(run_session: ThreeRoundEncounterSession) -> void:
	visible = true
	_hide_actions()
	var last_total := 0
	if not run_session.committed_reports.is_empty():
		last_total = run_session.committed_reports[-1].total
	title_label.text = _title_for_status(run_session.status)
	detail_label.text = (
		"本轮解析：%d\n累计解析：%d / %d\n目标差值：%d"
		% [
			last_total,
			run_session.cumulative_total,
			run_session.target_total,
			maxi(run_session.target_total - run_session.cumulative_total, 0),
		]
	)
	next_button.visible = run_session.status == ThreeRoundEncounterSession.Status.ROUND_SUMMARY
	shop_button.visible = run_session.status == ThreeRoundEncounterSession.Status.SUCCEEDED
	retry_button.visible = run_session.status == ThreeRoundEncounterSession.Status.FAILED
	retry_button.text = "同种子重试"
	return_button.visible = true

func show_dealer_ready(deck_ids: Array[StringName], intel_tickets: int) -> void:
	visible = true
	_hide_actions()
	title_label.text = "铁算盘正在等候"
	detail_label.text = (
		"当前牌组：%d 张\n剩余情报券：%d\n"
		+ "规则公开：每轮 12 点，每颗未分配骰减少 2 点。"
	) % [deck_ids.size(), intel_tickets]
	dealer_button.visible = true
	return_button.visible = true

func show_dealer_failure(run_session: ThreeRoundEncounterSession) -> void:
	visible = true
	_hide_actions()
	var last_report: ResolutionReport = (
		run_session.committed_reports[-1]
		if not run_session.committed_reports.is_empty()
		else ResolutionReport.new()
	)
	title_label.text = "铁算盘挑战未达标"
	detail_label.text = (
		"累计解析：%d / %d\n目标差值：%d\n"
		+ "末轮未分配骰：%d；损失固定奖励：%d"
	) % [
		run_session.cumulative_total,
		run_session.target_total,
		maxi(run_session.target_total - run_session.cumulative_total, 0),
		last_report.unassigned_dice,
		last_report.dealer_reward_lost,
	]
	dealer_retry_button.visible = true
	retry_button.visible = true
	retry_button.text = "完整重试"
	return_button.visible = true

func show_verification_result(applied: bool, reason: String) -> void:
	visible = true
	_hide_actions()
	title_label.text = "刻印验证完成" if applied else "刻印尚未触发"
	detail_label.text = reason
	if not applied:
		verification_retry_button.visible = true
		retry_button.visible = true
		retry_button.text = "完整重试"
	return_button.visible = true

func show_stage_complete(deck_ids: Array[StringName], intel_tickets: int) -> void:
	visible = true
	_hide_actions()
	title_label.text = "阶段试局完成"
	detail_label.text = "最终牌组：%d 张\n剩余情报券：%d" % [
		deck_ids.size(),
		intel_tickets,
	]
	retry_button.visible = true
	retry_button.text = "完整重试"
	return_button.visible = true

func close() -> void:
	visible = false

func _hide_actions() -> void:
	for button in [
		next_button,
		shop_button,
		retry_button,
		return_button,
		dealer_button,
		dealer_retry_button,
		verification_retry_button,
	]:
		button.visible = false

func _title_for_status(status: ThreeRoundEncounterSession.Status) -> String:
	match status:
		ThreeRoundEncounterSession.Status.ROUND_SUMMARY:
			return "本轮完成"
		ThreeRoundEncounterSession.Status.SUCCEEDED:
			return "解析目标达成"
		ThreeRoundEncounterSession.Status.FAILED:
			return "解析目标未达成"
	return "轮次状态"
