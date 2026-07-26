class_name GoldCorridorGuideProgressStore
extends RefCounted

const SECTION := "gold_corridor_guide_v1"
const DISMISSED_KEY := "dismissed"
const CHECKPOINT_KEY_BY_ID := {
	&"route": "seen_route",
	&"shop": "seen_shop",
	&"dealer": "seen_dealer",
	&"engraving": "seen_engraving",
}

var config_path: String
var _values: Dictionary = {}
var _initial_error: Error = OK
var _write_blocked := false

func _init(path: String = "user://onboarding.cfg") -> void:
	config_path = path
	_values = _default_values()
	_load_existing()

func snapshot() -> Dictionary:
	return _values.duplicate(true)

func initial_load_error() -> Error:
	return _initial_error

func is_dismissed() -> bool:
	return bool(_values.get(DISMISSED_KEY, false))

func is_seen(checkpoint_id: StringName) -> bool:
	if not CHECKPOINT_KEY_BY_ID.has(checkpoint_id):
		return false
	return bool(_values.get(CHECKPOINT_KEY_BY_ID[checkpoint_id], false))

func mark_seen(checkpoint_id: StringName) -> Error:
	if not CHECKPOINT_KEY_BY_ID.has(checkpoint_id):
		return ERR_INVALID_PARAMETER
	_values[CHECKPOINT_KEY_BY_ID[checkpoint_id]] = true
	return _persist()

func dismiss_all() -> Error:
	_values[DISMISSED_KEY] = true
	return _persist()

func reset() -> Error:
	_values = _default_values()
	return _persist()

func _default_values() -> Dictionary:
	var values := {DISMISSED_KEY: false}
	for key in CHECKPOINT_KEY_BY_ID.values():
		values[key] = false
	return values

func _load_existing() -> void:
	var config := ConfigFile.new()
	var result := config.load(config_path)
	if result == ERR_FILE_NOT_FOUND:
		return
	if result != OK:
		_initial_error = result
		_write_blocked = true
		return
	_values[DISMISSED_KEY] = bool(config.get_value(SECTION, DISMISSED_KEY, false))
	for key in CHECKPOINT_KEY_BY_ID.values():
		_values[key] = bool(config.get_value(SECTION, key, false))

func _persist() -> Error:
	if _write_blocked:
		return _initial_error
	var config := ConfigFile.new()
	var load_result := config.load(config_path)
	if load_result != OK and load_result != ERR_FILE_NOT_FOUND:
		_initial_error = load_result
		_write_blocked = true
		return load_result
	config.set_value(SECTION, DISMISSED_KEY, is_dismissed())
	for key in CHECKPOINT_KEY_BY_ID.values():
		config.set_value(SECTION, key, bool(_values.get(key, false)))
	return config.save(config_path)
