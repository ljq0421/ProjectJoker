class_name AchievementArchiveScreen
extends Control

const MAIN_MENU := "res://scenes/run/main_menu_screen.tscn"
const Achievements = preload("res://scripts/run/achievement_catalog.gd")

@onready var list: VBoxContainer = %AchievementList
@onready var summary: Label = %ArchiveSummary
@onready var error_label: Label = %ArchiveError
@onready var return_button: Button = %ReturnButton

func _ready() -> void:
	return_button.pressed.connect(func() -> void: get_tree().change_scene_to_file(MAIN_MENU))
	var path := String(get_tree().root.get_meta(
		"expedition_meta_path", "user://expedition_meta.cfg"
	))
	var loaded := ExpeditionMetaStore.new(path).load_snapshot()
	if not loaded.accepted:
		error_label.text = loaded.reason
		return
	var unlocked := 0
	for definition in Achievements.new().all():
		var achieved := bool(loaded.snapshot.achievements[definition.id])
		if achieved:
			unlocked += 1
		var card := Button.new()
		card.disabled = true
		card.custom_minimum_size = Vector2(0, 58)
		card.text = "%s　%s｜%s" % [
			"已解锁" if achieved else "未解锁",
			definition.title,
			definition.description,
		]
		card.tooltip_text = "同时解锁同名档案徽章与自定义边框" if achieved else definition.description
		list.add_child(card)
	summary.text = "档案完成度｜%d / %d　奖励仅为称号、徽章与自定义装饰，不提供战力。" % [
		unlocked, Achievements.new().ids().size(),
	]
