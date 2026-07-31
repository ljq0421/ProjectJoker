class_name MainMenuScreen
extends Control

const PRACTICE_SCENE := "res://scenes/run/single_encounter_screen.tscn"
const GOLD_CORRIDOR_SCENE := "res://scenes/run/gold_corridor_run_screen.tscn"
const MIRROR_HALL_SCENE := "res://scenes/run/mirror_hall_run_screen.tscn"
const FACELESS_HUB_SCENE := "res://scenes/run/faceless_hub_run_screen.tscn"
const RULE_ARCHIVE_SCENE := "res://scenes/run/rule_archive_screen.tscn"
const EXPEDITION_SCENE := "res://scenes/run/expedition_run_screen.tscn"
const EXPEDITION_SETUP_SCENE := "res://scenes/run/expedition_setup_screen.tscn"

@onready var practice_button: Button = %PracticeButton
@onready var gold_corridor_button: Button = %GoldCorridorButton
@onready var mirror_hall_button: Button = %MirrorHallButton
@onready var faceless_hub_button: Button = %FacelessHubButton
@onready var rule_archive_button: Button = %RuleArchiveButton
@onready var start_expedition_button: Button = %StartExpeditionButton
@onready var continue_expedition_button: Button = %ContinueExpeditionButton
@onready var abandon_expedition_button: Button = %AbandonExpeditionButton
@onready var expedition_status_label: Label = %ExpeditionStatusLabel
@onready var abandon_expedition_dialog: ConfirmationDialog = %AbandonExpeditionDialog
@onready var new_expedition_dialog: ConfirmationDialog = %NewExpeditionDialog

var expedition_store: ExpeditionSaveStore
var expedition_save_path := "user://expedition_save.cfg"

func _ready() -> void:
	var root_window := get_tree().root
	if root_window.has_meta("expedition_save_path"):
		expedition_save_path = String(
			root_window.get_meta("expedition_save_path")
		)
	expedition_store = ExpeditionSaveStore.new(expedition_save_path)
	start_expedition_button.pressed.connect(_on_start_expedition_pressed)
	continue_expedition_button.pressed.connect(_on_continue_expedition_pressed)
	abandon_expedition_button.pressed.connect(
		func() -> void: abandon_expedition_dialog.popup_centered()
	)
	abandon_expedition_dialog.confirmed.connect(_on_abandon_confirmed)
	new_expedition_dialog.confirmed.connect(_launch_new_expedition)
	practice_button.pressed.connect(func() -> void: _open_scene(PRACTICE_SCENE))
	gold_corridor_button.pressed.connect(
		func() -> void: _open_scene(GOLD_CORRIDOR_SCENE)
	)
	mirror_hall_button.pressed.connect(
		func() -> void: _open_scene(MIRROR_HALL_SCENE)
	)
	faceless_hub_button.pressed.connect(
		func() -> void: _open_scene(FACELESS_HUB_SCENE)
	)
	rule_archive_button.pressed.connect(
		func() -> void: _open_scene(RULE_ARCHIVE_SCENE)
	)
	_refresh_expedition_status()

func _open_scene(scene_path: String) -> void:
	SfxAccess.play(self, &"page_transition")
	get_tree().change_scene_to_file(scene_path)

func _on_start_expedition_pressed() -> void:
	if expedition_store.has_save():
		new_expedition_dialog.popup_centered()
		return
	_launch_new_expedition()

func _launch_new_expedition() -> void:
	_open_scene(EXPEDITION_SETUP_SCENE)

func _on_continue_expedition_pressed() -> void:
	var loaded := expedition_store.load_snapshot()
	if not loaded.accepted:
		expedition_status_label.text = loaded.reason
		_refresh_expedition_status()
		return
	if loaded.snapshot["status"] == ExpeditionSession.Status.COMPLETE:
		_launch_expedition(&"continue", 0)
		return
	if loaded.snapshot["status"] != ExpeditionSession.Status.ACTIVE:
		expedition_status_label.text = "该远征已经结束，不能继续"
		continue_expedition_button.disabled = true
		return
	_launch_expedition(&"continue", 0)

func _launch_expedition(mode: StringName, seed: int) -> void:
	var root_window := get_tree().root
	root_window.set_meta("expedition_launch_mode", mode)
	root_window.set_meta("expedition_seed", seed)
	root_window.set_meta("expedition_save_path", expedition_save_path)
	_open_scene(EXPEDITION_SCENE)

func _on_abandon_confirmed() -> void:
	var result := expedition_store.clear()
	expedition_status_label.text = (
		"远征记录已清除"
		if result.accepted
		else result.reason
	)
	_refresh_expedition_status()

func _refresh_expedition_status() -> void:
	var has_save := expedition_store.has_save()
	continue_expedition_button.disabled = not has_save
	abandon_expedition_button.disabled = not has_save
	if not has_save:
		expedition_status_label.text = "没有进行中的远征"
		continue_expedition_button.text = "继续远征"
		return
	var loaded := expedition_store.load_snapshot()
	if not loaded.accepted:
		expedition_status_label.text = loaded.reason
		continue_expedition_button.disabled = true
		return
	var snapshot: Dictionary = loaded.snapshot
	if snapshot["status"] == ExpeditionSession.Status.COMPLETE:
		expedition_status_label.text = "远征已完成，可查看最终总结"
		continue_expedition_button.text = "查看远征总结"
		return
	if snapshot["status"] != ExpeditionSession.Status.ACTIVE:
		expedition_status_label.text = "远征已经结束"
		continue_expedition_button.disabled = true
		return
	var area_index: int = snapshot["current_area_index"]
	expedition_status_label.text = "可继续：%s · 种子 %d" % [
		_area_name(ExpeditionSession.AREA_ORDER[area_index]),
		snapshot["seed_value"],
	]
	continue_expedition_button.text = "继续远征"

func _area_name(area_id: StringName) -> String:
	match area_id:
		&"gold_corridor":
			return "金线回廊"
		&"mirror_hall":
			return "反照牌厅"
		&"faceless_hub":
			return "无面中枢"
	return String(area_id)
