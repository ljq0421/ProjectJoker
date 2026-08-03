class_name RuleArchiveScreen
extends Control

const MAIN_MENU_SCENE := "res://scenes/run/main_menu_screen.tscn"

@onready var encounter_screen: SingleEncounterScreen = %EncounterScreen
@onready var handbook_panel: RuleReferenceOverlay = %HandbookPanel
@onready var navigation_bar: Control = %NavigationBar
@onready var completion_panel: Control = %CompletionPanel
@onready var archive_title: Label = %CompletionTitle
@onready var archive_detail: Label = %CompletionDetail

var catalog := RuleArchiveCatalog.new()
var card_catalog := CardCatalog.new()
var current_definition: RuleArchiveDefinition

func _ready() -> void:
	%HomeButton.pressed.connect(_go_home)
	%BackToHandbookButton.pressed.connect(show_handbook)
	%CompletionHandbookButton.pressed.connect(show_handbook)
	%CompletionHomeButton.pressed.connect(_go_home)
	%RetryPracticeButton.pressed.connect(retry_current)
	handbook_panel.close_requested.connect(_go_home)
	handbook_panel.practice_requested.connect(start_practice)
	encounter_screen.round_committed.connect(_on_round_committed)
	var errors := catalog.validate(card_catalog)
	show_handbook()
	if not errors.is_empty():
		_show_handbook_error("规则手册内容不完整：%s" % "；".join(errors))

func start_practice(archive_id: StringName) -> bool:
	var definition := catalog.find_entry(archive_id)
	if definition == null:
		_show_handbook_error("未找到规则分类：%s" % archive_id)
		return false
	var hand := definition.resolve_hand(card_catalog)
	if hand.size() != definition.hand_ids.size():
		_show_handbook_error("规则演练所需手牌不完整")
		return false
	current_definition = definition
	_set_practice_settings_active(true)
	var session := SingleEncounterSession.new(
		definition.make_state(),
		definition.encounter,
		hand
	)
	handbook_panel.call("close_reference")
	completion_panel.visible = false
	navigation_bar.visible = true
	encounter_screen.visible = true
	encounter_screen.bind_external_session(
		session,
		"规则手册 · %s" % definition.display_name,
		"固定单轮演练 · 2 点校准 · 无奖励"
	)
	encounter_screen.bind_archive(definition)
	SfxAccess.play(self, &"page_transition")
	return true

func retry_current() -> void:
	if current_definition != null:
		start_practice(current_definition.id)

func show_handbook() -> void:
	var preferred_archive: StringName = (
		current_definition.id if current_definition != null else StringName()
	)
	encounter_screen.visible = false
	_set_practice_settings_active(false)
	navigation_bar.visible = false
	completion_panel.visible = false
	handbook_panel.call(
		"open_reference",
		[],
		true,
		preferred_archive,
		"返回主页面"
	)
	SfxAccess.play(self, &"ui_back")


func _unhandled_input(event: InputEvent) -> void:
	if not handbook_panel.visible:
		return
	var closes_handbook := event.is_action_pressed("ui_cancel")
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		var key_event := event as InputEventKey
		closes_handbook = (
			closes_handbook
			or key_event.keycode == KEY_F1
			or key_event.physical_keycode == KEY_F1
		)
	if not closes_handbook:
		return
	_go_home()
	get_viewport().set_input_as_handled()

func _on_round_committed(report: ResolutionReport) -> void:
	completion_panel.visible = true
	archive_title.text = "%s · 演练完成" % current_definition.display_name
	archive_detail.text = (
		"本轮公开得分：%d\n最终方向：%s\n"
		+ "本演练不发放情报券、刻印或地区奖励。"
	) % [
		report.total,
		(
			"从右向左"
			if report.resolution_direction
				== EncounterRuleProfile.ResolutionDirection.RIGHT_TO_LEFT
			else "从左向右"
		),
	]

func _go_home() -> void:
	SfxAccess.play(self, &"page_transition")
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _show_handbook_error(message: String) -> void:
	var hint := handbook_panel.get_node_or_null("%HandbookHint") as Label
	if hint != null:
		hint.text = message


func _set_practice_settings_active(active: bool) -> void:
	var settings_layer := encounter_screen.get_node_or_null("%SettingsLayer")
	if settings_layer == null:
		return
	settings_layer.process_mode = (
		Node.PROCESS_MODE_ALWAYS if active else Node.PROCESS_MODE_DISABLED
	)
	var settings_root := settings_layer.get_node_or_null("SettingsRoot") as Control
	if settings_root != null:
		settings_root.visible = active
