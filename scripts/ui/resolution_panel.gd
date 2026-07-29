class_name ResolutionPanel
extends PanelContainer

signal playback_finished(report: ResolutionReport)
signal source_focus_requested(source_id: StringName)

const PLAYBACK_SCRIPT = preload(
	"res://scripts/resolution/resolution_playback.gd"
)
const APPLIED_COLOR := Color(0.68, 1.0, 0.96, 1.0)
const INACTIVE_COLOR := Color(0.68, 0.66, 0.76, 1.0)

@onready var heading_label: Label = %ResolutionHeading
@onready var status_label: Label = %PlaybackStatus
@onready var event_list: VBoxContainer = %EventList
@onready var total_label: Label = %Total
@onready var playback_actions: HBoxContainer = %PlaybackActions
@onready var boost_button: Button = %BoostResolutionButton
@onready var finish_button: Button = %FinishResolutionButton

var _playback
var _playing_report: ResolutionReport
var _reduce_flashes := false
var _disable_distortion := false

func _ready() -> void:
	set_process(false)
	boost_button.toggled.connect(_on_boost_toggled)
	finish_button.pressed.connect(finish_playback)

func bind_report(report: ResolutionReport) -> void:
	if is_playing():
		return
	_clear_event_rows()
	_reduce_flashes = false
	_disable_distortion = false
	heading_label.text = "预测轨迹"
	status_label.text = "方案变化会立即刷新"
	playback_actions.visible = false
	for event in report.events:
		_append_event_row(event, false)
	total_label.text = "预测结算：%d" % report.total

func play_committed_report(
	report: ResolutionReport,
	accessibility: Dictionary = {}
) -> void:
	_clear_event_rows()
	_playing_report = report
	_reduce_flashes = bool(accessibility.get("reduce_flashes", false))
	_disable_distortion = bool(
		accessibility.get("disable_distortion", false)
	)
	heading_label.text = "正式结算"
	status_label.text = "正在按已提交事件逐项解析"
	total_label.text = "正式结算：0"
	boost_button.button_pressed = false
	boost_button.text = "2× 加速"
	playback_actions.visible = true
	_playback = PLAYBACK_SCRIPT.new()
	_playback.event_revealed.connect(_on_event_revealed)
	_playback.completed.connect(_on_playback_completed)
	set_process(true)
	_playback.start(
		report,
		StringName(accessibility.get("resolution_speed", "normal"))
	)

func is_playing() -> bool:
	return _playback != null and not _playback.is_complete()

func finish_playback() -> void:
	if _playback != null:
		_playback.finish_now()

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

func _on_event_revealed(event: ResolutionEvent, index: int) -> void:
	var row := _append_event_row(event, true)
	row.set_meta("playback_index", index)
	total_label.text = "正式结算：%d" % event.running_total
	status_label.text = "事件 %d / %d · %s" % [
		index + 1,
		_playing_report.events.size(),
		"生效" if event.effect_applied else "未触发",
	]
	source_focus_requested.emit(event.source_id)
	SfxAccess.play(self, &"ui_confirm")

func _on_playback_completed(report: ResolutionReport) -> void:
	set_process(false)
	playback_actions.visible = false
	boost_button.button_pressed = false
	status_label.text = "正式结算已完成 · 共 %d 项" % report.events.size()
	total_label.text = "正式结算：%d" % report.total
	playback_finished.emit(report)

func _append_event_row(event: ResolutionEvent, animate: bool) -> Label:
	var row := Label.new()
	var old_total := event.running_total - event.delta
	row.text = "%s %s\n%d → %d（%+d）" % [
		"◆ 生效" if event.effect_applied else "◇ 未触发",
		event.label,
		old_total,
		event.running_total,
		event.delta,
	]
	row.set_meta("source_id", event.source_id)
	row.set_meta("is_mirror_copy", event.is_mirror_copy)
	row.set_meta("source_card_id", event.source_card_id)
	row.set_meta("source_slot_id", event.source_slot_id)
	row.set_meta("mirror_slot_id", event.mirror_slot_id)
	row.set_meta("flash_suppressed", _reduce_flashes)
	row.set_meta("motion_suppressed", _disable_distortion)
	row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_theme_color_override(
		"font_color",
		APPLIED_COLOR if event.effect_applied else INACTIVE_COLOR
	)
	event_list.add_child(row)
	if animate:
		_animate_row(row)
	return row

func _animate_row(row: Label) -> void:
	if _reduce_flashes and _disable_distortion:
		return
	var tween := create_tween()
	tween.set_parallel(true)
	if not _reduce_flashes:
		row.modulate = Color(1.2, 1.2, 1.2, 1.0)
		tween.tween_property(row, "modulate", Color.WHITE, 0.18)
	if not _disable_distortion:
		row.position.x += 6.0
		tween.tween_property(row, "position:x", 0.0, 0.18)

func _clear_event_rows() -> void:
	for child in event_list.get_children():
		event_list.remove_child(child)
		child.queue_free()
