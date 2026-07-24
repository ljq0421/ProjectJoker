class_name SingleEncounterTutorial
extends Control

signal persistence_warning(message: String)

@onready var dimmer: ColorRect = %TutorialDimmer
@onready var focus_rings: Control = %FocusRings
@onready var callout: PanelContainer = %TutorialCallout
@onready var title_label: Label = %TutorialTitle
@onready var instruction_label: Label = %TutorialInstruction
@onready var progress_label: Label = %TutorialProgress
@onready var warning_label: Label = %TutorialWarning
@onready var continue_button: Button = %TutorialContinueButton
@onready var skip_button: Button = %TutorialSkipButton
@onready var finish_button: Button = %TutorialFinishButton

var screen: SingleEncounterScreen
var progress_store: TutorialProgressStore
var flow := SingleEncounterTutorialFlow.new()
var active: bool = false

func _ready() -> void:
	visible = false
	continue_button.pressed.connect(_on_continue_pressed)
	skip_button.pressed.connect(_on_skip_pressed)
	finish_button.pressed.connect(_on_finish_pressed)

func configure(
	p_screen: SingleEncounterScreen,
	p_progress_store: TutorialProgressStore
) -> void:
	screen = p_screen
	progress_store = p_progress_store
	screen.view_refreshed.connect(refresh_targets)
	screen.ui_action_accepted.connect(record_accepted_action)

func maybe_start() -> void:
	if progress_store != null and not progress_store.is_done():
		start(false)

func start(replay: bool = false) -> void:
	if replay:
		_show_save_error(progress_store.reset())
		screen.reset_teaching_encounter()
	flow.start()
	active = true
	visible = true
	_refresh()

func allows(action: StringName, payload: Dictionary) -> bool:
	if not active:
		return true
	var accepted := flow.allows(action, payload, screen.session)
	if not accepted:
		_refresh()
	return accepted

func record_accepted_action(action: StringName, payload: Dictionary) -> void:
	if not active:
		return
	flow.record_accepted_action(action, payload, screen.session)
	_refresh()

func refresh_targets() -> void:
	if active:
		call_deferred("_rebuild_focus_rings")

func _refresh() -> void:
	title_label.text = _step_title(flow.step_index)
	instruction_label.text = flow.instruction(screen.session)
	progress_label.text = "%d / 11" % (flow.step_index + 1)
	continue_button.visible = flow.step_index in [0, 6]
	finish_button.visible = flow.step_index == 10
	call_deferred("_rebuild_focus_rings")

func _rebuild_focus_rings() -> void:
	if not active or not is_inside_tree():
		return
	for child in focus_rings.get_children():
		child.free()

	var target_rects: Array[Rect2] = []
	for spec in flow.target_specs(screen.session):
		var target: Control = screen.find_tutorial_target(spec)
		if target == null:
			push_error("Tutorial target missing: %s" % spec)
			continue
		var target_rect: Rect2 = target.get_global_rect()
		target_rects.append(target_rect)
		var ring := Panel.new()
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ring.position = target_rect.position - global_position - Vector2(5, 5)
		ring.size = target_rect.size + Vector2(10, 10)
		ring.add_theme_stylebox_override("panel", _focus_style())
		focus_rings.add_child(ring)
	_place_callout(target_rects)

func _place_callout(target_rects: Array[Rect2]) -> void:
	var viewport_size := size
	var callout_size := callout.size
	var candidates: Array[Vector2] = [
		Vector2(32, 32),
		Vector2(viewport_size.x - callout_size.x - 32, 32),
		Vector2(32, viewport_size.y - callout_size.y - 32),
		Vector2(
			viewport_size.x - callout_size.x - 32,
			viewport_size.y - callout_size.y - 32
		),
	]
	var best: Vector2 = candidates[0]
	var best_overlap := INF
	for candidate in candidates:
		var candidate_rect := Rect2(candidate + global_position, callout_size)
		var overlap := 0.0
		for target_rect in target_rects:
			var intersection := candidate_rect.intersection(target_rect)
			overlap += intersection.size.x * intersection.size.y
		if overlap < best_overlap:
			best_overlap = overlap
			best = candidate
	callout.position = best

func _focus_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.22, 0.25, 0.12)
	style.border_color = Color(0.55, 1.0, 0.94, 1.0)
	style.set_border_width_all(4)
	style.set_corner_radius_all(10)
	return style

func _step_title(index: int) -> String:
	var titles := [
		"三轨解析", "拖动骰子", "点击分配", "连续三数", "校准骰子",
		"修改规则", "读取预测", "撤销方案", "重新用牌", "确认结算", "教学完成",
	]
	return titles[index]

func _on_continue_pressed() -> void:
	flow.continue_step(screen.session)
	_refresh()

func _on_skip_pressed() -> void:
	_show_save_error(progress_store.mark_done())
	active = false
	visible = false

func _on_finish_pressed() -> void:
	if not flow.can_finish(screen.session):
		return
	_show_save_error(progress_store.mark_done())
	active = false
	visible = false

func _show_save_error(error: Error) -> void:
	warning_label.text = "" if error == OK else "无法保存引导状态；下次启动会再次显示。"
	if error != OK:
		persistence_warning.emit(warning_label.text)
