class_name ExpeditionSetupScreen
extends Control

const MAIN_MENU_SCENE := "res://scenes/run/main_menu_screen.tscn"
const EXPEDITION_SCENE := "res://scenes/run/expedition_run_screen.tscn"
const ExpeditionConfigs = preload("res://scripts/run/expedition_config_catalog.gd")
const ExpeditionMeta = preload("res://scripts/run/expedition_meta_store.gd")
const ChallengeRules = preload("res://scripts/run/expedition_challenge_rules.gd")

@onready var deck_choice_row: HBoxContainer = %DeckChoiceRow
@onready var challenge_grid: GridContainer = %ChallengeGrid
@onready var challenge_count_label: Label = %ChallengeCountLabel
@onready var challenge_lock_label: Label = %ChallengeLockLabel
@onready var seed_input: LineEdit = %ExpeditionSeedInput
@onready var history_list: VBoxContainer = %RunHistoryList
@onready var error_label: Label = %SetupErrorLabel
@onready var start_button: Button = %StartConfiguredExpeditionButton
@onready var return_button: Button = %ReturnFromSetupButton
@onready var setup_subtitle: Label = %SetupSubtitle
@onready var deck_recommendation_label: Label = %DeckRecommendationLabel
@onready var selection_summary_label: Label = %SelectionSummaryLabel
@onready var first_run_journey_panel: PanelContainer = %FirstRunJourneyPanel
@onready var history_panel: PanelContainer = %HistoryPanel

var configs = ExpeditionConfigs.new()
var meta_store
var meta_path := "user://expedition_meta.cfg"
var save_path := "user://expedition_save.cfg"
var selected_deck_id: StringName = ExpeditionConfigs.DICE_CONTROL
var selected_challenge_ids: Array[StringName] = []
var challenges_unlocked := false
var _deck_buttons: Dictionary = {}
var _challenge_buttons: Dictionary = {}

func _ready() -> void:
	var root_window := get_tree().root
	meta_path = String(root_window.get_meta("expedition_meta_path", meta_path))
	save_path = String(root_window.get_meta("expedition_save_path", save_path))
	meta_store = ExpeditionMeta.new(meta_path)
	var loaded = meta_store.load_snapshot()
	if not loaded.accepted:
		error_label.text = loaded.reason
		start_button.disabled = true
		return_button.pressed.connect(_return_to_menu)
		return
	challenges_unlocked = loaded.snapshot["challenges_unlocked"]
	_build_deck_choices()
	_build_challenge_choices()
	_build_history(loaded.snapshot["history"])
	seed_input.text = str(_new_seed())
	start_button.pressed.connect(_start_selected)
	return_button.pressed.connect(_return_to_menu)
	_refresh_selection()

func _build_deck_choices() -> void:
	for child in deck_choice_row.get_children():
		child.queue_free()
	var group := ButtonGroup.new()
	for definition in configs.all_decks():
		var button := Button.new()
		button.custom_minimum_size = Vector2(190, 96)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.toggle_mode = true
		button.button_group = group
		var is_recommended: bool = definition["id"] == configs.recommended_deck_id()
		button.text = "%s%s\n%s" % [
			"首局推荐｜" if is_recommended else "",
			definition["display_name"],
			definition["description"],
		]
		button.tooltip_text = "十二张固定起手牌｜立即开放"
		button.set_meta("deck_id", definition["id"])
		button.pressed.connect(_select_deck.bind(definition["id"]))
		deck_choice_row.add_child(button)
		_deck_buttons[definition["id"]] = button

func _build_challenge_choices() -> void:
	for child in challenge_grid.get_children():
		child.queue_free()
	for definition in configs.all_challenges():
		var button := Button.new()
		button.custom_minimum_size = Vector2(240, 62)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.toggle_mode = true
		button.disabled = not challenges_unlocked
		button.text = "%s\n%s" % [
			definition["display_name"],
			definition["description"],
		]
		button.set_meta("challenge_id", definition["id"])
		button.pressed.connect(_toggle_challenge.bind(definition["id"]))
		challenge_grid.add_child(button)
		_challenge_buttons[definition["id"]] = button

func _build_history(history: Array) -> void:
	for child in history_list.get_children():
		child.queue_free()
	history_panel.visible = not history.is_empty()
	if history.is_empty():
		return
	for record in history:
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 88)
		button.text = "%s｜种子 %d\n%s · %s\n同配置重开" % [
			"完成" if record["result"] == &"complete" else "失败",
			record["seed_value"],
			_deck_name(record["starting_deck_id"]),
			ChallengeRules.new(record["challenge_ids"]).display_copy(configs),
		]
		button.tooltip_text = (
			"失败原因：%s" % record["failure_reason"]
			if record["result"] == &"failed"
			else "载入相同种子、牌组与挑战"
		)
		button.set_meta("run_id", record["run_id"])
		button.pressed.connect(_replay_record.bind(record.duplicate(true)))
		history_list.add_child(button)

func _select_deck(deck_id: StringName) -> void:
	selected_deck_id = deck_id
	error_label.text = ""
	_refresh_selection()

func _toggle_challenge(challenge_id: StringName) -> void:
	if challenge_id in selected_challenge_ids:
		selected_challenge_ids.erase(challenge_id)
	elif selected_challenge_ids.size() >= ExpeditionConfigs.MAX_CHALLENGES:
		error_label.text = "单局最多启用两项挑战；请先取消一项。"
	else:
		selected_challenge_ids.append(challenge_id)
		error_label.text = ""
	_refresh_selection()

func _refresh_selection() -> void:
	for deck_id in _deck_buttons:
		_deck_buttons[deck_id].button_pressed = deck_id == selected_deck_id
	for challenge_id in _challenge_buttons:
		_challenge_buttons[challenge_id].button_pressed = (
			challenge_id in selected_challenge_ids
		)
	challenge_count_label.text = "已选条款 %d / %d" % [
		selected_challenge_ids.size(),
		ExpeditionConfigs.MAX_CHALLENGES,
	]
	challenge_lock_label.visible = not challenges_unlocked
	challenge_grid.visible = challenges_unlocked
	first_run_journey_panel.visible = not challenges_unlocked
	setup_subtitle.text = (
		"选择十二张起手牌、至多两项挑战，并留下可复盘的种子。"
		if challenges_unlocked
		else "首局选择一套起手牌并使用标准难度；种子可用于复盘。"
	)
	deck_recommendation_label.text = "首局推荐：%s%s" % [
		_deck_name(configs.recommended_deck_id()),
		"（已选择）" if selected_deck_id == configs.recommended_deck_id() else "",
	]
	challenge_lock_label.text = (
		"挑战条款尚未生效：完成一次完整三区远征后六项同时开放。"
		if not challenges_unlocked
		else "挑战已开放；所有条款在出发前公开，单局最多组合两项。"
	)
	var difficulty_copy := (
		ChallengeRules.new(selected_challenge_ids).display_copy(configs)
		if challenges_unlocked
		else "标准难度"
	)
	selection_summary_label.text = "当前配置：%s · %s%s" % [
		_deck_name(selected_deck_id),
		difficulty_copy,
		(
			"（推荐首局）"
			if (
				not challenges_unlocked
				and selected_deck_id == configs.recommended_deck_id()
			)
			else ""
		),
	]

func _start_selected() -> void:
	var seed := int(seed_input.text)
	if seed <= 0:
		error_label.text = "种子必须是大于 0 的整数。"
		return
	var error := configs.selection_error(
		selected_deck_id,
		selected_challenge_ids,
		challenges_unlocked
	)
	if not error.is_empty():
		error_label.text = error
		return
	_launch(seed, selected_deck_id, selected_challenge_ids)

func _replay_record(record: Dictionary) -> void:
	_launch(
		record["seed_value"],
		record["starting_deck_id"],
		record["challenge_ids"]
	)

func _launch(
	seed: int,
	deck_id: StringName,
	challenge_ids: Array
) -> void:
	var root_window := get_tree().root
	root_window.set_meta("expedition_launch_mode", &"new")
	root_window.set_meta("expedition_seed", seed)
	root_window.set_meta("expedition_starting_deck_id", deck_id)
	root_window.set_meta("expedition_challenge_ids", challenge_ids.duplicate())
	root_window.set_meta("expedition_save_path", save_path)
	root_window.set_meta("standard_expedition_save_path", save_path)
	root_window.set_meta("expedition_meta_path", meta_path)
	SfxAccess.play(self, &"page_transition")
	get_tree().change_scene_to_file(EXPEDITION_SCENE)

func _return_to_menu() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)

func _deck_name(deck_id: StringName) -> String:
	var definition: Dictionary = configs.find_deck(deck_id)
	return String(deck_id) if definition.is_empty() else definition["display_name"]

func _new_seed() -> int:
	return maxi(
		int(abs(Time.get_unix_time_from_system() * 1000.0) + Time.get_ticks_msec()),
		1
	)
