class_name RoundSummaryPanel
extends Control

signal next_round_requested
signal shop_requested
signal retry_requested
signal return_requested

@onready var title_label: Label = %SummaryTitle
@onready var detail_label: Label = %SummaryDetail
@onready var next_button: Button = %NextRoundButton
@onready var shop_button: Button = %EnterShopButton
@onready var retry_button: Button = %RetryRunButton
@onready var return_button: Button = %ReturnTeachingButton

func _ready() -> void:
	visible = false
	next_button.pressed.connect(func() -> void: next_round_requested.emit())
	shop_button.pressed.connect(func() -> void: shop_requested.emit())
	retry_button.pressed.connect(func() -> void: retry_requested.emit())
	return_button.pressed.connect(func() -> void: return_requested.emit())

func show_run_state(run_session: ThreeRoundEncounterSession) -> void:
	visible = true
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
	return_button.visible = true

func show_stage_complete(deck_ids: Array[StringName], intel_tickets: int) -> void:
	visible = true
	title_label.text = "阶段试局完成"
	detail_label.text = "最终牌组：%d 张\n剩余情报券：%d" % [
		deck_ids.size(),
		intel_tickets,
	]
	next_button.visible = false
	shop_button.visible = false
	retry_button.visible = true
	return_button.visible = true

func close() -> void:
	visible = false

func _title_for_status(status: ThreeRoundEncounterSession.Status) -> String:
	match status:
		ThreeRoundEncounterSession.Status.ROUND_SUMMARY:
			return "本轮完成"
		ThreeRoundEncounterSession.Status.SUCCEEDED:
			return "解析目标达成"
		ThreeRoundEncounterSession.Status.FAILED:
			return "解析目标未达成"
	return "轮次状态"
