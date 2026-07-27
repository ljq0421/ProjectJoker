extends Node

signal audio_changed(channel: StringName)
signal preview_requested(cue_id: StringName)
signal display_draft_changed
signal display_confirmation_changed(active: bool, seconds_remaining: int)
signal settings_error(message: String)

const DEFAULT_CONFIRMATION_SECONDS := 10.0
const CHANNELS := {
	&"master": {
		"bus": &"Master",
		"linear": "master_linear",
		"muted": "master_muted",
		"last_audible": "master_last_audible",
		"preview": &"ui_confirm",
	},
	&"ui": {
		"bus": &"UI",
		"linear": "ui_linear",
		"muted": "ui_muted",
		"last_audible": "ui_last_audible",
		"preview": &"ui_confirm",
	},
	&"gameplay": {
		"bus": &"Gameplay",
		"linear": "gameplay_linear",
		"muted": "gameplay_muted",
		"last_audible": "gameplay_last_audible",
		"preview": &"die_place",
	},
}
const DEFAULT_SETTINGS := {
	"audio": {
		"master_linear": 1.0,
		"master_muted": false,
		"master_last_audible": 1.0,
		"ui_linear": 0.501187,
		"ui_muted": false,
		"ui_last_audible": 0.501187,
		"gameplay_linear": 0.794328,
		"gameplay_muted": false,
		"gameplay_last_audible": 0.794328,
	},
	"display": {
		"mode": "windowed",
		"window_width": 1280,
		"window_height": 720,
		"vsync_enabled": true,
	},
}

var _store: RefCounted
var _display_adapter: RefCounted
var _settings: Dictionary = DEFAULT_SETTINGS.duplicate(true)
var _display_draft: Dictionary = DEFAULT_SETTINGS["display"].duplicate(true)
var _display_snapshot: Dictionary = {}
var _confirmation_active := false
var _confirmation_remaining := 0.0
var _confirmation_seconds := DEFAULT_CONFIRMATION_SECONDS
var _last_confirmation_second := -1
var _last_error := ""

func configure_for_test(
	store: RefCounted,
	display_adapter: RefCounted,
	confirmation_seconds := DEFAULT_CONFIRMATION_SECONDS
) -> void:
	_store = store
	_display_adapter = display_adapter
	_confirmation_seconds = maxf(0.01, confirmation_seconds)
	if is_node_ready():
		_load_from_store()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _store == null:
		_store = SettingsStore.new()
	if _display_adapter == null:
		_display_adapter = DisplaySettingsAdapter.new()
	_load_from_store()
	call_deferred("_apply_confirmed_display_on_startup")

func _load_from_store() -> void:
	var load_result: Dictionary = _store.load_settings(DEFAULT_SETTINGS)
	_settings = (
		load_result.get("values", DEFAULT_SETTINGS).duplicate(true)
	)
	_display_draft = _settings["display"].duplicate(true)
	_clear_display_confirmation()
	_apply_all_audio()
	if bool(load_result.get("parse_failed", false)):
		_report_error(String(load_result.get("error", "设置配置无法解析")))

func _process(delta: float) -> void:
	if not _confirmation_active:
		return
	_confirmation_remaining = maxf(0.0, _confirmation_remaining - delta)
	var visible_second := ceili(_confirmation_remaining)
	if visible_second != _last_confirmation_second:
		_last_confirmation_second = visible_second
		display_confirmation_changed.emit(true, visible_second)
	if _confirmation_remaining <= 0.0:
		revert_display_settings()

func settings_snapshot() -> Dictionary:
	return _settings.duplicate(true)

func default_settings() -> Dictionary:
	return DEFAULT_SETTINGS.duplicate(true)

func last_error() -> String:
	return _last_error

func audio_linear(channel: StringName) -> float:
	if not CHANNELS.has(channel):
		return 0.0
	var definition: Dictionary = CHANNELS[channel]
	return float(
		_settings["audio"].get(String(definition["linear"]), 0.0)
	)

func audio_percent(channel: StringName) -> int:
	return roundi(audio_linear(channel) * 100.0)

func audio_muted(channel: StringName) -> bool:
	if not CHANNELS.has(channel):
		return false
	var definition: Dictionary = CHANNELS[channel]
	return bool(
		_settings["audio"].get(String(definition["muted"]), false)
	)

func audio_last_audible(channel: StringName) -> float:
	if not CHANNELS.has(channel):
		return 0.0
	var definition: Dictionary = CHANNELS[channel]
	return float(
		_settings["audio"].get(
			String(definition["last_audible"]),
			0.0
		)
	)

func set_audio_linear(channel: StringName, value: float) -> bool:
	if not CHANNELS.has(channel):
		_report_error("未知声音设置：%s" % channel)
		return false
	var definition: Dictionary = CHANNELS[channel]
	var audio: Dictionary = _settings["audio"]
	var linear_key := String(definition["linear"])
	var muted_key := String(definition["muted"])
	var last_audible_key := String(definition["last_audible"])
	var clamped := clampf(value, 0.0, 1.0)
	audio[linear_key] = clamped
	if clamped > 0.0:
		audio[last_audible_key] = clamped
		audio[muted_key] = false
	if not _apply_audio_channel(channel):
		return false
	audio_changed.emit(channel)
	return true

func finish_audio_adjustment(channel: StringName) -> bool:
	if not CHANNELS.has(channel):
		return false
	var saved := _save_current()
	if audio_linear(channel) > 0.0 and not audio_muted(channel):
		var definition: Dictionary = CHANNELS[channel]
		preview_requested.emit(StringName(definition["preview"]))
	return saved

func set_audio_muted(channel: StringName, muted: bool) -> bool:
	if not CHANNELS.has(channel):
		_report_error("未知声音设置：%s" % channel)
		return false
	var definition: Dictionary = CHANNELS[channel]
	var audio: Dictionary = _settings["audio"]
	var linear_key := String(definition["linear"])
	var muted_key := String(definition["muted"])
	var last_audible_key := String(definition["last_audible"])
	if not muted and float(audio[linear_key]) <= 0.0:
		audio[linear_key] = float(audio[last_audible_key])
	audio[muted_key] = muted
	if not _apply_audio_channel(channel):
		return false
	audio_changed.emit(channel)
	var saved := _save_current()
	if not muted:
		preview_requested.emit(StringName(definition["preview"]))
	return saved

func restore_audio_defaults() -> bool:
	_settings["audio"] = DEFAULT_SETTINGS["audio"].duplicate(true)
	_apply_all_audio()
	for channel in CHANNELS:
		audio_changed.emit(channel)
	var saved := _save_current()
	preview_requested.emit(&"ui_confirm")
	return saved

func confirmed_display() -> Dictionary:
	return _settings["display"].duplicate(true)

func display_draft() -> Dictionary:
	return _display_draft.duplicate(true)

func begin_display_draft() -> Dictionary:
	if not _confirmation_active:
		_display_draft = _settings["display"].duplicate(true)
	display_draft_changed.emit()
	return display_draft()

func set_display_draft_mode(mode: String) -> bool:
	if mode not in ["windowed", "fullscreen"]:
		_report_error("不支持的显示模式")
		return false
	_display_draft["mode"] = mode
	display_draft_changed.emit()
	return true

func set_display_draft_resolution(resolution: Vector2i) -> bool:
	if resolution not in SettingsStore.APPROVED_RESOLUTIONS:
		_report_error("不支持的窗口分辨率")
		return false
	_display_draft["window_width"] = resolution.x
	_display_draft["window_height"] = resolution.y
	display_draft_changed.emit()
	return true

func set_display_draft_vsync(enabled: bool) -> void:
	_display_draft["vsync_enabled"] = enabled
	display_draft_changed.emit()

func restore_display_defaults() -> void:
	_display_draft = DEFAULT_SETTINGS["display"].duplicate(true)
	display_draft_changed.emit()

func discard_display_draft() -> void:
	if _confirmation_active:
		revert_display_settings()
		return
	_display_draft = _settings["display"].duplicate(true)
	display_draft_changed.emit()

func available_resolutions() -> Array[Vector2i]:
	var values: Array[Vector2i] = []
	for value in _display_adapter.available_resolutions():
		values.append(value)
	return values

func can_apply_display_draft() -> bool:
	if String(_display_draft.get("mode", "windowed")) == "fullscreen":
		return true
	var resolution := Vector2i(
		int(_display_draft.get("window_width", 1280)),
		int(_display_draft.get("window_height", 720))
	)
	return resolution in available_resolutions()

func apply_display_draft() -> bool:
	if _confirmation_active:
		return false
	if not can_apply_display_draft():
		_report_error("当前屏幕不足以容纳所选窗口分辨率")
		return false
	_display_snapshot = _display_adapter.snapshot().duplicate(true)
	var result: Dictionary = _display_adapter.apply_settings(_display_draft)
	if not bool(result.get("ok", false)):
		_display_adapter.restore(_display_snapshot)
		_display_snapshot = {}
		_report_error(String(result.get("error", "显示设置应用失败")))
		return false
	_confirmation_active = true
	_confirmation_remaining = _confirmation_seconds
	_last_confirmation_second = ceili(_confirmation_remaining)
	display_confirmation_changed.emit(
		true,
		_last_confirmation_second
	)
	return true

func display_confirmation_active() -> bool:
	return _confirmation_active

func display_confirmation_seconds_remaining() -> int:
	return ceili(_confirmation_remaining) if _confirmation_active else 0

func confirm_display_settings() -> bool:
	if not _confirmation_active:
		return false
	var candidate := _settings.duplicate(true)
	candidate["display"] = _display_draft.duplicate(true)
	var result: Dictionary = _store.save_settings(candidate)
	if not bool(result.get("ok", false)):
		_display_adapter.restore(_display_snapshot)
		_clear_display_confirmation()
		_display_draft = _settings["display"].duplicate(true)
		_report_error(String(result.get("error", "显示设置保存失败")))
		display_draft_changed.emit()
		return false
	_settings = candidate
	_clear_display_confirmation()
	display_draft_changed.emit()
	return true

func revert_display_settings() -> bool:
	if not _confirmation_active:
		_display_draft = _settings["display"].duplicate(true)
		display_draft_changed.emit()
		return false
	var result: Dictionary = _display_adapter.restore(_display_snapshot)
	var restored := bool(result.get("ok", false))
	_clear_display_confirmation()
	_display_draft = _settings["display"].duplicate(true)
	display_draft_changed.emit()
	if not restored:
		_report_error(String(result.get("error", "原显示设置恢复失败")))
	return restored

func _apply_all_audio() -> void:
	for channel in CHANNELS:
		_apply_audio_channel(channel)

func _apply_audio_channel(channel: StringName) -> bool:
	var definition: Dictionary = CHANNELS[channel]
	var bus_name := StringName(definition["bus"])
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		_report_error("缺少声音总线：%s" % bus_name)
		return false
	var linear := audio_linear(channel)
	AudioServer.set_bus_volume_db(
		bus_index,
		linear_to_db(linear) if linear > 0.0 else -80.0
	)
	AudioServer.set_bus_mute(bus_index, audio_muted(channel))
	return true

func _apply_confirmed_display_on_startup() -> void:
	var startup_display: Dictionary = _settings["display"].duplicate(true)
	if String(startup_display.get("mode", "windowed")) == "windowed":
		var requested := Vector2i(
			int(startup_display.get("window_width", 1280)),
			int(startup_display.get("window_height", 720))
		)
		var available := available_resolutions()
		if requested not in available:
			if available.is_empty():
				_report_error("当前屏幕不足以容纳最低窗口分辨率")
				return
			var fallback: Vector2i = available[-1]
			startup_display["window_width"] = fallback.x
			startup_display["window_height"] = fallback.y
	var result: Dictionary = _display_adapter.apply_settings(startup_display)
	if not bool(result.get("ok", false)):
		_report_error(String(result.get("error", "启动显示设置应用失败")))

func _save_current() -> bool:
	var result: Dictionary = _store.save_settings(_settings)
	if bool(result.get("ok", false)):
		return true
	_report_error(String(result.get("error", "设置保存失败")))
	return false

func _clear_display_confirmation() -> void:
	_confirmation_active = false
	_confirmation_remaining = 0.0
	_last_confirmation_second = -1
	_display_snapshot = {}
	display_confirmation_changed.emit(false, 0)

func _report_error(message: String) -> void:
	_last_error = message
	settings_error.emit(message)
