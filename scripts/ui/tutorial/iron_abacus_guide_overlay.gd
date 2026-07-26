class_name IronAbacusGuideOverlay
extends Control

signal acknowledged(checkpoint_id: StringName)
signal dismiss_all_requested(checkpoint_id: StringName)

const SAFE_MARGIN := 28.0
const FOCUS_PADDING := 6.0
const STANDARD_CARD_MINIMUM_SIZE := Vector2(540, 236)
const ROUTE_RAIL_MARGIN := 8.0
const ROUTE_RAIL_TOP := 0.0

@onready var dimmer: ColorRect = %GuideDimmer
@onready var focus_frames: Control = %GuideFocusFrames
@onready var card: PanelContainer = %GuideCard
@onready var margins: MarginContainer = card.get_node("Margins")
@onready var content: VBoxContainer = margins.get_node("Content")
@onready var actions: HBoxContainer = content.get_node("Actions")
@onready var progress_label: Label = %GuideProgress
@onready var title_label: Label = %GuideTitle
@onready var instruction_label: Label = %GuideInstruction
@onready var warning_label: Label = %GuideWarning
@onready var dismiss_button: Button = %GuideDismissButton
@onready var acknowledge_button: Button = %GuideAcknowledgeButton

var _active_checkpoint_id: StringName = &""
var _targets: Array[Control] = []
var _layout_refresh_serial := 0
var _route_rail_allowed := false
var _route_rail: HBoxContainer
var _route_copy: VBoxContainer
var _route_rail_active := false
var _standard_card_minimum_size := STANDARD_CARD_MINIMUM_SIZE
var _standard_margin_constants: Dictionary = {}
var _standard_title_font_size := 25
var _standard_layout_captured := false

func _ready() -> void:
	_capture_standard_card_layout()
	dismiss_button.pressed.connect(dismiss_all)
	acknowledge_button.pressed.connect(acknowledge_current)
	close_card()

func open_card(card_spec: Dictionary, targets: Array) -> bool:
	close_card()
	var checkpoint_id: StringName = card_spec.get("id", &"")
	if checkpoint_id == &"":
		return false
	var required_targets: Array[Control] = []
	for candidate in targets:
		var target := candidate as Control
		if target == null:
			return false
		required_targets.append(target)
	if required_targets.is_empty():
		return false

	_active_checkpoint_id = checkpoint_id
	_targets = required_targets
	_route_rail_allowed = (
		checkpoint_id == &"route"
		and int(card_spec.get("progress_total", 0)) == 4
	)
	_layout_refresh_serial += 1
	var refresh_serial := _layout_refresh_serial
	var progress_copy := String(card_spec.get("progress_label", "进阶提示"))
	progress_label.text = "%s %d/%d" % [
		progress_copy,
		int(card_spec.get("progress_index", 0)),
		int(card_spec.get("progress_total", 5)),
	]
	title_label.text = String(card_spec.get("title", ""))
	instruction_label.text = String(card_spec.get("instruction", ""))
	warning_label.text = ""
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	if not _rebuild_focus_frames():
		close_card()
		return false
	_refresh_after_layout(refresh_serial, checkpoint_id)
	acknowledge_button.grab_focus()
	return true

func close_card() -> void:
	_layout_refresh_serial += 1
	_clear_focus_frames()
	_active_checkpoint_id = &""
	_targets.clear()
	_route_rail_allowed = false
	_restore_standard_card_layout()
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
	if is_open() and not _rebuild_focus_frames():
		close_card()

func _refresh_after_layout(
	refresh_serial: int,
	checkpoint_id: StringName
) -> void:
	for frame_index in range(2):
		await get_tree().process_frame
		if (
			refresh_serial != _layout_refresh_serial
			or checkpoint_id != _active_checkpoint_id
			or not is_open()
		):
			return
		if not _rebuild_focus_frames():
			close_card()
			return

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

func _rebuild_focus_frames() -> bool:
	_clear_focus_frames()
	if not is_open() or not is_inside_tree():
		return false
	var target_rects: Array[Rect2] = []
	var overlay_bounds := Rect2(Vector2.ZERO, size)
	if not overlay_bounds.has_area():
		return false
	for target in _targets:
		if (
			not is_instance_valid(target)
			or target.is_queued_for_deletion()
			or not target.is_inside_tree()
			or not target.is_visible_in_tree()
		):
			return false
		var local_rect := _target_rect_in_overlay(target)
		if (
			not local_rect.has_area()
			or not local_rect.intersection(overlay_bounds).has_area()
		):
			return false
		var expanded := local_rect.grow(FOCUS_PADDING).intersection(
			overlay_bounds
		)
		if not expanded.has_area():
			return false
		target_rects.append(expanded)
	for expanded in target_rects:
		var frame := Panel.new()
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.position = expanded.position
		frame.size = expanded.size
		frame.add_theme_stylebox_override("panel", _focus_style())
		focus_frames.add_child(frame)
	if target_rects.is_empty():
		return false
	_place_card(target_rects)
	return true

func _place_card(target_rects: Array[Rect2]) -> void:
	_restore_standard_card_layout()
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
	if _route_rail_allowed and top_overlap > 0.0 and bottom_overlap > 0.0:
		_place_route_top_rail(target_rects)
		return
	var chosen := bottom if bottom_overlap <= top_overlap else top
	_set_card_rect(Rect2(chosen, card_size))

func _place_route_top_rail(target_rects: Array[Rect2]) -> void:
	var top_clearance: float = _top_clearance(target_rects)
	if size.x <= 0.0 or top_clearance <= 0.0:
		return
	_activate_route_rail()
	margins.add_theme_constant_override("margin_left", 12)
	margins.add_theme_constant_override("margin_top", 2)
	margins.add_theme_constant_override("margin_right", 12)
	margins.add_theme_constant_override("margin_bottom", 2)
	title_label.add_theme_font_size_override("font_size", 20)
	var rail_width: float = maxf(size.x - ROUTE_RAIL_MARGIN * 2.0, 1.0)
	card.custom_minimum_size = Vector2(rail_width, 0.0)
	var rail_height: float = card.get_combined_minimum_size().y
	_set_card_rect(Rect2(
		Vector2(ROUTE_RAIL_MARGIN, ROUTE_RAIL_TOP),
		Vector2(rail_width, minf(rail_height, top_clearance - ROUTE_RAIL_TOP))
	))

func _activate_route_rail() -> void:
	if _route_rail == null:
		_route_rail = HBoxContainer.new()
		_route_rail.name = "RouteRail"
		_route_rail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_route_rail.add_theme_constant_override("separation", 14)
		_route_copy = VBoxContainer.new()
		_route_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_route_copy.add_theme_constant_override("separation", 0)
		_route_rail.add_child(_route_copy)
		margins.add_child(_route_rail)
	_move_to_parent(progress_label, _route_copy)
	_move_to_parent(title_label, _route_copy)
	_move_to_parent(instruction_label, _route_copy)
	_move_to_parent(actions, _route_rail)
	_move_to_parent(content, self)
	content.visible = false
	_route_rail.visible = true
	_route_rail_active = true

func _move_to_parent(child: Control, new_parent: Node) -> void:
	if child.get_parent() != new_parent:
		child.reparent(new_parent)

func _top_clearance(target_rects: Array[Rect2]) -> float:
	var clearance := size.y
	for target_rect in target_rects:
		clearance = min(clearance, target_rect.position.y)
	return clearance

func _set_card_rect(rect: Rect2) -> void:
	card.anchor_left = 0.0
	card.anchor_top = 0.0
	card.anchor_right = 0.0
	card.anchor_bottom = 0.0
	card.offset_left = rect.position.x
	card.offset_top = rect.position.y
	card.offset_right = rect.end.x
	card.offset_bottom = rect.end.y

func _restore_standard_card_layout() -> void:
	if not is_instance_valid(card) or not _standard_layout_captured:
		return
	if _route_rail_active:
		_move_to_parent(progress_label, content)
		_move_to_parent(title_label, content)
		_move_to_parent(instruction_label, content)
		_move_to_parent(actions, content)
		_move_to_parent(content, margins)
		margins.move_child(content, 0)
		content.move_child(progress_label, 0)
		content.move_child(title_label, 1)
		content.move_child(instruction_label, 2)
		content.move_child(warning_label, 3)
		content.move_child(actions, 4)
		content.visible = true
		_route_rail.visible = false
		_route_rail_active = false
	card.custom_minimum_size = _standard_card_minimum_size
	for margin_name in _standard_margin_constants:
		margins.add_theme_constant_override(
			margin_name,
			int(_standard_margin_constants[margin_name])
		)
	title_label.add_theme_font_size_override("font_size", _standard_title_font_size)

func _capture_standard_card_layout() -> void:
	_standard_card_minimum_size = card.custom_minimum_size
	for margin_name in [
		"margin_left",
		"margin_top",
		"margin_right",
		"margin_bottom",
	]:
		_standard_margin_constants[margin_name] = margins.get_theme_constant(
			margin_name
		)
	_standard_title_font_size = title_label.get_theme_font_size("font_size")
	_standard_layout_captured = true

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
	var overlay_global := get_global_rect()
	var target_global := _target_content_rect(target)
	return Rect2(
		target_global.position - overlay_global.position,
		target_global.size
	)

func _target_content_rect(target: Control) -> Rect2:
	if target is GridContainer:
		var child_bounds := Rect2()
		var has_child_bounds := false
		for child in target.get_children():
			var child_control := child as Control
			if (
				child_control == null
				or child_control.is_queued_for_deletion()
				or not child_control.is_inside_tree()
				or not child_control.is_visible_in_tree()
				or not child_control.get_global_rect().has_area()
			):
				continue
			if has_child_bounds:
				child_bounds = child_bounds.merge(child_control.get_global_rect())
			else:
				child_bounds = child_control.get_global_rect()
				has_child_bounds = true
		if has_child_bounds:
			return child_bounds
	return target.get_global_rect()

func _focus_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.22, 0.25, 0.12)
	style.border_color = Color(0.55, 1.0, 0.94, 1.0)
	style.set_border_width_all(4)
	style.set_corner_radius_all(10)
	return style
