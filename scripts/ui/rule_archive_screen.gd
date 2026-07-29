class_name RuleArchiveScreen
extends Control

const MAIN_MENU_SCENE := "res://scenes/run/main_menu_screen.tscn"

@onready var encounter_screen: SingleEncounterScreen = %EncounterScreen
@onready var selection_panel: Control = %SelectionPanel
@onready var navigation_bar: Control = %NavigationBar
@onready var completion_panel: Control = %CompletionPanel
@onready var archive_title: Label = %CompletionTitle
@onready var archive_detail: Label = %CompletionDetail

var catalog := RuleArchiveCatalog.new()
var card_catalog := CardCatalog.new()
var current_definition: RuleArchiveDefinition

func _ready() -> void:
	%HomeButton.pressed.connect(_go_home)
	%SelectionHomeButton.pressed.connect(_go_home)
	%BackToArchiveButton.pressed.connect(show_archive)
	%CompletionArchiveButton.pressed.connect(show_archive)
	%CompletionHomeButton.pressed.connect(_go_home)
	%RetryArchiveButton.pressed.connect(retry_current)
	encounter_screen.round_committed.connect(_on_round_committed)
	var buttons: Array[Button] = [
		%Archive01Button,
		%Archive02Button,
		%Archive03Button,
		%Archive04Button,
		%Archive05Button,
		%Archive06Button,
	]
	var entries := catalog.all_entries()
	for index in range(mini(buttons.size(), entries.size())):
		var entry: RuleArchiveDefinition = entries[index]
		buttons[index].text = "%s\n%s\n%s" % [
			entry.display_name,
			entry.group_label,
			entry.summary,
		]
		buttons[index].pressed.connect(open_archive.bind(entry.id))
	var errors := catalog.validate(card_catalog)
	if not errors.is_empty():
		%ArchiveErrorLabel.text = "\n".join(errors)
	show_archive()

func open_archive(archive_id: StringName) -> bool:
	var definition := catalog.find_entry(archive_id)
	if definition == null:
		%ArchiveErrorLabel.text = "未找到规则档案：%s" % archive_id
		return false
	var hand := definition.resolve_hand(card_catalog)
	if hand.size() != definition.hand_ids.size():
		%ArchiveErrorLabel.text = "规则档案手牌资源不完整"
		return false
	current_definition = definition
	var session := SingleEncounterSession.new(
		definition.make_state(),
		definition.encounter,
		hand
	)
	selection_panel.visible = false
	completion_panel.visible = false
	navigation_bar.visible = true
	encounter_screen.visible = true
	encounter_screen.bind_external_session(
		session,
		"规则档案室 · %s" % definition.display_name,
		"单轮固定练习 · 2 点校准 · 无奖励"
	)
	encounter_screen.bind_archive(definition)
	SfxAccess.play(self, &"page_transition")
	return true

func retry_current() -> void:
	if current_definition != null:
		open_archive(current_definition.id)

func show_archive() -> void:
	current_definition = null
	encounter_screen.visible = false
	navigation_bar.visible = false
	completion_panel.visible = false
	selection_panel.visible = true
	SfxAccess.play(self, &"ui_back")

func _on_round_committed(report: ResolutionReport) -> void:
	completion_panel.visible = true
	archive_title.text = "%s · 练习完成" % current_definition.display_name
	archive_detail.text = (
		"本轮公开得分：%d\n最终方向：%s\n"
		+ "本练习不发放情报券、刻印或地区奖励。"
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
