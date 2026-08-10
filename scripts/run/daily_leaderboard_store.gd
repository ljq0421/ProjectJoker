class_name DailyLeaderboardStore
extends RefCounted

const FORMAT_VERSION := 1
const LIMIT := 10

var config_path := "user://daily_leaderboard.cfg"

func _init(path := "user://daily_leaderboard.cfg") -> void:
	config_path = path

func entries(date_key: String) -> Array[Dictionary]:
	var snapshot := _load()
	var result: Array[Dictionary] = []
	for entry in snapshot.get("boards", {}).get(date_key, []):
		result.append(entry.duplicate(true))
	return result

func record(entry: Dictionary, current_date_key: String) -> OperationResult:
	var error := _entry_error(entry)
	if not error.is_empty():
		return OperationResult.new(false, error)
	if not bool(entry["completed"]):
		return OperationResult.new(false, "只有完整通关才能进入每日榜")
	if entry["date_key"] != current_date_key:
		return OperationResult.new(false, "跨日旧局可以继续，但不能进入当日榜")
	var snapshot := _load()
	var boards: Dictionary = snapshot.get("boards", {}).duplicate(true)
	var board: Array = boards.get(current_date_key, []).duplicate(true)
	for existing in board:
		if existing.get("run_id", &"") == entry["run_id"]:
			return OperationResult.new(true)
	board.append(entry.duplicate(true))
	board.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["score"] != b["score"]:
			return a["score"] > b["score"]
		if a["emergency_spend"] != b["emergency_spend"]:
			return a["emergency_spend"] < b["emergency_spend"]
		return a["completion_time"] < b["completion_time"]
	)
	if board.size() > LIMIT:
		board.resize(LIMIT)
	boards[current_date_key] = board
	snapshot["boards"] = boards
	return _save(snapshot)

func clear() -> OperationResult:
	var absolute := ProjectSettings.globalize_path(config_path)
	if not FileAccess.file_exists(absolute):
		return OperationResult.new(true)
	var error := DirAccess.remove_absolute(absolute)
	return OperationResult.new(error == OK, "" if error == OK else "无法清除每日榜")

func _load() -> Dictionary:
	var config := ConfigFile.new()
	if config.load(ProjectSettings.globalize_path(config_path)) != OK:
		return {"boards": {}}
	if int(config.get_value("meta", "format_version", -1)) != FORMAT_VERSION:
		return {"boards": {}}
	var snapshot = config.get_value("daily", "snapshot", {"boards": {}})
	return snapshot.duplicate(true) if snapshot is Dictionary else {"boards": {}}

func _save(snapshot: Dictionary) -> OperationResult:
	var config := ConfigFile.new()
	config.set_value("meta", "format_version", FORMAT_VERSION)
	config.set_value("daily", "snapshot", snapshot.duplicate(true))
	var error := config.save(ProjectSettings.globalize_path(config_path))
	return OperationResult.new(error == OK, "" if error == OK else "无法写入每日榜")

func _entry_error(entry: Dictionary) -> String:
	for key in [
		"date_key", "run_id", "score", "emergency_spend", "completion_time", "completed",
	]:
		if not entry.has(key):
			return "每日榜记录缺少字段：%s" % key
	if String(entry["date_key"]).is_empty() or String(entry["run_id"]).is_empty():
		return "每日榜日期或局次 ID 不能为空"
	for key in ["score", "emergency_spend", "completion_time"]:
		if not entry[key] is int or entry[key] < 0:
			return "每日榜数值字段无效：%s" % key
	if not entry["completed"] is bool:
		return "每日榜完成状态无效"
	return ""
