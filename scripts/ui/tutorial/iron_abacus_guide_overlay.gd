class_name IronAbacusGuideOverlay
extends Control

signal acknowledged(checkpoint_id: StringName)
signal dismiss_all_requested(checkpoint_id: StringName)

const SAFE_MARGIN := 28.0
const FOCUS_PADDING := 6.0

@onready var dimmer: ColorRect = %GuideDimmer
@onready var focus_frames: Control = %GuideFocusFrames
@onready var card: PanelContainer = %GuideCard
@onready var progress_label: Label = %GuideProgress
@onready var title_label: Label = %GuideTitle
@onready var instruction_label: Label = %GuideInstruction
@onready var warning_label: Label = %GuideWarning
@onready var dismiss_button: Button = %GuideDismissButton
@onready var acknowledge_button: Button = %GuideAcknowledgeButton

var _active_checkpoint_id: StringName = &""
var _targets: Array[Control] = []

func _ready() -> void:
	dismiss_button.pressed.connect(dismiss_all)
	acknowledge_button.pressed.connect(acknowledge_current)
	close_card()

func open_card(card_spec: Dictionary, targets: Array) -> bool:
	close_card()
	var checkpoint_id: StringName = card_spec.get("id", &"")
	if checkpoint_id == &"":
		return false
	var valid_targets: Array[Control] = []
	for candidate in targets:
		var target := candidate as Control
		if target != null and is_instance_valid(target) and target.is_inside_tree():
			valid_targets.append(target)
	if valid_targets.is_empty():
		return false

	_active_checkpoint_id = checkpoint_id
	_targets = valid_targets
	progress_label.text = "进阶提示 %d/%d" % [
		int(card_spec.get("progress_index", 0)),
		int(card_spec.get("progress_total", 5)),
	]
	title_label.text = String(card_spec.get("title", ""))
	instruction_label.text = String(card_spec.get("instruction", ""))
	warning_label.text = ""
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_rebuild_focus_frames()
	acknowledge_button.grab_focus()
	return true

func close_card() -> void:
	_clear_focus_frames()
	_active_checkpoint_id = &""
	_targets.clear()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_node_ready():
		warning_label.text = ""

func is_open() -> bool:
	return visible and _active_checkpoint_id != &""

func acknowledge_current() -> void:
	if not is_open():
		return
	acknowledged.emit(_active_checkpoint_id)

func dismiss_all() -> void:
	if not is_open():
		return
	dismiss_all_requested.emit(_active_checkpoint_id)

func show_persistence_warning(message: String) -> void:
	warning_label.text = message

func refresh_targets() -> void:
	if is_open():
		_rebuild_focus_frames()

func active_checkpoint_id() -> StringName:
	return _active_checkpoint_id

func _unhandled_key_input(event: InputEvent) -> void:
	if not is_open() or not event.is_pressed() or event.is_echo():
		return
	var key_event := event as InputEventKey
	if key_event == null:
		return
	if key_event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE]:
		acknowledge_current()
		get_viewport().set_input_as_handled()

func _rebuild_focus_frames() -> void:
	_clear_focus_frames()
	if not is_open() or not is_inside_tree():
		return
	var target_rects: Array[Rect2] = []
	var overlay_bounds := Rect2(Vector2.ZERO, size)
	for target in _targets:
		if not is_instance_valid(target) or not target.is_inside_tree():
			continue
		var local_rect := _target_rect_in_overlay(target)
		var expanded := _clamp_rect_to_bounds(
			local_rect.grow(FOCUS_PADDING),
			overlay_bounds
		)
		if not expanded.has_area():
			continue
		target_rects.append(expanded)
		var frame := Panel.new()
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.position = expanded.position
		frame.size = expanded.size
		frame.add_theme_stylebox_override("panel", _focus_style())
		focus_frames.add_child(frame)
	if target_rects.is_empty():
		close_card()
		return
	_place_card(target_rects)

func _place_card(target_rects: Array[Rect2]) -> void:
	var minimum := card.get_combined_minimum_size()
	var card_size := Vector2(
		min(
			max(card.custom_minimum_size.x, minimum.x),
			max(size.x - SAFE_MARGIN * 2.0, 1.0)
		),
		min(
			max(card.custom_minimum_size.y, minimum.y),
			max(size.y - SAFE_MARGIN * 2.0, 1.0)
		)
	)
	var centered_x := clampf(
		(size.x - card_size.x) * 0.5,
		SAFE_MARGIN,
		max(SAFE_MARGIN, size.x - card_size.x - SAFE_MARGIN)
	)
	var top := Vector2(centered_x, SAFE_MARGIN)
	var bottom := Vector2(
		centered_x,
		max(SAFE_MARGIN, size.y - card_size.y - SAFE_MARGIN)
	)
	var top_overlap := _overlap_area(Rect2(top, card_size), target_rects)
	var bottom_overlap := _overlap_area(Rect2(bottom, card_size), target_rects)
	var chosen := bottom if bottom_overlap <= top_overlap else top
	chosen.x = clampf(chosen.x, SAFE_MARGIN, max(SAFE_MARGIN, size.x - card_size.x - SAFE_MARGIN))
	chosen.y = clampf(chosen.y, SAFE_MARGIN, max(SAFE_MARGIN, size.y - card_size.y - SAFE_MARGIN))
	card.anchor_left = 0.0
	card.anchor_top = 0.0
	card.anchor_right = 0.0
	card.anchor_bottom = 0.0
	card.offset_left = chosen.x
	card.offset_top = chosen.y
	card.offset_right = chosen.x + card_size.x
	card.offset_bottom = chosen.y + card_size.y

func _overlap_area(candidate: Rect2, target_rects: Array[Rect2]) -> float:
	var total := 0.0
	for target_rect in target_rects:
		var overlap := candidate.intersection(target_rect)
		total += overlap.size.x * overlap.size.y
	return total

func _clear_focus_frames() -> void:
	if not is_node_ready():
		return
	for child in focus_frames.get_children():
		child.free()

func _target_rect_in_overlay(target: Control) -> Rect2:
	var shared_parent := get_parent()
	var target_origin := Vector2.ZERO
	var current: Node = target
	while current != null and current != shared_parent:
		if current is Control:
			target_origin += (current as Control).position
		current = current.get_parent()
	if current == null:
		return Rect2()
	return Rect2(target_origin - position, target.size)

func _clamp_rect_to_bounds(candidate: Rect2, bounds: Rect2) -> Rect2:
	if not candidate.has_area() or not bounds.has_area():
		return Rect2()
	var fitted_size := Vector2(
		min(candidate.size.x, bounds.size.x),
		min(candidate.size.y, bounds.size.y)
	)
	var fitted_position := Vector2(
		clampf(candidate.position.x, bounds.position.x, bounds.end.x - fitted_size.x),
		clampf(candidate.position.y, bounds.position.y, bounds.end.y - fitted_size.y)
	)
	return Rect2(fitted_position, fitted_size)

func _focus_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.22, 0.25, 0.12)
	style.border_color = Color(0.55, 1.0, 0.94, 1.0)
	style.set_border_width_all(4)
	style.set_corner_radius_all(10)
	return style
