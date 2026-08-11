class_name RoundSummaryPanel
extends Control

const FailureReview = preload("res://scripts/run/failure_review_builder.gd")
const ScoreLedger = preload("res://scripts/ui/score_ledger_formatter.gd")

signal next_round_requested
signal shop_requested
signal retry_requested
signal return_requested
signal dealer_requested
signal dealer_retry_requested
signal verification_retry_requested

@onready var title_label: Label = %SummaryTitle
@onready var detail_label: Label = %SummaryDetail
@onready var dimmer: ColorRect = $Dimmer
@onready var panel_card: PanelContainer = $Center/Panel
@onready var score_block: VBoxContainer = %RoundScoreBlock
@onready var score_value: Label = %RoundScoreValue
@onready var score_ledger: Label = %RoundScoreLedger
@onready var engraving_total: Label = %RoundEngravingTotal
@onready var fact_seal: TextureRect = %RoundFactSeal
@onready var fact_badges: Label = %RoundFactBadges
@onready var retention_block: VBoxContainer = %RetentionBlock
@onready var retention_choice: OptionButton = %RetentionChoice
@onready var next_button: Button = %NextRoundButton
@onready var shop_button: Button = %EnterShopButton
@onready var retry_button: Button = %RetryRunButton
@onready var return_button: Button = %ReturnTeachingButton
@onready var dealer_button: Button = %ChallengeDealerButton
@onready var dealer_retry_button: Button = %RetryDealerButton
@onready var verification_retry_button: Button = %RetryVerificationButton
@onready var failure_review: Control = %FailureReview
@onready var failure_result_label: Label = %FailureResultLabel
@onready var failure_loss_label: Label = %FailureLossLabel
@onready var failure_suggestion_label: Label = %FailureSuggestionLabel

var _summary_tween: Tween
var _retention_session: ThreeRoundEncounterSession

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
	retention_choice.item_selected.connect(_on_retention_selected)

func show_run_state(
	run_session: ThreeRoundEncounterSession,
	emergency_free: bool = false
) -> void:
	visible = true
	_hide_actions()
	match run_session.status:
		ThreeRoundEncounterSession.Status.SUCCEEDED:
			SfxAccess.play(self, &"round_success")
		ThreeRoundEncounterSession.Status.FAILED:
			SfxAccess.play(self, &"round_failure")
		_:
			SfxAccess.play(self, &"panel_open")
	var last_total := 0
	var last_report: ResolutionReport
	if not run_session.committed_reports.is_empty():
		last_report = run_session.committed_reports[-1]
		last_total = last_report.total
		score_ledger.text = ScoreLedger.compact_copy(
			last_report
		)
		engraving_total.text = "本轮刻印贡献：%+d" % int(
			last_report.score_breakdown.get(
				ResolutionEvent.ScoreSource.ENGRAVING,
				0
			)
		)
	else:
		last_report = ResolutionReport.new()
		score_ledger.text = ScoreLedger.compact_copy(ResolutionReport.new())
		engraving_total.text = "本轮刻印贡献：+0"
	score_block.visible = true
	_bind_fact_badges(last_report, emergency_free)
	score_value.text = str(last_total)
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
	detail_label.text += "\n契约封印｜%s" % _contract_seal_copy(
		run_session.cumulative_total,
		run_session.target_total
	)
	if run_session.status == ThreeRoundEncounterSession.Status.FAILED:
		_bind_failure_review(run_session, false)
	next_button.visible = run_session.status == ThreeRoundEncounterSession.Status.ROUND_SUMMARY
	_bind_retention(run_session)
	shop_button.visible = run_session.status == ThreeRoundEncounterSession.Status.SUCCEEDED
	retry_button.visible = run_session.status == ThreeRoundEncounterSession.Status.FAILED
	retry_button.text = "同种子重试"
	return_button.visible = true
	_play_round_summary_climax(_rare_fact_kind(last_report))

func show_room_checkpoint(room_summary: Dictionary) -> void:
	visible = true
	SfxAccess.play(self, &"panel_open")
	_hide_actions()
	title_label.text = "解析目标达成"
	detail_label.text = "累计解析：%d / %d\n房间已封存，可进入商店。" % [
		room_summary.get("cumulative_total", 0),
		room_summary.get("target_total", 0),
	]
	shop_button.visible = true
	return_button.visible = true

func show_dealer_ready(deck_ids: Array[StringName], intel_tickets: int) -> void:
	visible = true
	SfxAccess.play(self, &"panel_open")
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
	SfxAccess.play(self, &"round_failure")
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
	_bind_failure_review(run_session, true)
	dealer_retry_button.visible = true
	retry_button.visible = true
	retry_button.text = "完整重试"
	return_button.visible = true

func show_area_failure(
	run_session: ThreeRoundEncounterSession,
	dealer_failure: bool,
	area_name: String = "金线回廊",
	dealer_name: String = "铁算盘"
) -> void:
	visible = true
	SfxAccess.play(self, &"round_failure")
	_hide_actions()
	title_label.text = (
		"%s挑战未达标" % dealer_name
		if dealer_failure
		else "%s解析未达标" % area_name
	)
	detail_label.text = "累计解析：%d / %d\n目标差值：%d" % [
		run_session.cumulative_total,
		run_session.target_total,
		maxi(run_session.target_total - run_session.cumulative_total, 0),
	]
	_bind_failure_review(run_session, dealer_failure)
	retry_button.visible = true
	retry_button.text = "重新开始%s" % area_name
	return_button.visible = true
	return_button.text = "返回入口"

func show_verification_result(applied: bool, reason: String) -> void:
	visible = true
	SfxAccess.play(self, &"round_success" if applied else &"round_failure")
	_hide_actions()
	title_label.text = "刻印验证完成" if applied else "刻印尚未触发"
	detail_label.text = reason
	if applied:
		retry_button.visible = true
		retry_button.text = "完整重试"
	else:
		verification_retry_button.visible = true
		retry_button.visible = true
		retry_button.text = "完整重试"
	return_button.visible = true

func show_stage_complete(deck_ids: Array[StringName], intel_tickets: int) -> void:
	visible = true
	SfxAccess.play(self, &"panel_open")
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
	failure_review.visible = false
	score_block.visible = false
	retention_block.visible = false
	_retention_session = null
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

func _bind_retention(run_session: ThreeRoundEncounterSession) -> void:
	retention_choice.clear()
	retention_choice.add_item("不保留手牌")
	retention_choice.set_item_metadata(0, &"")
	if not run_session.retention_available():
		retention_block.visible = false
		return
	_retention_session = run_session
	for card_id in run_session.retainable_card_ids():
		var card := run_session.catalog.find_card(card_id)
		retention_choice.add_item(
			"保留｜%s" % (card.display_name if card != null else String(card_id))
		)
		retention_choice.set_item_metadata(
			retention_choice.item_count - 1,
			card_id
		)
	retention_block.visible = retention_choice.item_count > 1

func _on_retention_selected(index: int) -> void:
	if _retention_session == null:
		return
	var card_id := StringName(retention_choice.get_item_metadata(index))
	var result := _retention_session.retain_card(card_id)
	if not result.accepted:
		retention_choice.select(0)


func _play_round_summary_climax(rare_kind: StringName = &"") -> void:
	set_meta(
		"last_motion_kind",
		&"rare_fact_summary" if rare_kind != &"" else &"round_complete_summary"
	)
	if _summary_tween != null and _summary_tween.is_valid():
		_summary_tween.kill()
	var settings := get_node_or_null("/root/SettingsService")
	var reduce_flashes := false
	var disable_distortion := false
	if settings != null and settings.has_method("accessibility_value"):
		reduce_flashes = bool(settings.call("accessibility_value", &"reduce_flashes"))
		disable_distortion = bool(
			settings.call("accessibility_value", &"disable_distortion")
		)
	dimmer.modulate.a = 1.0
	panel_card.pivot_offset = panel_card.size * 0.5
	score_value.pivot_offset = score_value.size * 0.5
	panel_card.scale = Vector2.ONE if disable_distortion else (
		Vector2(0.9, 0.9) if rare_kind != &"" else Vector2(0.96, 0.96)
	)
	score_value.scale = Vector2.ONE if disable_distortion else (
		Vector2(1.12, 1.12) if rare_kind != &"" else Vector2(1.04, 1.04)
	)
	score_value.modulate = (
		Color.WHITE
		if reduce_flashes or rare_kind == &""
		else Color(0.92, 0.72, 1.0, 1.0)
	)
	_summary_tween = create_tween()
	_summary_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if not reduce_flashes and rare_kind != &"":
		_summary_tween.parallel().tween_property(
			score_value,
			"modulate",
			Color.WHITE,
			0.28
		)
	if not disable_distortion:
		_summary_tween.parallel().tween_property(
			panel_card,
			"scale",
			Vector2.ONE,
			0.22
		)
		_summary_tween.parallel().tween_property(
			score_value,
			"scale",
			Vector2.ONE,
			0.28
		)

func _bind_fact_badges(
	report: ResolutionReport,
	emergency_free: bool = false
) -> void:
	var facts: Array[String] = []
	if report.calibration_actions == 0:
		facts.append("零校准")
	if report.assigned_dice == 6:
		facts.append("六骰齐备")
	if report.passed_rule_count == 3:
		facts.append("三台全过")
	if emergency_free:
		facts.append("无应急")
	fact_badges.text = " · ".join(facts) if not facts.is_empty() else "本轮无额外事实徽章"
	var rare_kind := _rare_fact_kind(report)
	fact_seal.visible = rare_kind != &""
	fact_seal.texture = (
		load(_rare_fact_seal_path(rare_kind)) as Texture2D
		if rare_kind != &""
		else null
	)

func _rare_fact_kind(report: ResolutionReport) -> StringName:
	if report.storm_awarded:
		return &"storm"
	if report.resonance_awarded:
		return &"resonance"
	for event in report.events:
		if event.source_id == &"full_table_critical":
			return &"lucky"
	if not report.engraving_set_activations.is_empty():
		return &"engraving_set"
	return &""

func _rare_fact_seal_path(kind: StringName) -> String:
	return "res://resources/ui/dream_glass/feedback/seal_%s.svg" % kind

func _contract_seal_copy(cumulative_total: int, target_total: int) -> String:
	var lit_count := 0
	if target_total > 0:
		lit_count = clampi(floori(float(cumulative_total) / float(target_total) * 4.0 + 0.0001), 0, 4)
	return "◆".repeat(lit_count) + "◇".repeat(4 - lit_count)

func _title_for_status(status: ThreeRoundEncounterSession.Status) -> String:
	match status:
		ThreeRoundEncounterSession.Status.ROUND_SUMMARY:
			return "本轮完成"
		ThreeRoundEncounterSession.Status.SUCCEEDED:
			return "解析目标达成"
		ThreeRoundEncounterSession.Status.FAILED:
			return "解析目标未达成"
	return "轮次状态"

func _bind_failure_review(
	run_session: ThreeRoundEncounterSession,
	dealer_failure: bool
) -> void:
	var review: Dictionary = FailureReview.new().build(
		run_session.committed_reports,
		run_session.target_total,
		dealer_failure
	)
	failure_result_label.text = (
		"结果｜累计 %d / %d，差 %d；最低为第 %d 轮（%d 点）。"
		% [
			review["cumulative_total"],
			review["target_total"],
			review["target_gap"],
			review["weakest_round"],
			review["weakest_total"],
		]
	)
	var losses: Array[String] = []
	if review["unassigned_dice"] > 0:
		losses.append("未分配骰 %d 颗" % review["unassigned_dice"])
	if review["dealer_reward_lost"] > 0:
		losses.append("庄家固定奖励损失 %d 点" % review["dealer_reward_lost"])
	for failure in review["rule_failures"].slice(
		0,
		mini(1, review["rule_failures"].size())
	):
		losses.append(
			"%s：%s"
			% [
				failure.get("display_name", failure.get("rule_id", "规则台")),
				failure.get("reason", "未满足公开条件"),
			]
		)
	if losses.is_empty():
		losses.append("未记录额外损失；主要差距来自各轮累计得分。")
	failure_loss_label.text = "主要损失｜%s" % "；".join(losses)
	var suggestions: Array[String] = []
	for index in range(mini(1, review["suggestions"].size())):
		suggestions.append(
			"%d. %s" % [index + 1, review["suggestions"][index]]
		)
	failure_suggestion_label.text = (
		"下次可尝试｜%s" % "　".join(suggestions)
		if not suggestions.is_empty()
		else "下次可尝试｜复盘各轮规则成立情况，再调整分配顺序。"
	)
	failure_review.visible = true
