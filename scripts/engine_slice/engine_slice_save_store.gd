class_name EngineSliceSaveStore
extends RefCounted

const OperationResult = preload("res://scripts/run/operation_result.gd")

const FORMAT_VERSION := 2

var config_path := "user://gold_engine_slice_v1.cfg"

func _init(path := "user://gold_engine_slice_v1.cfg") -> void:
	config_path = path

func has_save() -> bool:
	return FileAccess.file_exists(_absolute(config_path))

func save_session(session) -> OperationResult:
	if session == null:
		return OperationResult.new(false, "引擎切片会话不存在")
	return save_snapshot(session.to_snapshot())

func save_snapshot(snapshot: Dictionary) -> OperationResult:
	var temp_path := config_path + ".tmp"
	var config := ConfigFile.new()
	config.set_value("meta", "format_version", FORMAT_VERSION)
	config.set_value("run", "snapshot", snapshot)
	var error := config.save(_absolute(temp_path))
	if error != OK:
		return OperationResult.new(false, "无法写入引擎切片存档：%s" % error)
	var target := _absolute(config_path)
	var backup := _absolute(config_path + ".bak")
	if FileAccess.file_exists(backup):
		DirAccess.remove_absolute(backup)
	if FileAccess.file_exists(target):
		error = DirAccess.rename_absolute(target, backup)
		if error != OK:
			return OperationResult.new(false, "无法备份旧的引擎切片存档：%s" % error)
	error = DirAccess.rename_absolute(_absolute(temp_path), target)
	if error != OK:
		if FileAccess.file_exists(backup):
			DirAccess.rename_absolute(backup, target)
		return OperationResult.new(false, "无法提交引擎切片存档：%s" % error)
	if FileAccess.file_exists(backup):
		DirAccess.remove_absolute(backup)
	return OperationResult.new(true)

func load_session() -> Dictionary:
	if not has_save():
		return {"accepted": false, "reason": "没有可继续的金线引擎切片"}
	var config := ConfigFile.new()
	var error := config.load(_absolute(config_path))
	if error != OK:
		return {"accepted": false, "reason": "无法读取引擎切片存档：%s" % error}
	var version := int(config.get_value("meta", "format_version", -1))
	if version not in [1, FORMAT_VERSION]:
		return {"accepted": false, "reason": "引擎切片存档版本不受支持"}
	var snapshot = config.get_value("run", "snapshot", null)
	if not snapshot is Dictionary:
		return {"accepted": false, "reason": "引擎切片存档主体无效"}
	if version == 1:
		snapshot = _migrate_v1(snapshot)
	return {"accepted": true, "snapshot": snapshot}

func load_snapshot() -> Dictionary:
	var result := load_session()
	return {
		"ok": bool(result.get("accepted", false)),
		"reason": String(result.get("reason", "")),
		"snapshot": result.get("snapshot", {}),
	}

func clear() -> OperationResult:
	for suffix in ["", ".tmp", ".bak"]:
		var path := _absolute(config_path + suffix)
		if FileAccess.file_exists(path):
			var error := DirAccess.remove_absolute(path)
			if error != OK:
				return OperationResult.new(false, "无法清除引擎切片存档：%s" % error)
	return OperationResult.new(true)

func clear_save() -> OperationResult:
	return clear()

func _absolute(path: String) -> String:
	return ProjectSettings.globalize_path(path)

func _migrate_v1(snapshot: Dictionary) -> Dictionary:
	var migrated := snapshot.duplicate(true)
	var battle: Dictionary = migrated.get("battle", {}).duplicate(true)
	if not battle.is_empty():
		battle["activated_technique_counts"] = battle.get("technique_uses", {}).duplicate(true)
		battle["die_technique_marks"] = {}
		battle["engine_charge"] = 0
		battle["carried_block"] = 0
		battle["next_retained_block"] = 0
		battle["counter_percent"] = 0
		migrated["battle"] = battle
	return migrated
