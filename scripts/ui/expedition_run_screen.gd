class_name ExpeditionRunScreen
extends Control

const MAIN_MENU_SCENE := "res://scenes/run/main_menu_screen.tscn"
const AREA_SCENES := {
	&"gold_corridor": "res://scenes/run/gold_corridor_run_screen.tscn",
	&"mirror_hall": "res://scenes/run/mirror_hall_run_screen.tscn",
	&"faceless_hub": "res://scenes/run/faceless_hub_run_screen.tscn",
}

@onready var area_host: Control = %AreaHost
@onready var error_panel: Control = %ExpeditionErrorPanel
@onready var error_label: Label = %ExpeditionErrorLabel
@onready var summary_panel: Control = %ExpeditionSummaryPanel
@onready var seed_label: Label = %ExpeditionSeedLabel
@onready var area_history_label: Label = %ExpeditionAreaHistoryLabel
@onready var final_build_label: Label = %ExpeditionFinalBuildLabel
@onready var epilogue_label: Label = %ExpeditionEpilogueLabel
@onready var return_button: Button = %ReturnFromExpeditionButton
@onready var return_from_error_button: Button = %ReturnFromErrorButton
@onready var narrative_card: Control = %NarrativeCard

var expedition := ExpeditionSession.new()
var store: ExpeditionSaveStore
var save_path := "user://expedition_save.cfg"
var current_area_screen: AreaRunScreen
var _pending_completion: Dictionary = {}

func _ready() -> void:
	return_button.pressed.connect(_on_return_from_summary)
	return_from_error_button.pressed.connect(_on_safe_exit_requested)
	narrative_card.confirmed.connect(_mount_current_area)
	narrative_card.exit_requested.connect(_on_safe_exit_requested)
	error_panel.visible = false
	summary_panel.visible = false
	var root_window := get_tree().root
	var mode: StringName = root_window.get_meta(
		"expedition_launch_mode",
		&"continue"
	)
	var seed := int(root_window.get_meta("expedition_seed", 0))
	save_path = String(root_window.get_meta(
		"expedition_save_path",
		save_path
	))
	root_window.remove_meta("expedition_launch_mode")
	root_window.remove_meta("expedition_seed")
	store = ExpeditionSaveStore.new(save_path)
	if mode == &"new":
		var cleared := store.clear()
		if not cleared.accepted:
			_show_error(cleared.reason)
			return
		var result := expedition.start_new(maxi(seed, 1))
		if not result.accepted:
			_show_error(result.reason)
			return
	else:
		var loaded := store.load_snapshot()
		if not loaded.accepted:
			_show_error(loaded.reason)
			return
		var restored := expedition.restore_snapshot(loaded.snapshot)
		if not restored.accepted:
			_show_error(restored.reason)
			return
	if expedition.status == ExpeditionSession.Status.COMPLETE:
		_show_summary()
	elif expedition.area_checkpoint.is_empty():
		var boundary_save := store.save(expedition.to_snapshot())
		if not boundary_save.accepted:
			_show_error(boundary_save.reason)
			return
		_show_area_transition()
	else:
		_mount_current_area()

func _mount_current_area() -> void:
	narrative_card.close()
	var area_id := expedition.current_area_id()
	if not AREA_SCENES.has(area_id):
		_show_error("远征当前区域不存在：%s" % area_id)
		return
	for child in area_host.get_children():
		child.queue_free()
	var packed := load(AREA_SCENES[area_id]) as PackedScene
	if packed == null:
		_show_error("无法加载远征区域：%s" % area_id)
		return
	var screen := packed.instantiate() as AreaRunScreen
	if screen == null:
		_show_error("远征区域场景类型无效：%s" % area_id)
		return
	current_area_screen = screen
	screen.expedition_checkpoint_reached.connect(_on_checkpoint_reached)
	screen.expedition_failed.connect(_on_expedition_failed)
	screen.expedition_area_completed.connect(_on_area_completed)
	screen.expedition_continue_requested.connect(_on_continue_requested)
	screen.expedition_exit_requested.connect(_on_safe_exit_requested)
	screen.configure_for_expedition(
		_area_definition(area_id),
		expedition.seed_value,
		expedition.current_entry_state(),
		expedition.area_checkpoint,
		expedition.current_area_index < ExpeditionSession.AREA_ORDER.size() - 1
	)
	area_host.add_child(screen)

func _on_checkpoint_reached(snapshot: Dictionary) -> void:
	var result := expedition.set_area_checkpoint(snapshot)
	if not result.accepted:
		_show_error(result.reason)
		return
	result = store.save(expedition.to_snapshot())
	if not result.accepted:
		_show_error(result.reason)

func _on_expedition_failed(reason: String) -> void:
	expedition.fail_run(reason if not reason.is_empty() else "区域挑战未达标")
	var cleared := store.clear()
	if not cleared.accepted:
		_show_error(cleared.reason)

func _on_area_completed(summary: Dictionary) -> void:
	_pending_completion = summary.duplicate(true)

func _on_continue_requested() -> void:
	var completion := _pending_completion.duplicate(true)
	if completion.is_empty():
		completion = expedition.area_checkpoint.get("completion", {}).duplicate(true)
	if completion.is_empty():
		_show_error("区域完成记录不存在，不能进入下一地区")
		return
	var result := expedition.complete_current_area(completion)
	if not result.accepted:
		_show_error(result.reason)
		return
	result = store.save(expedition.to_snapshot())
	if not result.accepted:
		_show_error(result.reason)
		return
	_pending_completion = {}
	if expedition.status == ExpeditionSession.Status.COMPLETE:
		_show_summary()
	else:
		_show_area_transition()

func _on_safe_exit_requested() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)

func _show_summary() -> void:
	narrative_card.close()
	for child in area_host.get_children():
		child.queue_free()
	current_area_screen = null
	summary_panel.visible = true
	seed_label.text = "远征种子｜%d" % expedition.seed_value
	var area_lines: Array[String] = []
	for index in range(expedition.completed_areas.size()):
		var completion: Dictionary = expedition.completed_areas[index]
		var dealer: Dictionary = completion.get("dealer", {})
		area_lines.append("%d. %s　庄家解析 %d / %d" % [
			index + 1,
			_area_name(completion.get("area_id", &"")),
			dealer.get("cumulative_total", 0),
			dealer.get("target_total", 0),
		])
	area_history_label.text = "\n".join(area_lines)
	var final_state := expedition.inherited_state
	var engraving_lines: Array[String] = []
	for profile in final_state.get("die_profiles", []):
		if profile.get("engraving_id", &"") != &"":
			engraving_lines.append("%s · %s · 第 %d 面" % [
				String(profile.get("id", &"")).to_upper(),
				profile.get("engraving_id", &""),
				profile.get("engraved_face", 0),
			])
	final_build_label.text = (
		"最终牌组｜%d 张\n剩余情报券｜%d\n刻印\n%s"
		% [
			final_state.get("deck_ids", []).size(),
			final_state.get("intel_tickets", 0),
			"\n".join(engraving_lines) if not engraving_lines.is_empty() else "无",
		]
	)
	epilogue_label.text = (
		"三位庄家的规则都已留下可复核的轨迹。你没有靠运气赢走筹码；"
		+ "你证明了公开规则可以被理解、预演并拆解。"
	)

func _on_return_from_summary() -> void:
	var result := store.clear()
	if not result.accepted:
		_show_error(result.reason)
		return
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)

func _show_error(message: String) -> void:
	narrative_card.close()
	error_label.text = message
	error_panel.visible = true
	error_panel.move_to_front()
	SfxAccess.play(self, &"error")

func _area_definition(area_id: StringName) -> AreaDefinition:
	var catalog := AreaCatalog.new()
	match area_id:
		&"gold_corridor":
			return catalog.gold_corridor()
		&"mirror_hall":
			return catalog.mirror_hall()
		&"faceless_hub":
			return catalog.faceless_hub()
	return null

func _area_name(area_id: StringName) -> String:
	var definition := _area_definition(area_id)
	return String(area_id) if definition == null else definition.display_name

func _show_area_transition() -> void:
	summary_panel.visible = false
	for child in area_host.get_children():
		child.queue_free()
	current_area_screen = null
	var area := _area_definition(expedition.current_area_id())
	if not narrative_card.show_area_transition(
		area,
		expedition.current_entry_state(),
		_accessibility_snapshot()
	):
		_show_error("远征区域叙事无法显示")

func _accessibility_snapshot() -> Dictionary:
	var service := get_tree().root.get_node_or_null("SettingsService")
	if service == null or not service.has_method("settings_snapshot"):
		return {}
	var settings: Dictionary = service.settings_snapshot()
	return settings.get("accessibility", {}).duplicate(true)
