class_name MainMenuScreen
extends Control

const PRACTICE_SCENE := "res://scenes/run/single_encounter_screen.tscn"
const DICE_FIRST_PROTOTYPE_SCENE := "res://scenes/run/dice_first_prototype_screen.tscn"
const GOLD_CORRIDOR_SCENE := "res://scenes/run/gold_corridor_run_screen.tscn"
const MIRROR_HALL_SCENE := "res://scenes/run/mirror_hall_run_screen.tscn"
const FACELESS_HUB_SCENE := "res://scenes/run/faceless_hub_run_screen.tscn"
const RULE_HANDBOOK_SCENE := "res://scenes/run/rule_archive_screen.tscn"
const EXPEDITION_SCENE := "res://scenes/run/expedition_run_screen.tscn"
const EXPEDITION_SETUP_SCENE := "res://scenes/run/expedition_setup_screen.tscn"
const CUSTOM_SETUP_SCENE := "res://scenes/run/custom_expedition_setup_screen.tscn"
const ACHIEVEMENT_ARCHIVE_SCENE := "res://scenes/run/achievement_archive_screen.tscn"
const TUTORIAL_CONFIG_META := "tutorial_config_path"
const TUTORIAL_NEXT_SCENE_META := "tutorial_next_scene"
const DemoProfile := preload("res://scripts/run/demo_build_profile.gd")
const DailyService = preload("res://scripts/run/daily_challenge_service.gd")
const StartConfig = preload("res://scripts/run/expedition_start_config.gd")

@export_enum("Auto:-1", "Full:0", "Demo:1") var demo_scope_override := -1

@onready var tutorial_button: Button = %TutorialButton
@onready var practice_button: Button = %PracticeButton
@onready var dice_first_prototype_button: Button = %DiceFirstPrototypeButton
@onready var gold_corridor_button: Button = %GoldCorridorButton
@onready var mirror_hall_button: Button = %MirrorHallButton
@onready var faceless_hub_button: Button = %FacelessHubButton
@onready var rule_handbook_button: Button = %RuleHandbookButton
@onready var start_expedition_button: Button = %StartExpeditionButton
@onready var continue_expedition_button: Button = %ContinueExpeditionButton
@onready var abandon_expedition_button: Button = %AbandonExpeditionButton
@onready var expedition_status_label: Label = %ExpeditionStatusLabel
@onready var daily_challenge_button: Button = %DailyChallengeButton
@onready var custom_expedition_button: Button = %CustomExpeditionButton
@onready var achievement_archive_button: Button = %AchievementArchiveButton
@onready var abandon_expedition_dialog: ConfirmationDialog = %AbandonExpeditionDialog
@onready var new_expedition_dialog: ConfirmationDialog = %NewExpeditionDialog
@onready var credits_button: Button = %CreditsButton
@onready var quit_button: Button = %QuitButton
@onready var version_label: Label = %VersionLabel
@onready var credits_overlay: Control = %CreditsOverlay
@onready var credits_text: TextEdit = %CreditsText
@onready var close_credits_button: Button = %CloseCreditsButton
@onready var quit_game_dialog: ConfirmationDialog = %QuitGameDialog
@onready var practice_routes_header: Control = %PracticeRoutesHeader
@onready var route_grid: Control = %RouteGrid
@onready var practice_row: Control = %PracticeRow
@onready var practice_hint: Label = %PracticeHint
@onready var content: VBoxContainer = $SafeArea/Content
@onready var demo_journey_panel: Control = %DemoJourneyPanel

var expedition_store: ExpeditionSaveStore
var expedition_save_path := "user://expedition_save.cfg"
var daily_save_path := "user://daily_expedition_save.cfg"
var custom_save_path := "user://custom_expedition_save.cfg"
var meta_path := "user://expedition_meta.cfg"
var custom_meta_path := "user://custom_expedition_meta.cfg"
var daily_leaderboard_path := "user://daily_leaderboard.cfg"
var tutorial_config_path := "user://onboarding.cfg"
var _is_demo_build := false

func _ready() -> void:
	var root_window := get_tree().root
	if root_window.has_meta("standard_expedition_save_path"):
		expedition_save_path = String(
			root_window.get_meta("standard_expedition_save_path")
		)
	elif root_window.has_meta("expedition_save_path"):
		expedition_save_path = String(
			root_window.get_meta("expedition_save_path")
		)
	meta_path = String(root_window.get_meta(
		"standard_expedition_meta_path",
		root_window.get_meta("expedition_meta_path", meta_path)
	))
	daily_save_path = String(root_window.get_meta("daily_expedition_save_path", daily_save_path))
	custom_save_path = String(root_window.get_meta("custom_expedition_save_path", custom_save_path))
	custom_meta_path = String(root_window.get_meta("custom_expedition_meta_path", custom_meta_path))
	daily_leaderboard_path = String(root_window.get_meta("daily_leaderboard_path", daily_leaderboard_path))
	if root_window.has_meta(TUTORIAL_CONFIG_META):
		tutorial_config_path = String(root_window.get_meta(TUTORIAL_CONFIG_META))
	expedition_store = ExpeditionSaveStore.new(expedition_save_path)
	tutorial_button.pressed.connect(_on_tutorial_pressed)
	start_expedition_button.pressed.connect(_on_start_expedition_pressed)
	continue_expedition_button.pressed.connect(_on_continue_expedition_pressed)
	abandon_expedition_button.pressed.connect(
		func() -> void: abandon_expedition_dialog.popup_centered()
	)
	abandon_expedition_dialog.confirmed.connect(_on_abandon_confirmed)
	new_expedition_dialog.confirmed.connect(_launch_new_expedition)
	daily_challenge_button.pressed.connect(_on_daily_challenge_pressed)
	custom_expedition_button.pressed.connect(_on_custom_expedition_pressed)
	achievement_archive_button.pressed.connect(
		func() -> void:
			get_tree().root.set_meta("expedition_meta_path", meta_path)
			get_tree().root.set_meta("standard_expedition_meta_path", meta_path)
			_open_scene(ACHIEVEMENT_ARCHIVE_SCENE)
	)
	credits_button.pressed.connect(_on_credits_pressed)
	close_credits_button.pressed.connect(_on_close_credits_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	quit_game_dialog.confirmed.connect(_on_quit_confirmed)
	practice_button.pressed.connect(func() -> void: _open_scene(PRACTICE_SCENE))
	dice_first_prototype_button.pressed.connect(
		func() -> void: _open_scene(DICE_FIRST_PROTOTYPE_SCENE)
	)
	gold_corridor_button.pressed.connect(
		func() -> void: _open_scene(GOLD_CORRIDOR_SCENE)
	)
	mirror_hall_button.pressed.connect(
		func() -> void: _open_scene(MIRROR_HALL_SCENE)
	)
	faceless_hub_button.pressed.connect(
		func() -> void: _open_scene(FACELESS_HUB_SCENE)
	)
	rule_handbook_button.pressed.connect(
		func() -> void: _open_scene(RULE_HANDBOOK_SCENE)
	)
	_apply_build_scope()
	_run_release_smoke_probe_if_requested()
	_refresh_tutorial_entry()
	_refresh_expedition_status()
	_refresh_extended_modes()
	_refresh_release_identity()

func _apply_build_scope() -> void:
	var profile := DemoProfile.new()
	var is_demo := profile.is_demo_build(demo_scope_override)
	_is_demo_build = is_demo
	var access := profile.main_menu_access(demo_scope_override)
	demo_journey_panel.visible = is_demo
	practice_routes_header.visible = bool(access["region_practice"])
	route_grid.visible = bool(access["region_practice"])
	rule_handbook_button.visible = bool(access["developer_practice"])
	practice_button.visible = bool(access["developer_practice"])
	dice_first_prototype_button.visible = bool(access["developer_practice"])
	tutorial_button.visible = bool(access["tutorial"])
	practice_row.visible = (
		tutorial_button.visible
		or rule_handbook_button.visible
		or practice_button.visible
		or dice_first_prototype_button.visible
	)
	practice_hint.text = (
		"想重温基础操作？"
		if is_demo
		else "想先熟悉基础结算？"
	)
	content.alignment = (
		BoxContainer.ALIGNMENT_CENTER
		if is_demo
		else BoxContainer.ALIGNMENT_BEGIN
	)

func _run_release_smoke_probe_if_requested() -> void:
	if "--release-smoke-test" not in OS.get_cmdline_user_args():
		return
	var release_files_present := FileAccess.file_exists(
		"res://release/steam_demo/store_assets_manifest.json"
	)
	print(
		"RELEASE_SMOKE demo=%s release_files=%s"
		% [_is_demo_build, release_files_present]
	)

func _unhandled_input(event: InputEvent) -> void:
	if (
		credits_overlay.visible
		and event is InputEventKey
		and event.pressed
		and not event.echo
		and event.keycode == KEY_ESCAPE
	):
		_on_close_credits_pressed()
		get_viewport().set_input_as_handled()

func _refresh_release_identity() -> void:
	var version := String(
		ProjectSettings.get_setting("application/config/version", "unversioned")
	)
	version_label.text = "Demo v%s" % version
	credits_text.text = _build_credits_text(version)

func _build_credits_text(version: String) -> String:
	var sections: Array[String] = [
		(
			"《六面诡局》 Steam Demo\n"
			+ "版本：%s\n" % version
			+ "制作：独立开发版本 · 开发者暂不公开\n\n"
			+ "游戏设计、程序、美术界面与文字为本项目内容。\n"
			+ "音乐与音效由项目内确定性生成工具合成，不含第三方采样、"
			+ "录音、循环素材或外部音乐库。"
		),
		(
			"Godot Engine\n"
			+ "This game uses Godot Engine.\n"
			+ "Copyright (c) 2014-present Godot Engine contributors.\n"
			+ "Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur.\n\n"
			+ Engine.get_license_text()
		),
	]
	var license_info := Engine.get_license_info()
	var license_names: Array[String] = []
	for license_name in license_info.keys():
		license_names.append(String(license_name))
	license_names.sort()
	var bundled_sections: Array[String] = [
		"Godot bundled third-party license texts"
	]
	for license_name in license_names:
		bundled_sections.append(
			"[%s]\n%s" % [license_name, String(license_info[license_name])]
		)
	sections.append("\n\n".join(bundled_sections))
	return "\n\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n".join(sections)

func _on_credits_pressed() -> void:
	credits_overlay.visible = true
	credits_text.scroll_vertical = 0
	close_credits_button.grab_focus()
	SfxAccess.play(self, &"panel_open")

func _on_close_credits_pressed() -> void:
	credits_overlay.visible = false
	credits_button.grab_focus()
	SfxAccess.play(self, &"ui_back")

func _on_quit_pressed() -> void:
	quit_game_dialog.popup_centered()
	SfxAccess.play(self, &"panel_open")

func _on_quit_confirmed() -> void:
	get_tree().quit()

func _open_scene(scene_path: String) -> void:
	SfxAccess.play(self, &"page_transition")
	get_tree().change_scene_to_file(scene_path)

func _on_start_expedition_pressed() -> void:
	if expedition_store.has_save():
		new_expedition_dialog.popup_centered()
		return
	_launch_new_expedition()

func _launch_new_expedition() -> void:
	if not TutorialProgressStore.new(tutorial_config_path).is_done():
		_open_tutorial_before(EXPEDITION_SETUP_SCENE)
		return
	_open_scene(EXPEDITION_SETUP_SCENE)

func _on_tutorial_pressed() -> void:
	var result := TutorialProgressStore.new(tutorial_config_path).reset()
	if result != OK:
		expedition_status_label.text = "无法重置新手引导，请检查存档目录。"
		SfxAccess.play(self, &"error")
		return
	_open_tutorial_before("res://scenes/run/main_menu_screen.tscn")

func _open_tutorial_before(next_scene: String) -> void:
	var root_window := get_tree().root
	root_window.set_meta(TUTORIAL_CONFIG_META, tutorial_config_path)
	root_window.set_meta(TUTORIAL_NEXT_SCENE_META, next_scene)
	_open_scene(PRACTICE_SCENE)

func _refresh_tutorial_entry() -> void:
	var completed := TutorialProgressStore.new(tutorial_config_path).is_done()
	tutorial_button.text = "重播新手引导" if completed else "开始新手引导"

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
	root_window.set_meta("standard_expedition_save_path", expedition_save_path)
	root_window.set_meta("expedition_meta_path", meta_path)
	root_window.set_meta("standard_expedition_meta_path", meta_path)
	_open_scene(EXPEDITION_SCENE)

func _refresh_extended_modes() -> void:
	var loaded := ExpeditionMetaStore.new(meta_path).load_snapshot()
	var unlocked := loaded.accepted and bool(loaded.snapshot.get("challenges_unlocked", false))
	for button in [daily_challenge_button, custom_expedition_button]:
		button.disabled = not unlocked
		button.tooltip_text = (
			""
			if unlocked
			else "首次完成标准三区远征后开放"
		)
	daily_challenge_button.text = (
		"继续每日挑战"
		if unlocked and ExpeditionSaveStore.new(daily_save_path).has_save()
		else "每日挑战"
	)
	custom_expedition_button.text = (
		"继续 / 配置自定义"
		if unlocked and ExpeditionSaveStore.new(custom_save_path).has_save()
		else "自定义远征"
	)
	achievement_archive_button.tooltip_text = (
		"查看已解锁称号、徽章与自定义装饰"
		if loaded.accepted
		else loaded.reason
	)

func _on_daily_challenge_pressed() -> void:
	var store := ExpeditionSaveStore.new(daily_save_path)
	if store.has_save():
		_launch_extended_expedition(&"continue", {}, daily_save_path, meta_path)
		return
	var config = DailyService.new().config_for(DailyService.new().local_date_key())
	if config == null:
		expedition_status_label.text = "无法生成今日挑战配置"
		return
	_launch_extended_expedition(&"new", config.to_snapshot(), daily_save_path, meta_path)

func _on_custom_expedition_pressed() -> void:
	var root_window := get_tree().root
	root_window.set_meta("custom_expedition_save_path", custom_save_path)
	root_window.set_meta("custom_expedition_meta_path", custom_meta_path)
	root_window.set_meta("expedition_meta_path", meta_path)
	root_window.set_meta("standard_expedition_meta_path", meta_path)
	root_window.set_meta("standard_expedition_save_path", expedition_save_path)
	_open_scene(CUSTOM_SETUP_SCENE)

func _launch_extended_expedition(
	launch_mode: StringName,
	config_snapshot: Dictionary,
	save_file: String,
	progress_file: String
) -> void:
	var root_window := get_tree().root
	root_window.set_meta("expedition_launch_mode", launch_mode)
	root_window.set_meta("expedition_start_config", config_snapshot.duplicate(true))
	root_window.set_meta("expedition_save_path", save_file)
	root_window.set_meta("expedition_meta_path", progress_file)
	root_window.set_meta("standard_expedition_meta_path", meta_path)
	root_window.set_meta("standard_expedition_save_path", expedition_save_path)
	root_window.set_meta("daily_leaderboard_path", daily_leaderboard_path)
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
		expedition_status_label.text = (
			"从金线回廊出发，连续完成三个区域；"
			+ "进度会在区域边界自动保存。"
		)
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
