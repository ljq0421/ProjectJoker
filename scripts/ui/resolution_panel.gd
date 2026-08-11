class_name ResolutionPanel
extends PanelContainer

signal playback_finished(report: ResolutionReport)
signal source_focus_requested(source_id: StringName)
signal event_focus_requested(event: ResolutionEvent)
signal rare_highlight_requested(kind: StringName, running_total: int)
signal highlight_cancel_requested

const PLAYBACK_SCRIPT = preload(
	"res://scripts/resolution/resolution_playback.gd"
)
const EVENT_ROW_SCENE = preload(
	"res://scenes/components/resolution_event_row.tscn"
)
const ScoreLedger = preload("res://scripts/ui/score_ledger_formatter.gd")
const DETAIL_DEFAULT := "悬停或聚焦节点查看完整说明"
const IMPACT_DELTA_THRESHOLD := 8
const STANDARD_GLOW := Color("adfff5")
const IMPACT_GLOW := Color("ebb8ff")

@onready var heading_label: Label = %ResolutionHeading
@onready var status_label: Label = %PlaybackStatus
@onready var prediction_total: Label = %PredictionTotal
@onready var empty_state: Label = %EmptyState
@onready var event_scroll: ScrollContainer = %EventScroll
@onready var event_list: VBoxContainer = %EventList
@onready var event_detail: RichTextLabel = %EventDetail
@onready var playback_actions: Container = %PlaybackActions
@onready var boost_button: Button = %BoostResolutionButton
@onready var finish_button: Button = %FinishResolutionButton

var _playback
var _playing_report: ResolutionReport
var _bound_report: ResolutionReport
var _hidden_events: Array[ResolutionEvent] = []
var _score_event_count := 0
var _reduce_flashes := false
var _disable_distortion := false
var _sound_enabled := true
var _total_hovered := false
var _total_tween: Tween


func _ready() -> void:
	set_process(false)
	boost_button.toggled.connect(_on_boost_toggled)
	finish_button.pressed.connect(finish_playback)
	var summary_row = _hidden_summary_row()
	summary_row.detail_requested.connect(_show_detail)
	summary_row.detail_cleared.connect(_restore_default_detail)
	prediction_total.mouse_entered.connect(_on_total_mouse_entered)
	prediction_total.mouse_exited.connect(_on_total_mouse_exited)
	prediction_total.focus_entered.connect(_show_total_detail)
	prediction_total.focus_exited.connect(_on_total_focus_exited)

func bind_report(report: ResolutionReport) -> void:
	if is_playing():
		return
	_reset_total_motion()
	_reset_report_display("暂无得分变化")
	_reduce_flashes = false
	_disable_distortion = false
	_bound_report = report
	heading_label.text = "预测轨迹"
	status_label.text = "实时预演"
	prediction_total.text = str(report.total)
	_set_total_detail(ScoreLedger.compact_copy(report))
	playback_actions.visible = false
	for event in report.events:
		_register_event(event, false)
	_refresh_empty_state("暂无得分变化")


func play_committed_report(
	report: ResolutionReport,
	accessibility: Dictionary = {}
) -> void:
	_reset_total_motion()
	_reset_report_display("等待得分变化")
	_playing_report = report
	_bound_report = report
	_reduce_flashes = bool(accessibility.get("reduce_flashes", false))
	_disable_distortion = bool(
		accessibility.get("disable_distortion", false)
	)
	heading_label.text = "正式结算"
	status_label.text = "准备逐项解析"
	prediction_total.text = "0"
	_set_total_detail("正式结算进行中｜完成后显示八段构成")
	boost_button.button_pressed = false
	boost_button.text = "2× 加速"
	playback_actions.visible = true
	_playback = PLAYBACK_SCRIPT.new()
	_playback.step_revealed.connect(_on_step_revealed)
	_playback.completed.connect(_on_playback_completed)
	set_process(true)
	_sound_enabled = String(
		accessibility.get("resolution_speed", "normal")
	) != "instant"
	_playback.start(
		report,
		StringName(accessibility.get("resolution_speed", "normal"))
	)


func is_playing() -> bool:
	return _playback != null and not _playback.is_complete()


func finish_playback() -> void:
	if _playback != null:
		if _playback.is_paused():
			highlight_cancel_requested.emit()
		_playback.finish_now()

func resume_after_highlight() -> void:
	if _playback != null and _playback.is_paused():
		_playback.set_paused(false)


func advance_playback_for_test(delta: float) -> void:
	if _playback != null:
		_playback.advance(delta)


func _process(delta: float) -> void:
	if _playback == null:
		set_process(false)
		return
	_playback.advance(delta)


func _on_boost_toggled(enabled: bool) -> void:
	if _playback == null or _playback.is_complete():
		boost_button.button_pressed = false
		return
	_playback.set_temporary_boost(enabled)
	boost_button.text = "恢复原速" if enabled else "2× 加速"
	SfxAccess.play(self, &"ui_confirm")

func _on_step_revealed(step: RefCounted, step_index: int) -> void:
	var step_count: int = _playback.steps().size()
	for local_index in range(step.events.size()):
		var event: ResolutionEvent = step.events[local_index]
		var original_index: int = int(step.original_indices[local_index])
		var emphasis := event_emphasis_for(
			event,
			original_index,
			_playing_report.events.size()
		)
		var row = _register_event(event, true, emphasis)
		if row != null:
			row.set_meta("playback_index", original_index)
			row.set_meta("playback_step_index", step_index)
			row.set_meta("emphasis", emphasis)
	var representative: ResolutionEvent = step.representative_event()
	if representative == null:
		return
	prediction_total.text = str(step.running_total)
	status_label.text = "结算步骤 %d / %d · %+d" % [
		step_index + 1,
		step_count,
		step.delta,
	]
	_set_total_detail(
		"正式结算进行中｜步骤 %d / %d\n本步合计：%+d　累计：%d" % [
			step_index + 1,
			step_count,
			step.delta,
			step.running_total,
		]
	)
	source_focus_requested.emit(representative.source_id)
	event_focus_requested.emit(representative)
	if step.delta != 0:
		_animate_total(&"climax" if step.is_rare_highlight() else &"standard")
	if _sound_enabled:
		var cue_id := sfx_cue_for_emphasis(
			&"climax" if step.is_rare_highlight() else &"standard"
		)
		if cue_id != &"":
			SfxAccess.play(self, cue_id)
	if (
		step.is_rare_highlight()
		and _playback.speed_mode() != &"instant"
		and not _playback.is_finishing_now()
	):
		_playback.set_paused(true)
		rare_highlight_requested.emit(step.highlight_kind, step.running_total)


func _on_event_revealed(event: ResolutionEvent, index: int) -> void:
	var emphasis := event_emphasis_for(
		event,
		index,
		_playing_report.events.size()
	)
	var row = _register_event(event, true, emphasis)
	if row != null:
		row.set_meta("playback_index", index)
		row.set_meta("emphasis", emphasis)
	prediction_total.text = str(event.running_total)
	status_label.text = "事件 %d / %d" % [
		index + 1,
		_playing_report.events.size(),
	]
	_set_total_detail(
		"正式结算进行中｜事件 %d / %d\n当前累计：%d" % [
			index + 1,
			_playing_report.events.size(),
			event.running_total,
		]
	)
	source_focus_requested.emit(event.source_id)
	event_focus_requested.emit(event)
	if event.delta != 0:
		_animate_total(emphasis)
	if _sound_enabled:
		var cue_id := sfx_cue_for_emphasis(emphasis)
		if cue_id != &"":
			SfxAccess.play(self, cue_id)


func _on_playback_completed(report: ResolutionReport) -> void:
	set_process(false)
	playback_actions.visible = false
	boost_button.button_pressed = false
	status_label.text = "已完成 · %d 项" % report.events.size()
	prediction_total.text = str(report.total)
	_set_total_detail(ScoreLedger.compact_copy(report))
	_refresh_empty_state("暂无得分变化")
	playback_finished.emit(report)


func event_emphasis_for(
	event: ResolutionEvent,
	index: int,
	event_count: int
) -> StringName:
	if not event.effect_applied or event.delta == 0:
		return &"muted"
	if event.combo_kind == &"storm":
		return &"climax"
	if absi(event.delta) >= IMPACT_DELTA_THRESHOLD:
		return &"impact"
	return &"standard"


func sfx_cue_for_emphasis(emphasis: StringName) -> StringName:
	match emphasis:
		&"standard":
			return &"resolution_tick"
		&"impact":
			return &"resolution_impact"
		&"climax":
			return &"resolution_climax"
	return &""


func _register_event(
	event: ResolutionEvent,
	animate: bool,
	emphasis: StringName = &"standard"
):
	if event.delta == 0:
		_hidden_events.append(event)
		_refresh_hidden_summary()
		return null
	_score_event_count += 1
	return _append_event_row(event, animate, emphasis)


func _append_event_row(
	event: ResolutionEvent,
	animate: bool,
	emphasis: StringName = &"standard"
):
	var row = EVENT_ROW_SCENE.instantiate()
	event_list.add_child(row)
	row.bind_event(
		event,
		_event_short_title(event),
		_event_detail_copy(event)
	)
	row.set_meta("flash_suppressed", _reduce_flashes)
	row.set_meta("motion_suppressed", _disable_distortion)
	row.set_meta("emphasis", emphasis)
	row.detail_requested.connect(_show_detail)
	row.detail_cleared.connect(_restore_default_detail)
	var summary_row = _hidden_summary_row()
	if summary_row != null:
		event_list.move_child(row, summary_row.get_index())
	event_scroll.visible = true
	empty_state.visible = false
	_queue_scroll_to_latest()
	if animate:
		_animate_row(row, emphasis)
	return row


func _event_short_title(event: ResolutionEvent) -> String:
	var copy := event.label.strip_edges()
	if copy.is_empty():
		return ScoreLedger.source_name(event.score_source)
	if copy.begins_with("镜像副本："):
		var mirror_copy := copy.trim_prefix("镜像副本：")
		var mirror_separator := mirror_copy.find("：")
		return "镜像·%s" % (
			mirror_copy.left(mirror_separator)
			if mirror_separator > 0
			else mirror_copy
		)
	var separator := copy.find("：")
	return copy.left(separator) if separator > 0 else copy


func _event_detail_copy(event: ResolutionEvent) -> String:
	var old_total := event.running_total - event.delta
	var context_copy := _event_context_copy(event)
	return "%s · %s\n%s%s\n%d → %d（%+d）" % [
		"生效" if event.effect_applied else "未触发",
		ScoreLedger.source_name(event.score_source),
		event.label,
		"\n%s" % context_copy if not context_copy.is_empty() else "",
		old_total,
		event.running_total,
		event.delta,
	]


func _event_context_copy(event: ResolutionEvent) -> String:
	match event.combo_kind:
		&"storm":
			return "连击｜风暴高潮"
		&"bridge":
			return "桥接轨迹｜%s → %s" % [
				String(event.source_table_id),
				String(event.target_table_id),
			]
		&"echo":
			return "回声｜回环强化"
		&"rewrite":
			return "复写｜回环强化"
	return ""


func _refresh_hidden_summary() -> void:
	var summary_row = _hidden_summary_row()
	if _hidden_events.is_empty():
		summary_row.visible = false
		return
	var other_effect_count := 0
	var missed_count := 0
	var detail_rows: Array[String] = []
	for index in range(_hidden_events.size()):
		var event := _hidden_events[index]
		if event.effect_applied:
			other_effect_count += 1
		else:
			missed_count += 1
		detail_rows.append("%d. %s" % [index + 1, _event_detail_copy(event)])
	summary_row.visible = true
	summary_row.bind_summary(
		"其他影响 %d · 未触发 %d" % [other_effect_count, missed_count],
		"\n\n".join(detail_rows)
	)
	summary_row.set_meta("other_effect_count", other_effect_count)
	summary_row.set_meta("missed_event_count", missed_count)
	summary_row.set_meta("collapsed_event_count", _hidden_events.size())
	event_scroll.visible = true


func _refresh_empty_state(copy: String) -> void:
	empty_state.text = copy
	empty_state.visible = _score_event_count == 0
	event_scroll.visible = _score_event_count > 0 or not _hidden_events.is_empty()


func _reset_report_display(empty_copy: String) -> void:
	_clear_event_rows()
	_hidden_events.clear()
	_score_event_count = 0
	_hidden_summary_row().visible = false
	empty_state.text = empty_copy
	empty_state.visible = true
	event_scroll.visible = false
	event_scroll.scroll_vertical = 0
	_restore_default_detail()


func _hidden_summary_row():
	return get_node("%HiddenEventSummary")


func _show_detail(detail_text: String) -> void:
	event_detail.text = detail_text if not detail_text.is_empty() else DETAIL_DEFAULT
	event_detail.scroll_to_line(0)


func _restore_default_detail() -> void:
	event_detail.text = DETAIL_DEFAULT
	event_detail.scroll_to_line(0)


func _set_total_detail(detail_text: String) -> void:
	prediction_total.tooltip_text = detail_text
	prediction_total.set_meta("detail_text", detail_text)
	if prediction_total.has_focus() or _total_hovered:
		_show_total_detail()


func _show_total_detail() -> void:
	_show_detail(String(prediction_total.get_meta("detail_text", DETAIL_DEFAULT)))


func _on_total_mouse_entered() -> void:
	_total_hovered = true
	_show_total_detail()


func _on_total_mouse_exited() -> void:
	_total_hovered = false
	if not prediction_total.has_focus():
		_restore_default_detail()


func _on_total_focus_exited() -> void:
	if not _total_hovered:
		_restore_default_detail()


func _queue_scroll_to_latest() -> void:
	call_deferred("_scroll_to_latest")


func _scroll_to_latest() -> void:
	if not is_instance_valid(event_scroll) or not event_scroll.visible:
		return
	event_scroll.scroll_vertical = int(event_scroll.get_v_scroll_bar().max_value)


func _animate_row(row: Control, emphasis: StringName) -> void:
	if _reduce_flashes and _disable_distortion:
		return
	var duration := float({
		&"muted": 0.14,
		&"standard": 0.18,
		&"impact": 0.24,
		&"climax": 0.3,
	}.get(emphasis, 0.18))
	var displacement := float({
		&"muted": 3.0,
		&"standard": 8.0,
		&"impact": 14.0,
		&"climax": 18.0,
	}.get(emphasis, 8.0))
	var peak_scale := Vector2({
		&"muted": Vector2.ONE,
		&"standard": Vector2(1.015, 1.015),
		&"impact": Vector2(1.04, 1.04),
		&"climax": Vector2(1.065, 1.065),
	}.get(emphasis, Vector2.ONE))
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if not _reduce_flashes:
		row.modulate = (
			IMPACT_GLOW
			if emphasis in [&"impact", &"climax"]
			else STANDARD_GLOW
		)
		tween.tween_property(row, "modulate", Color.WHITE, duration)
	if not _disable_distortion:
		row.position.x += displacement
		row.scale = peak_scale
		row.pivot_offset = row.size * 0.5
		tween.tween_property(row, "position:x", 0.0, duration)
		tween.tween_property(row, "scale", Vector2.ONE, duration).set_trans(
			Tween.TRANS_BACK
		)


func _animate_total(emphasis: StringName) -> void:
	if _reduce_flashes and _disable_distortion:
		return
	if _total_tween != null and _total_tween.is_valid():
		_total_tween.kill()
	var peak_scale := (
		Vector2(1.12, 1.12)
		if emphasis == &"climax"
		else Vector2(1.045, 1.045)
	)
	var duration := 0.32 if emphasis == &"climax" else 0.18
	prediction_total.pivot_offset = prediction_total.size * 0.5
	_total_tween = create_tween().set_parallel(true)
	_total_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if not _disable_distortion:
		prediction_total.scale = peak_scale
		_total_tween.tween_property(
			prediction_total,
			"scale",
			Vector2.ONE,
			duration
		)
	if not _reduce_flashes:
		prediction_total.modulate = (
			IMPACT_GLOW
			if emphasis in [&"impact", &"climax"]
			else STANDARD_GLOW
		)
		_total_tween.tween_property(
			prediction_total,
			"modulate",
			Color.WHITE,
			duration
		)


func _clear_event_rows() -> void:
	var summary_row = _hidden_summary_row()
	for child in event_list.get_children():
		if child == summary_row:
			continue
		event_list.remove_child(child)
		child.queue_free()


func _reset_total_motion() -> void:
	if _total_tween != null and _total_tween.is_valid():
		_total_tween.kill()
	_total_tween = null
	if prediction_total != null:
		prediction_total.scale = Vector2.ONE
		prediction_total.modulate = Color.WHITE
