class_name MainMenuScreen
extends Control

const PRACTICE_SCENE := "res://scenes/run/single_encounter_screen.tscn"
const GOLD_CORRIDOR_SCENE := "res://scenes/run/gold_corridor_run_screen.tscn"
const MIRROR_HALL_SCENE := "res://scenes/run/mirror_hall_run_screen.tscn"
const FACELESS_HUB_SCENE := "res://scenes/run/faceless_hub_run_screen.tscn"
const RULE_ARCHIVE_SCENE := "res://scenes/run/rule_archive_screen.tscn"

@onready var practice_button: Button = %PracticeButton
@onready var gold_corridor_button: Button = %GoldCorridorButton
@onready var mirror_hall_button: Button = %MirrorHallButton
@onready var faceless_hub_button: Button = %FacelessHubButton
@onready var rule_archive_button: Button = %RuleArchiveButton

func _ready() -> void:
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

func _open_scene(scene_path: String) -> void:
	SfxAccess.play(self, &"page_transition")
	get_tree().change_scene_to_file(scene_path)
