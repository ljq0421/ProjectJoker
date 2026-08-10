class_name CustomExpeditionSetupScreen
extends Control

const MAIN_MENU := "res://scenes/run/main_menu_screen.tscn"
const RUN_SCENE := "res://scenes/run/expedition_run_screen.tscn"
const StartConfig = preload("res://scripts/run/expedition_start_config.gd")
const Configs = preload("res://scripts/run/expedition_config_catalog.gd")
const Modifiers = preload("res://scripts/run/area_run_modifier_catalog.gd")
const Achievements = preload("res://scripts/run/achievement_catalog.gd")

@onready var deck_option: OptionButton = %DeckOption
@onready var area_count_option: OptionButton = %AreaCountOption
@onready var target_option: OptionButton = %TargetMultiplierOption
@onready var decoration_option: OptionButton = %DecorationOption
@onready var challenge_list: VBoxContainer = %CustomChallengeList
@onready var modifier_list: VBoxContainer = %CustomModifierList
@onready var summary_label: Label = %CustomSetupSummary
@onready var error_label: Label = %CustomSetupError
@onready var continue_button: Button = %ContinueCustomButton
@onready var start_button: Button = %StartCustomButton
@onready var return_button: Button = %ReturnButton

var save_path := "user://custom_expedition_save.cfg"
var custom_meta_path := "user://custom_expedition_meta.cfg"
var standard_meta_path := "user://expedition_meta.cfg"
var selected_challenges: Array[StringName] = []
var selected_modifiers: Dictionary = {}
var modifier_buttons: Dictionary = {}

func _ready() -> void:
	var root := get_tree().root
	save_path = String(root.get_meta("custom_expedition_save_path", save_path))
	custom_meta_path = String(root.get_meta("custom_expedition_meta_path", custom_meta_path))
	standard_meta_path = String(root.get_meta("expedition_meta_path", standard_meta_path))
	root.set_meta("standard_expedition_meta_path", standard_meta_path)
	_build_primary_options()
	_build_challenges()
	_build_modifiers()
	_build_decorations()
	area_count_option.item_selected.connect(func(_index: int) -> void: _refresh())
	deck_option.item_selected.connect(func(_index: int) -> void: _refresh())
	target_option.item_selected.connect(func(_index: int) -> void: _refresh())
	decoration_option.item_selected.connect(func(_index: int) -> void: _refresh())
	continue_button.pressed.connect(_continue_saved)
	start_button.pressed.connect(_start_custom)
	return_button.pressed.connect(func() -> void: get_tree().change_scene_to_file(MAIN_MENU))
	continue_button.disabled = not ExpeditionSaveStore.new(save_path).has_save()
	_refresh()

func _build_primary_options() -> void:
	for deck in Configs.new().all_decks():
		deck_option.add_item(deck.display_name)
		deck_option.set_item_metadata(deck_option.item_count - 1, deck.id)
	for count in range(1, 4):
		area_count_option.add_item("%d 区｜%s" % [count, " → ".join(
			["金线", "反照", "无面"].slice(0, count)
		)])
		area_count_option.set_item_metadata(area_count_option.item_count - 1, count)
	for multiplier in StartConfig.TARGET_MULTIPLIERS:
		target_option.add_item("%d%%" % int(multiplier * 100.0))
		target_option.set_item_metadata(target_option.item_count - 1, multiplier)
	target_option.select(1)

func _build_challenges() -> void:
	for definition in Configs.new().all_challenges():
		var button := CheckButton.new()
		button.text = "%s｜%s" % [definition.display_name, definition.description]
		button.toggled.connect(_toggle_challenge.bind(definition.id))
		challenge_list.add_child(button)

func _build_modifiers() -> void:
	for area_id in StartConfig.STANDARD_AREAS:
		selected_modifiers[area_id] = []
		var title := Label.new()
		title.text = _area_name(area_id)
		modifier_list.add_child(title)
		for modifier_id in Modifiers.new().ids_for_area(area_id):
			var definition := Modifiers.new().find(modifier_id)
			var button := CheckButton.new()
			button.text = "%s｜%s" % [definition.display_name, definition.description]
			button.set_meta("area_id", area_id)
			button.toggled.connect(_toggle_modifier.bind(area_id, modifier_id, button))
			modifier_list.add_child(button)
			modifier_buttons[modifier_id] = button

func _build_decorations() -> void:
	decoration_option.add_item("标准契据")
	decoration_option.set_item_metadata(0, &"")
	var loaded := ExpeditionMetaStore.new(standard_meta_path).load_snapshot()
	if not loaded.accepted:
		return
	for achievement_id in loaded.snapshot.unlocked_cosmetics:
		var definition := Achievements.new().find(achievement_id)
		if definition.is_empty():
			continue
		decoration_option.add_item("%s · 徽章边框" % definition.title)
		decoration_option.set_item_metadata(decoration_option.item_count - 1, achievement_id)

func _toggle_challenge(enabled: bool, challenge_id: StringName) -> void:
	if enabled and challenge_id not in selected_challenges:
		selected_challenges.append(challenge_id)
	elif not enabled:
		selected_challenges.erase(challenge_id)
	_refresh()

func _toggle_modifier(
	enabled: bool,
	area_id: StringName,
	modifier_id: StringName,
	button: CheckButton
) -> void:
	var ids: Array = selected_modifiers[area_id]
	if enabled and ids.size() >= 2:
		button.set_pressed_no_signal(false)
		error_label.text = "%s最多选择两项异变" % _area_name(area_id)
		return
	if enabled and modifier_id not in ids:
		ids.append(modifier_id)
	elif not enabled:
		ids.erase(modifier_id)
	selected_modifiers[area_id] = ids
	_refresh()

func _refresh() -> void:
	var count := int(area_count_option.get_selected_metadata())
	for modifier_id in modifier_buttons:
		var button: CheckButton = modifier_buttons[modifier_id]
		var area_index := StartConfig.STANDARD_AREAS.find(button.get_meta("area_id"))
		button.disabled = area_index >= count
		if button.disabled and button.button_pressed:
			button.set_pressed_no_signal(false)
			selected_modifiers[button.get_meta("area_id")].erase(modifier_id)
	summary_label.text = "当前契据｜%d 区 · %d 项挑战 · 目标 %d%% · 每区最多两项异变" % [
		count, selected_challenges.size(), int(float(target_option.get_selected_metadata()) * 100.0),
	]
	if not error_label.text.begins_with("无法"):
		error_label.text = ""

func _start_custom() -> void:
	var count := int(area_count_option.get_selected_metadata())
	var areas: Array = StartConfig.STANDARD_AREAS.slice(0, count)
	var modifiers: Dictionary = {}
	for area_id in areas:
		modifiers[area_id] = selected_modifiers[area_id].duplicate()
	var config := StartConfig.new()
	var result := config.restore_snapshot({
		"mode": StartConfig.CUSTOM,
		"seed_value": maxi(int(Time.get_unix_time_from_system() * 1000.0), 1),
		"starting_deck_id": deck_option.get_selected_metadata(),
		"challenge_ids": selected_challenges.duplicate(),
		"area_sequence": areas,
		"area_modifier_ids": modifiers,
		"target_multiplier": float(target_option.get_selected_metadata()),
		"daily_date_key": "",
		"decoration_id": decoration_option.get_selected_metadata(),
	})
	if not result.accepted:
		error_label.text = result.reason
		return
	var cleared := ExpeditionSaveStore.new(save_path).clear()
	if not cleared.accepted:
		error_label.text = cleared.reason
		return
	_launch(&"new", config.to_snapshot())

func _continue_saved() -> void:
	_launch(&"continue", {})

func _launch(mode: StringName, config_snapshot: Dictionary) -> void:
	var root := get_tree().root
	root.set_meta("expedition_launch_mode", mode)
	root.set_meta("expedition_start_config", config_snapshot.duplicate(true))
	root.set_meta("expedition_save_path", save_path)
	root.set_meta("expedition_meta_path", custom_meta_path)
	get_tree().change_scene_to_file(RUN_SCENE)

func _area_name(area_id: StringName) -> String:
	match area_id:
		&"gold_corridor": return "金线回廊"
		&"mirror_hall": return "反照牌厅"
		&"faceless_hub": return "无面中枢"
	return String(area_id)
