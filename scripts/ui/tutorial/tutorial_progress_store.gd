class_name TutorialProgressStore
extends RefCounted

const SECTION := "onboarding"
const DONE_KEY := "done"

var config_path: String

func _init(path: String = "user://onboarding.cfg") -> void:
	config_path = path

func is_done() -> bool:
	var config := ConfigFile.new()
	if config.load(config_path) != OK:
		return false
	return bool(config.get_value(SECTION, DONE_KEY, false))

func mark_done() -> Error:
	return _save(true)

func reset() -> Error:
	return _save(false)

func _save(value: bool) -> Error:
	var config := ConfigFile.new()
	config.set_value(SECTION, DONE_KEY, value)
	return config.save(config_path)
