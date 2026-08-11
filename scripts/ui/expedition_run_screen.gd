class_name ExpeditionRunScreen
extends Control

const MAIN_MENU_SCENE := "res://scenes/run/main_menu_screen.tscn"
const AREA_SCENES := {
	&"gold_corridor": "res://scenes/run/gold_corridor_run_screen.tscn",
	&"mirror_hall": "res://scenes/run/mirror_hall_run_screen.tscn",
	&"faceless_hub": "res://scenes/run/faceless_hub_run_screen.tscn",
}
const ExpeditionConfigs = preload("res://scripts/run/expedition_config_catalog.gd")
const ExpeditionMeta = preload("res://scripts/run/expedition_meta_store.gd")
const ChallengeRules = preload("res://scripts/run/expedition_challenge_rules.gd")
const StartConfig = preload("res://scripts/run/expedition_start_config.gd")
const DailyService = preload("res://scripts/run/daily_challenge_service.gd")
const DailyLeaderboard = preload("res://scripts/run/daily_leaderboard_store.gd")
const Achievements = preload("res://scripts/run/achievement_catalog.gd")

@onready var area_host: Control = %AreaHost
@onready var error_panel: Control = %ExpeditionErrorPanel
@onready var error_label: Label = %ExpeditionErrorLabel
@onready var summary_panel: Control = %ExpeditionSummaryPanel
@onready var seed_label: Label = %ExpeditionSeedLabel
@onready var config_label: Label = %ExpeditionConfigLabel
@onready var area_history_label: Label = %ExpeditionAreaHistoryLabel
@onready var final_build_label: Label = %ExpeditionFinalBuildLabel
@onready var epilogue_label: Label = %ExpeditionEpilogueLabel
@onready var daily_leaderboard_label: Label = %DailyLeaderboardLabel
@onready var return_button: Button = %ReturnFromExpeditionButton
@onready var return_from_error_button: Button = %ReturnFromErrorButton
@onready var narrative_card: Control = %NarrativeCard
@onready var feedback_layer: InteractionMotionLayer = %ExpeditionFeedbackLayer

var expedition := ExpeditionSession.new()
var store: ExpeditionSaveStore
var save_path := "user://expedition_save.cfg"
var meta_path := "user://expedition_meta.cfg"
var daily_leaderboard_path := "user://daily_leaderboard.cfg"
var meta_store
var current_area_screen: AreaRunScreen
var _pending_completion: Dictionary = {}
var _new_achievement_ids: Array[StringName] = []

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
	var starting_deck_id: StringName = root_window.get_meta(
		"expedition_starting_deck_id",
		ExpeditionConfigs.DICE_CONTROL
	)
	var challenge_ids: Array[StringName] = []
	challenge_ids.assign(root_window.get_meta("expedition_challenge_ids", []))
	save_path = String(root_window.get_meta(
		"expedition_save_path",
		save_path
	))
	meta_path = String(root_window.get_meta("expedition_meta_path", meta_path))
	daily_leaderboard_path = String(root_window.get_meta(
		"daily_leaderboard_path", daily_leaderboard_path
	))
	var launch_config_snapshot: Dictionary = root_window.get_meta(
		"expedition_start_config", {}
	).duplicate(true)
	root_window.remove_meta("expedition_launch_mode")
	root_window.remove_meta("expedition_seed")
	root_window.remove_meta("expedition_starting_deck_id")
	root_window.remove_meta("expedition_challenge_ids")
	root_window.remove_meta("expedition_start_config")
	store = ExpeditionSaveStore.new(save_path)
	meta_store = ExpeditionMeta.new(meta_path)
	if mode == &"new":
		var cleared := store.clear()
		if not cleared.accepted:
			_show_error(cleared.reason)
			return
		var result: OperationResult
		if launch_config_snapshot.is_empty():
			result = expedition.start_new(
				maxi(seed, 1), starting_deck_id, challenge_ids
			)
		else:
			var launch_config := StartConfig.new()
			result = launch_config.restore_snapshot(launch_config_snapshot)
			if result.accepted:
				result = expedition.start_with_config(launch_config)
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
		var record_result := _record_completion()
		if not record_result.accepted:
			_show_error(record_result.reason)
			return
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
		expedition.current_area_index < expedition.start_config.area_sequence.size() - 1
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
	var record_result := _record_run(&"failed", expedition.failure_reason)
	if not record_result.accepted:
		_show_error(record_result.reason)
		return
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
		var record_result := _record_completion()
		if not record_result.accepted:
			_show_error(record_result.reason)
			return
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
	config_label.text = "起手牌组｜%s　挑战｜%s" % [
		_deck_name(expedition.starting_deck_id),
		ChallengeRules.new(expedition.challenge_ids).display_copy(
			ExpeditionConfigs.new()
		),
	]
	config_label.text += "　模式｜%s" % _mode_name(expedition.start_config.mode)
	var area_lines: Array[String] = []
	for index in range(expedition.completed_areas.size()):
		var completion: Dictionary = expedition.completed_areas[index]
		var dealer: Dictionary = completion.get("dealer", {})
		area_lines.append("%d. %s　%s" % [
			index + 1,
			_area_name(completion.get("area_id", &"")),
			_dealer_score_copy(dealer),
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
	_bind_daily_leaderboard()
	epilogue_label.text = (
		"%d 份区域契据都已留下可复核的轨迹。你证明了公开规则可以被理解、预演并拆解。"
		% expedition.completed_areas.size()
	)
	if not _new_achievement_ids.is_empty():
		var achievement_names: Array[String] = []
		for achievement_id in _new_achievement_ids:
			var definition := Achievements.new().find(achievement_id)
			achievement_names.append(
				String(achievement_id)
				if definition.is_empty()
				else String(definition.get("display_name", achievement_id))
			)
		epilogue_label.text += "\n新成就｜%s" % " · ".join(achievement_names)
		feedback_layer.call_deferred(
			"play_rare_highlight",
			&"achievement",
			0,
			&"faceless_hub"
		)

func _on_return_from_summary() -> void:
	var result := store.clear()
	if not result.accepted:
		_show_error(result.reason)
		return
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)

func _dealer_score_copy(dealer: Dictionary) -> String:
	var target_total = dealer.get("target_total", 0)
	var cumulative_total = dealer.get("cumulative_total")
	if cumulative_total is int:
		return "庄家解析 %d / %d" % [cumulative_total, target_total]
	return "庄家解析 已达成 / %d（历史分数未记录）" % target_total

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

func _deck_name(deck_id: StringName) -> String:
	var definition: Dictionary = ExpeditionConfigs.new().find_deck(deck_id)
	return String(deck_id) if definition.is_empty() else definition["display_name"]

func _record_run(result_kind: StringName, reason: String) -> OperationResult:
	if meta_store == null:
		return OperationResult.new(false, "远征元进度存储尚未初始化")
	var route_ids: Array[StringName] = []
	var reward_ids: Array[StringName] = []
	var completed_area_ids: Array[StringName] = []
	for completion in expedition.completed_areas:
		completed_area_ids.append(completion.get("area_id", &""))
		for room in completion.get("rooms", []):
			route_ids.append(room.get("room_id", &""))
		var reward_id: StringName = (
			completion.get("reward_card_id", &"")
			if completion.get("reward_kind", &"engraving") == &"rare_card"
			else completion.get("engraving_id", &"")
		)
		if reward_id != &"":
			reward_ids.append(reward_id)
	if (
		result_kind == &"failed"
		and current_area_screen != null
		and current_area_screen.area_session != null
	):
		for room_id in current_area_screen.area_session.selected_room_ids:
			route_ids.append(room_id)
	var final_state := expedition.inherited_state
	if (
		result_kind == &"failed"
		and current_area_screen != null
		and current_area_screen.area_session != null
	):
		final_state = {
			"deck_ids": current_area_screen.area_session.deck_ids.duplicate(),
			"intel_tickets": current_area_screen.area_session.intel_tickets,
		}
	var telemetry := expedition.balance_telemetry_snapshot()
	return meta_store.record_run({
		"run_id": expedition.run_id,
		"ended_at": int(Time.get_unix_time_from_system()),
		"result": result_kind,
		"mode": expedition.start_config.mode,
		"seed_value": expedition.seed_value,
		"starting_deck_id": expedition.starting_deck_id,
		"challenge_ids": expedition.challenge_ids.duplicate(),
		"completed_areas": completed_area_ids,
		"route_ids": route_ids,
		"reward_ids": reward_ids,
		"final_deck_count": final_state.get("deck_ids", []).size(),
		"intel_tickets": int(final_state.get("intel_tickets", 0)),
		"failure_reason": reason,
		"zero_calibration": int(telemetry.get("calibration_actions", 0)) == 0,
		"full_allocation_every_round": (
			int(telemetry.get("rounds_total", 0)) > 0
			and int(telemetry.get("full_allocation_rounds", 0))
				== int(telemetry.get("rounds_total", 0))
		),
		"emergency_spend": int(telemetry.get("emergency_spend_total", 0)),
		"storm_count": int(telemetry.get("storm_rounds", 0)),
		"engraving_set_activations": int(
			telemetry.get("engraving_set_activations", 0)
		),
		"daily_score": (
			DailyService.new().expedition_score(expedition.completed_areas)
			if expedition.start_config.mode == StartConfig.DAILY
			else 0
		),
	})

func _record_completion() -> OperationResult:
	_new_achievement_ids.clear()
	var before_meta = meta_store.load_snapshot()
	var meta_result := _record_run(&"complete", "")
	if not meta_result.accepted:
		return meta_result
	var after_meta = meta_store.load_snapshot()
	if before_meta.accepted and after_meta.accepted:
		for achievement_id in after_meta.snapshot.get("achievements", {}):
			if (
				bool(after_meta.snapshot["achievements"].get(achievement_id, false))
				and not bool(before_meta.snapshot["achievements"].get(achievement_id, false))
			):
				_new_achievement_ids.append(StringName(achievement_id))
	if expedition.start_config.mode != StartConfig.DAILY:
		return OperationResult.new(true)
	var daily := DailyService.new()
	if not daily.leaderboard_eligible(
		expedition.start_config, daily.local_date_key()
	):
		return OperationResult.new(true)
	var telemetry := expedition.balance_telemetry_snapshot()
	return DailyLeaderboard.new(daily_leaderboard_path).record({
		"date_key": expedition.start_config.daily_date_key,
		"run_id": expedition.run_id,
		"score": daily.expedition_score(expedition.completed_areas),
		"emergency_spend": int(telemetry.get("emergency_spend_total", 0)),
		"completion_time": maxi(
			int(Time.get_unix_time_from_system()) - expedition.started_at_unix, 0
		),
		"completed": true,
	}, daily.local_date_key())

func _mode_name(mode: StringName) -> String:
	match mode:
		StartConfig.DAILY:
			return "每日挑战"
		StartConfig.CUSTOM:
			return "自定义远征"
	return "标准远征"

func _bind_daily_leaderboard() -> void:
	daily_leaderboard_label.visible = expedition.start_config.mode == StartConfig.DAILY
	if not daily_leaderboard_label.visible:
		return
	var entries := DailyLeaderboard.new(daily_leaderboard_path).entries(
		expedition.start_config.daily_date_key
	)
	var lines: Array[String] = [
		"本地每日榜 · %s · 前 10 名" % expedition.start_config.daily_date_key,
	]
	for index in entries.size():
		var entry: Dictionary = entries[index]
		lines.append("%d. %d 分｜应急 %d｜%d 秒%s" % [
			index + 1,
			entry.score,
			entry.emergency_spend,
			entry.completion_time,
			"　← 本局" if entry.run_id == expedition.run_id else "",
		])
	if entries.is_empty():
		lines.append("跨日旧局已完成，但不进入今日榜。")
	daily_leaderboard_label.text = "\n".join(lines)

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
