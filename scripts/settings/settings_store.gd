class_name SettingsStore
extends RefCounted

const SCHEMA_VERSION := 1
const APPROVED_RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
]

var config_path := "user://settings.cfg"

func _init(p_config_path := "user://settings.cfg") -> void:
	config_path = p_config_path

func load_settings(defaults: Dictionary) -> Dictionary:
	var values := defaults.duplicate(true)
	var config := ConfigFile.new()
	var error := config.load(config_path)
	if error == ERR_FILE_NOT_FOUND:
		return {
			"values": values,
			"parse_failed": false,
			"error": "",
		}
	if error != OK:
		return {
			"values": values,
			"parse_failed": true,
			"error": "设置配置无法解析，已使用默认值",
		}
	var schema_value: Variant = config.get_value(
		"meta",
		"schema_version",
		SCHEMA_VERSION
	)
	if not _is_number(schema_value) or int(schema_value) != SCHEMA_VERSION:
		return {
			"values": values,
			"parse_failed": true,
			"error": "设置配置版本不受支持，已使用默认值",
		}

	var audio: Dictionary = values["audio"]
	for key in [
		"master_linear",
		"master_last_audible",
		"ui_linear",
		"ui_last_audible",
		"gameplay_linear",
		"gameplay_last_audible",
	]:
		var value: Variant = config.get_value("audio", key, audio[key])
		if _is_number(value):
			var number := float(value)
			var minimum := 0.0001 if key.ends_with("_last_audible") else 0.0
			if number >= minimum and number <= 1.0:
				audio[key] = number
	for key in ["master_muted", "ui_muted", "gameplay_muted"]:
		var value: Variant = config.get_value("audio", key, audio[key])
		if typeof(value) == TYPE_BOOL:
			audio[key] = value

	var display: Dictionary = values["display"]
	var mode: Variant = config.get_value(
		"display",
		"mode",
		display["mode"]
	)
	if typeof(mode) == TYPE_STRING and mode in ["windowed", "fullscreen"]:
		display["mode"] = mode
	var width: Variant = config.get_value(
		"display",
		"window_width",
		display["window_width"]
	)
	var height: Variant = config.get_value(
		"display",
		"window_height",
		display["window_height"]
	)
	if _is_number(width) and _is_number(height):
		var resolution := Vector2i(int(width), int(height))
		if resolution in APPROVED_RESOLUTIONS:
			display["window_width"] = resolution.x
			display["window_height"] = resolution.y
	var vsync: Variant = config.get_value(
		"display",
		"vsync_enabled",
		display["vsync_enabled"]
	)
	if typeof(vsync) == TYPE_BOOL:
		display["vsync_enabled"] = vsync

	return {
		"values": values,
		"parse_failed": false,
		"error": "",
	}

func save_settings(values: Dictionary) -> Dictionary:
	var config := ConfigFile.new()
	config.set_value("meta", "schema_version", SCHEMA_VERSION)
	var audio: Dictionary = values.get("audio", {})
	for key in [
		"master_linear",
		"master_muted",
		"master_last_audible",
		"ui_linear",
		"ui_muted",
		"ui_last_audible",
		"gameplay_linear",
		"gameplay_muted",
		"gameplay_last_audible",
	]:
		config.set_value("audio", key, audio.get(key))
	var display: Dictionary = values.get("display", {})
	for key in [
		"mode",
		"window_width",
		"window_height",
		"vsync_enabled",
	]:
		config.set_value("display", key, display.get(key))

	var temporary_path := "%s.tmp" % config_path
	var backup_path := "%s.bak" % config_path
	var temporary_absolute := ProjectSettings.globalize_path(temporary_path)
	var config_absolute := ProjectSettings.globalize_path(config_path)
	var backup_absolute := ProjectSettings.globalize_path(backup_path)
	var parent_directory := config_absolute.get_base_dir()
	var make_error := DirAccess.make_dir_recursive_absolute(parent_directory)
	if make_error != OK and make_error != ERR_ALREADY_EXISTS:
		return _save_error("无法创建设置目录")
	var save_error := config.save(temporary_path)
	if save_error != OK:
		return _save_error("无法写入设置临时文件")

	if FileAccess.file_exists(backup_absolute):
		DirAccess.remove_absolute(backup_absolute)
	var had_existing := FileAccess.file_exists(config_absolute)
	if had_existing:
		var backup_error := DirAccess.rename_absolute(
			config_absolute,
			backup_absolute
		)
		if backup_error != OK:
			DirAccess.remove_absolute(temporary_absolute)
			return _save_error("无法备份原设置文件")
	var replace_error := DirAccess.rename_absolute(
		temporary_absolute,
		config_absolute
	)
	if replace_error != OK:
		if had_existing and FileAccess.file_exists(backup_absolute):
			DirAccess.rename_absolute(backup_absolute, config_absolute)
		DirAccess.remove_absolute(temporary_absolute)
		return _save_error("无法替换设置文件")
	if FileAccess.file_exists(backup_absolute):
		DirAccess.remove_absolute(backup_absolute)
	return {
		"ok": true,
		"error": "",
	}

func _is_number(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT]

func _save_error(message: String) -> Dictionary:
	return {
		"ok": false,
		"error": message,
	}
