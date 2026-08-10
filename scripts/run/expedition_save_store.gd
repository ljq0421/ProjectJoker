class_name ExpeditionSaveStore
extends RefCounted

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

const FORMAT_VERSION := 3
const CONTENT_VERSION := 2

var config_path := "user://expedition_save.cfg"

func _init(path := "user://expedition_save.cfg") -> void:
	config_path = path

func has_save() -> bool:
	return FileAccess.file_exists(_absolute(config_path))

func save(snapshot: Dictionary) -> OperationResult:
	var snapshot_error := ExpeditionSession.snapshot_error(snapshot)
	if not snapshot_error.is_empty():
		return OperationResult.new(false, snapshot_error)
	var temp_path := config_path + ".tmp"
	var backup_path := config_path + ".bak"
	_remove_if_exists(temp_path)
	var config := ConfigFile.new()
	config.set_value("meta", "format_version", FORMAT_VERSION)
	config.set_value("meta", "content_version", CONTENT_VERSION)
	config.set_value("run", "snapshot", snapshot.duplicate(true))
	var error := config.save(_absolute(temp_path))
	if error != OK:
		return OperationResult.new(false, "无法写入远征临时存档：%s" % error)
	var verified := _load_path(temp_path)
	if not verified.accepted:
		_remove_if_exists(temp_path)
		return OperationResult.new(false, "远征临时存档校验失败：%s" % verified.reason)

	_remove_if_exists(backup_path)
	var had_existing := has_save()
	if had_existing:
		error = DirAccess.rename_absolute(
			_absolute(config_path),
			_absolute(backup_path)
		)
		if error != OK:
			_remove_if_exists(temp_path)
			return OperationResult.new(false, "无法准备替换远征存档：%s" % error)
	error = DirAccess.rename_absolute(_absolute(temp_path), _absolute(config_path))
	if error != OK:
		if had_existing:
			DirAccess.rename_absolute(
				_absolute(backup_path),
				_absolute(config_path)
			)
		_remove_if_exists(temp_path)
		return OperationResult.new(false, "无法替换远征存档：%s" % error)
	_remove_if_exists(backup_path)
	return OperationResult.new(true)

func load_snapshot() -> LoadResult:
	if not has_save():
		return LoadResult.new(false, "没有可继续的远征存档")
	return _load_path(config_path)

func clear() -> OperationResult:
	for suffix: String in ["", ".tmp", ".bak"]:
		var path: String = config_path + suffix
		if not FileAccess.file_exists(_absolute(path)):
			continue
		var error := DirAccess.remove_absolute(_absolute(path))
		if error != OK:
			return OperationResult.new(false, "无法清除远征存档：%s" % error)
	return OperationResult.new(true)

func archive_corrupt() -> OperationResult:
	if not has_save():
		return OperationResult.new(true)
	var loaded := load_snapshot()
	if loaded.accepted:
		return OperationResult.new(false, "合法远征存档不能作为损坏文件归档")
	var archive_path := "%s.corrupt-%d" % [config_path, Time.get_ticks_usec()]
	var error := DirAccess.rename_absolute(
		_absolute(config_path),
		_absolute(archive_path)
	)
	if error != OK:
		return OperationResult.new(false, "无法归档损坏远征存档：%s" % error)
	return OperationResult.new(true)

func _load_path(path: String) -> LoadResult:
	var config := ConfigFile.new()
	var error := config.load(_absolute(path))
	if error != OK:
		return LoadResult.new(false, "无法读取远征存档：%s" % error)
	var format_version: int = config.get_value("meta", "format_version", -1)
	var content_version: int = config.get_value("meta", "content_version", -1)
	if format_version not in [1, 2, FORMAT_VERSION]:
		return LoadResult.new(false, "远征存档版本不受支持")
	if (
		(format_version < FORMAT_VERSION and content_version != 1)
		or (format_version == FORMAT_VERSION and content_version != CONTENT_VERSION)
	):
		return LoadResult.new(false, "远征存档内容版本不受支持")
	var snapshot = config.get_value("run", "snapshot", null)
	if not snapshot is Dictionary:
		return LoadResult.new(false, "远征存档主体格式无效")
	if format_version == 1:
		snapshot = _migrate_v1_snapshot(snapshot)
	if format_version < FORMAT_VERSION:
		snapshot = _migrate_v2_snapshot(snapshot)
	var snapshot_error := ExpeditionSession.snapshot_error(snapshot)
	if not snapshot_error.is_empty():
		return LoadResult.new(false, snapshot_error)
	return LoadResult.new(true, "", snapshot.duplicate(true))

func _migrate_v1_snapshot(legacy: Dictionary) -> Dictionary:
	var snapshot := legacy.duplicate(true)
	var seed := int(snapshot.get("seed_value", 1))
	var area_index := int(snapshot.get("current_area_index", 0))
	snapshot["run_id"] = StringName("legacy-%d-%d" % [seed, area_index])
	snapshot["starting_deck_id"] = &"dice_control"
	snapshot["challenge_ids"] = []
	var inherited: Dictionary = snapshot.get("inherited_state", {}).duplicate(true)
	if (
		inherited.is_empty()
		and snapshot.get("status", ExpeditionSession.Status.NOT_STARTED)
		== ExpeditionSession.Status.ACTIVE
		and area_index == 0
	):
		var profiles: Array[Dictionary] = []
		for die_index in range(1, 7):
			profiles.append({
				"id": StringName("d%d" % die_index),
				"rolled_value": 1,
				"engraving_id": &"",
				"engraved_face": 0,
			})
		inherited = {
			"deck_ids": AreaCatalog.new().gold_corridor().starting_deck_ids.duplicate(),
			"intel_tickets": AreaCatalog.new().gold_corridor().starting_intel_tickets,
			"die_profiles": profiles,
			"rng_state": RunRng.new(seed).snapshot_state(),
			"challenge_ids": [],
		}
	elif not inherited.is_empty():
		inherited["challenge_ids"] = []
	snapshot["inherited_state"] = inherited
	var checkpoint: Dictionary = snapshot.get("area_checkpoint", {}).duplicate(true)
	if not checkpoint.is_empty():
		checkpoint["challenge_ids"] = []
		if checkpoint.has("shop") and checkpoint["shop"] is Dictionary:
			var shop: Dictionary = checkpoint["shop"].duplicate(true)
			shop["price_modifier"] = 0
			checkpoint["shop"] = shop
	snapshot["area_checkpoint"] = checkpoint
	return snapshot

func _migrate_v2_snapshot(legacy: Dictionary) -> Dictionary:
	var snapshot := legacy.duplicate(true)
	var checkpoint: Dictionary = snapshot.get("area_checkpoint", {}).duplicate(true)
	if not checkpoint.is_empty():
		checkpoint["area_retry_used"] = bool(checkpoint.get("area_retry_used", false))
		checkpoint["current_event_id"] = checkpoint.get("current_event_id", &"")
		checkpoint["event_history"] = checkpoint.get("event_history", [])
		checkpoint["next_encounter_calibration_bonus"] = int(
			checkpoint.get("next_encounter_calibration_bonus", 0)
		)
		if checkpoint.has("shop") and checkpoint["shop"] is Dictionary:
			var shop: Dictionary = checkpoint["shop"].duplicate(true)
			shop["remove_card_used"] = bool(shop.get("remove_card_used", false))
			shop["transfer_engraving_used"] = bool(
				shop.get("transfer_engraving_used", false)
			)
			shop["area_refresh_count"] = int(shop.get("area_refresh_count", 0))
			shop["rare_guarantee_unavailable_reason"] = String(
				shop.get("rare_guarantee_unavailable_reason", "")
			)
			checkpoint["shop"] = shop
	snapshot["area_checkpoint"] = checkpoint
	return snapshot

func _remove_if_exists(path: String) -> void:
	var absolute := _absolute(path)
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)

func _absolute(path: String) -> String:
	return ProjectSettings.globalize_path(path)
