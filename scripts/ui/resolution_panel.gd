class_name ResolutionPanel
extends PanelContainer

signal playback_finished(report: ResolutionReport)
signal source_focus_requested(source_id: StringName)

const PLAYBACK_SCRIPT = preload(
	"res://scripts/resolution/resolution_playback.gd"
)
const APPLIED_COLOR := Color(0.68, 1.0, 0.96, 1.0)
const INACTIVE_COLOR := Color(0.68, 0.66, 0.76, 1.0)
const IMPACT_DELTA_THRESHOLD := 8
const STANDARD_GLOW := Color(0.68, 1.0, 0.96, 1.0)
const IMPACT_GLOW := Color(0.92, 0.72, 1.0, 1.0)

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
var _sound_enabled := true
var _total_tween: Tween

func _ready() -> void:
	set_process(false)
	boost_button.toggled.connect(_on_boost_toggled)
	finish_button.pressed.connect(finish_playback)

func bind_report(report: ResolutionReport) -> void:
	if is_playing():
		return
	_reset_total_motion()
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
	_reset_total_motion()
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
	var emphasis := event_emphasis_for(
		event,
		index,
		_playing_report.events.size()
	)
	var row := _append_event_row(event, true, emphasis)
	row.set_meta("playback_index", index)
	row.set_meta("emphasis", emphasis)
	total_label.text = "正式结算：%d" % event.running_total
	status_label.text = "事件 %d / %d · %s" % [
		index + 1,
		_playing_report.events.size(),
		"生效" if event.effect_applied else "未触发",
	]
	source_focus_requested.emit(event.source_id)
	_animate_total(emphasis)
	if _sound_enabled:
		var cue_id := sfx_cue_for_emphasis(emphasis)
		if cue_id != &"":
			SfxAccess.play(self, cue_id)

func _on_playback_completed(report: ResolutionReport) -> void:
	set_process(false)
	playback_actions.visible = false
	boost_button.button_pressed = false
	status_label.text = "正式结算已完成 · 共 %d 项" % report.events.size()
	total_label.text = "正式结算：%d" % report.total
	_animate_total(&"climax")
	playback_finished.emit(report)

func event_emphasis_for(
	event: ResolutionEvent,
	index: int,
	event_count: int
) -> StringName:
	if not event.effect_applied or event.delta == 0:
		return &"muted"
	if index == event_count - 1:
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

func _append_event_row(
	event: ResolutionEvent,
	animate: bool,
	emphasis: StringName = &"standard"
) -> Label:
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
	row.set_meta("emphasis", emphasis)
	row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_theme_color_override(
		"font_color",
		APPLIED_COLOR if event.effect_applied else INACTIVE_COLOR
	)
	event_list.add_child(row)
	if animate:
		_animate_row(row, emphasis)
	return row

func _animate_row(row: Label, emphasis: StringName) -> void:
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
	total_label.pivot_offset = total_label.size * 0.5
	_total_tween = create_tween().set_parallel(true)
	_total_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if not _disable_distortion:
		total_label.scale = peak_scale
		_total_tween.tween_property(
			total_label,
			"scale",
			Vector2.ONE,
			duration
		)
	if not _reduce_flashes:
		total_label.modulate = (
			IMPACT_GLOW
			if emphasis in [&"impact", &"climax"]
			else STANDARD_GLOW
		)
		_total_tween.tween_property(
			total_label,
			"modulate",
			Color.WHITE,
			duration
		)

func _clear_event_rows() -> void:
	for child in event_list.get_children():
		event_list.remove_child(child)
		child.queue_free()

func _reset_total_motion() -> void:
	if _total_tween != null and _total_tween.is_valid():
		_total_tween.kill()
	_total_tween = null
	if total_label != null:
		total_label.scale = Vector2.ONE
		total_label.modulate = Color.WHITE
