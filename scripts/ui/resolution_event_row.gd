class_name ResolutionEventRow
extends PanelContainer

signal detail_requested(detail_text: String)
signal detail_cleared

const POSITIVE_COLOR := Color("adfff5")
const NEGATIVE_COLOR := Color("ff617a")
const MUTED_COLOR := Color("ada8c2")
const ROW_BACKGROUND := Color(0.055, 0.035, 0.12, 0.82)

@onready var marker_label: Label = %EventMarker
@onready var title_label: Label = %EventTitle
@onready var delta_label: Label = %EventDelta

var _detail_text := ""
var _tone_color := MUTED_COLOR
var _hovered := false


func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)
	_apply_style(false)


func bind_event(
	event: ResolutionEvent,
	short_title: String,
	detail_text: String
) -> void:
	_detail_text = detail_text
	tooltip_text = detail_text
	marker_label.text = "◆"
	title_label.text = short_title
	delta_label.text = "%+d" % event.delta
	_tone_color = POSITIVE_COLOR if event.delta > 0 else NEGATIVE_COLOR
	_apply_metadata(event)
	_apply_color()
	_apply_style(has_focus() or _hovered)


func bind_summary(summary_text: String, detail_text: String) -> void:
	_detail_text = detail_text
	tooltip_text = detail_text
	marker_label.text = "◇"
	title_label.text = summary_text
	delta_label.text = ""
	_tone_color = MUTED_COLOR
	_apply_color()
	_apply_style(has_focus() or _hovered)


func _apply_metadata(event: ResolutionEvent) -> void:
	set_meta("source_id", event.source_id)
	set_meta("is_mirror_copy", event.is_mirror_copy)
	set_meta("source_card_id", event.source_card_id)
	set_meta("source_slot_id", event.source_slot_id)
	set_meta("mirror_slot_id", event.mirror_slot_id)
	set_meta("source_die_id", event.source_die_id)
	set_meta("source_table_id", event.source_table_id)
	set_meta("target_table_id", event.target_table_id)
	set_meta("combo_kind", event.combo_kind)


func _apply_color() -> void:
	marker_label.add_theme_color_override("font_color", _tone_color)
	title_label.add_theme_color_override("font_color", _tone_color)
	delta_label.add_theme_color_override("font_color", _tone_color)


func _apply_style(emphasized: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(
		ROW_BACKGROUND.r,
		ROW_BACKGROUND.g,
		ROW_BACKGROUND.b,
		0.96 if emphasized else ROW_BACKGROUND.a
	)
	style.border_color = Color(
		_tone_color.r,
		_tone_color.g,
		_tone_color.b,
		0.9 if emphasized else 0.48
	)
	style.border_width_left = 3 if emphasized else 2
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_right = 5
	style.corner_radius_bottom_left = 5
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	add_theme_stylebox_override("panel", style)


func _on_mouse_entered() -> void:
	_hovered = true
	_apply_style(true)
	detail_requested.emit(_detail_text)


func _on_mouse_exited() -> void:
	_hovered = false
	_apply_style(has_focus())
	if not has_focus():
		detail_cleared.emit()


func _on_focus_entered() -> void:
	_apply_style(true)
	detail_requested.emit(_detail_text)


func _on_focus_exited() -> void:
	_apply_style(_hovered)
	if not _hovered:
		detail_cleared.emit()
