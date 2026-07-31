class_name ExpeditionMetaStore
extends RefCounted

const ExpeditionConfigs = preload("res://scripts/run/expedition_config_catalog.gd")

class LoadResult extends RefCounted:
	var accepted: bool
	var reason: String
	var snapshot: Dictionary

	func _init(
		p_accepted: bool,
		p_reason: String = "",
		p_snapshot: Dictionary = {}
	) -> void:
		accepted = p_accepted
		reason = p_reason
		snapshot = p_snapshot

const FORMAT_VERSION := 1
const HISTORY_LIMIT := 30

var config_path := "user://expedition_meta.cfg"

func _init(path := "user://expedition_meta.cfg") -> void:
	config_path = path

func load_snapshot() -> LoadResult:
	if not FileAccess.file_exists(_absolute(config_path)):
		return LoadResult.new(true, "", _default_snapshot())
	var config := ConfigFile.new()
	var error := config.load(_absolute(config_path))
	if error != OK:
		return LoadResult.new(false, "无法读取远征进度：%s" % error)
	if config.get_value("meta", "format_version", -1) != FORMAT_VERSION:
		return LoadResult.new(false, "远征进度版本不受支持")
	var snapshot = config.get_value("progress", "snapshot", null)
	if not snapshot is Dictionary:
		return LoadResult.new(false, "远征进度主体格式无效")
	var validation_error := _snapshot_error(snapshot)
	if not validation_error.is_empty():
		return LoadResult.new(false, validation_error)
	return LoadResult.new(true, "", snapshot.duplicate(true))

func challenges_unlocked() -> bool:
	var loaded := load_snapshot()
	return loaded.accepted and bool(loaded.snapshot["challenges_unlocked"])

func history() -> Array[Dictionary]:
	var loaded := load_snapshot()
	var result: Array[Dictionary] = []
	if not loaded.accepted:
		return result
	for record in loaded.snapshot["history"]:
		result.append(record.duplicate(true))
	return result

func record_run(record: Dictionary) -> OperationResult:
	var record_error := _record_error(record)
	if not record_error.is_empty():
		return OperationResult.new(false, record_error)
	var loaded := load_snapshot()
	if not loaded.accepted:
		return OperationResult.new(false, loaded.reason)
	var snapshot := loaded.snapshot.duplicate(true)
	for existing in snapshot["history"]:
		if existing["run_id"] == record["run_id"]:
			return OperationResult.new(true)
	var next_history: Array = snapshot["history"].duplicate(true)
	next_history.push_front(record.duplicate(true))
	if next_history.size() > HISTORY_LIMIT:
		next_history.resize(HISTORY_LIMIT)
	snapshot["history"] = next_history
	if record["result"] == &"complete":
		snapshot["challenges_unlocked"] = true
		var identity_counts: Dictionary = snapshot["identity_completions"].duplicate(true)
		var deck_id: StringName = record["starting_deck_id"]
		identity_counts[deck_id] = int(identity_counts.get(deck_id, 0)) + 1
		snapshot["identity_completions"] = identity_counts
		var challenge_counts: Dictionary = snapshot["challenge_completions"].duplicate(true)
		for challenge_id in record["challenge_ids"]:
			challenge_counts[challenge_id] = int(challenge_counts.get(challenge_id, 0)) + 1
		snapshot["challenge_completions"] = challenge_counts
	return _save_snapshot(snapshot)

func clear() -> OperationResult:
	for suffix: String in ["", ".tmp", ".bak"]:
		var path := _absolute(config_path + suffix)
		if not FileAccess.file_exists(path):
			continue
		var error := DirAccess.remove_absolute(path)
		if error != OK:
			return OperationResult.new(false, "无法清除远征进度：%s" % error)
	return OperationResult.new(true)

func _save_snapshot(snapshot: Dictionary) -> OperationResult:
	var validation_error := _snapshot_error(snapshot)
	if not validation_error.is_empty():
		return OperationResult.new(false, validation_error)
	var temp_path := config_path + ".tmp"
	var backup_path := config_path + ".bak"
	var absolute_temp := _absolute(temp_path)
	if FileAccess.file_exists(absolute_temp):
		DirAccess.remove_absolute(absolute_temp)
	var config := ConfigFile.new()
	config.set_value("meta", "format_version", FORMAT_VERSION)
	config.set_value("progress", "snapshot", snapshot.duplicate(true))
	var error := config.save(absolute_temp)
	if error != OK:
		return OperationResult.new(false, "无法写入远征进度临时文件：%s" % error)
	var verified := ConfigFile.new()
	error = verified.load(absolute_temp)
	if error != OK:
		DirAccess.remove_absolute(absolute_temp)
		return OperationResult.new(false, "远征进度临时文件校验失败：%s" % error)
	var absolute_path := _absolute(config_path)
	var absolute_backup := _absolute(backup_path)
	if FileAccess.file_exists(absolute_backup):
		DirAccess.remove_absolute(absolute_backup)
	var had_existing := FileAccess.file_exists(absolute_path)
	if had_existing:
		error = DirAccess.rename_absolute(absolute_path, absolute_backup)
		if error != OK:
			DirAccess.remove_absolute(absolute_temp)
			return OperationResult.new(false, "无法替换远征进度：%s" % error)
	error = DirAccess.rename_absolute(absolute_temp, absolute_path)
	if error != OK:
		if had_existing:
			DirAccess.rename_absolute(absolute_backup, absolute_path)
		DirAccess.remove_absolute(absolute_temp)
		return OperationResult.new(false, "无法提交远征进度：%s" % error)
	if FileAccess.file_exists(absolute_backup):
		DirAccess.remove_absolute(absolute_backup)
	return OperationResult.new(true)

func _default_snapshot() -> Dictionary:
	var identity_counts: Dictionary = {}
	for deck_id in ExpeditionConfigs.new().deck_ids():
		identity_counts[deck_id] = 0
	var challenge_counts: Dictionary = {}
	for challenge_id in ExpeditionConfigs.new().challenge_ids():
		challenge_counts[challenge_id] = 0
	return {
		"challenges_unlocked": false,
		"identity_completions": identity_counts,
		"challenge_completions": challenge_counts,
		"history": [],
	}

func _snapshot_error(snapshot: Dictionary) -> String:
	for key in [
		"challenges_unlocked",
		"identity_completions",
		"challenge_completions",
		"history",
	]:
		if not snapshot.has(key):
			return "远征进度缺少字段：%s" % key
	if not snapshot["challenges_unlocked"] is bool:
		return "挑战解锁状态格式无效"
	if not snapshot["identity_completions"] is Dictionary:
		return "构筑完成次数格式无效"
	if not snapshot["challenge_completions"] is Dictionary:
		return "挑战完成次数格式无效"
	if not snapshot["history"] is Array or snapshot["history"].size() > HISTORY_LIMIT:
		return "远征历史格式无效"
	for record in snapshot["history"]:
		if not record is Dictionary:
			return "远征历史条目格式无效"
		var error := _record_error(record)
		if not error.is_empty():
			return error
	return ""

func _record_error(record: Dictionary) -> String:
	for key in [
		"run_id",
		"ended_at",
		"result",
		"seed_value",
		"starting_deck_id",
		"challenge_ids",
		"completed_areas",
		"route_ids",
		"reward_ids",
		"final_deck_count",
		"intel_tickets",
		"failure_reason",
	]:
		if not record.has(key):
			return "远征历史缺少字段：%s" % key
	if record["run_id"] == &"":
		return "远征历史局次 ID 不能为空"
	if not record["ended_at"] is int or record["ended_at"] < 0:
		return "远征历史结束时间无效"
	if record["result"] not in [&"complete", &"failed"]:
		return "远征历史结果无效"
	if not record["seed_value"] is int or record["seed_value"] <= 0:
		return "远征历史种子无效"
	if record["starting_deck_id"] not in ExpeditionConfigs.new().deck_ids():
		return "远征历史起始牌组无效"
	if not record["challenge_ids"] is Array:
		return "远征历史挑战格式无效"
	var selection_error := ExpeditionConfigs.new().selection_error(
		record["starting_deck_id"],
		record["challenge_ids"],
		true
	)
	if not selection_error.is_empty():
		return selection_error
	for key in ["completed_areas", "route_ids", "reward_ids"]:
		if not record[key] is Array:
			return "远征历史列表字段无效：%s" % key
	if not record["final_deck_count"] is int or record["final_deck_count"] < 0:
		return "远征历史最终牌组数量无效"
	if not record["intel_tickets"] is int or record["intel_tickets"] < 0:
		return "远征历史情报券无效"
	if not record["failure_reason"] is String:
		return "远征历史失败原因无效"
	return ""

func _absolute(path: String) -> String:
	return ProjectSettings.globalize_path(path)
