class_name DisplaySettingsAdapter
extends RefCounted

func snapshot() -> Dictionary:
	return {
		"mode": _mode_name(DisplayServer.window_get_mode()),
		"window_size": DisplayServer.window_get_size(),
		"window_position": DisplayServer.window_get_position(),
		"vsync_enabled": (
			DisplayServer.window_get_vsync_mode()
			!= DisplayServer.VSYNC_DISABLED
		),
	}

func available_resolutions() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var screen := DisplayServer.window_get_current_screen()
	var usable := DisplayServer.screen_get_usable_rect(screen).size
	for resolution in SettingsStore.APPROVED_RESOLUTIONS:
		if resolution.x <= usable.x and resolution.y <= usable.y:
			result.append(resolution)
	return result

func apply_settings(settings: Dictionary) -> Dictionary:
	var mode := String(settings.get("mode", "windowed"))
	var vsync_enabled := bool(settings.get("vsync_enabled", true))
	if mode == "windowed":
		var size := Vector2i(
			int(settings.get("window_width", 1280)),
			int(settings.get("window_height", 720))
		)
		if size not in available_resolutions():
			return {
				"ok": false,
				"error": "当前屏幕不足以容纳所选窗口分辨率",
			}
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(size)
		_center_window(size)
	elif mode == "fullscreen":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		return {
			"ok": false,
			"error": "不支持的显示模式",
		}

	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED
		if vsync_enabled
		else DisplayServer.VSYNC_DISABLED
	)
	DisplayServer.process_events()
	var readback := snapshot()
	if readback["mode"] != mode:
		return {
			"ok": false,
			"error": "窗口模式未能正确应用",
		}
	if mode == "windowed":
		var expected_size := Vector2i(
			int(settings.get("window_width", 1280)),
			int(settings.get("window_height", 720))
		)
		if readback["window_size"] != expected_size:
			return {
				"ok": false,
				"error": "窗口分辨率未能正确应用",
			}
	if readback["vsync_enabled"] != vsync_enabled:
		return {
			"ok": false,
			"error": "当前平台或渲染器不支持所选垂直同步状态",
		}
	return {
		"ok": true,
		"error": "",
	}

func restore(snapshot_values: Dictionary) -> Dictionary:
	var mode := String(snapshot_values.get("mode", "windowed"))
	var size: Vector2i = snapshot_values.get(
		"window_size",
		Vector2i(1280, 720)
	)
	var position: Vector2i = snapshot_values.get(
		"window_position",
		DisplayServer.window_get_position()
	)
	if mode == "fullscreen":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(size)
		DisplayServer.window_set_position(position)
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED
		if bool(snapshot_values.get("vsync_enabled", true))
		else DisplayServer.VSYNC_DISABLED
	)
	DisplayServer.process_events()
	var readback := snapshot()
	if readback["mode"] != mode:
		return {"ok": false, "error": "原窗口模式恢复失败"}
	if mode == "windowed" and readback["window_size"] != size:
		return {"ok": false, "error": "原窗口尺寸恢复失败"}
	if (
		readback["vsync_enabled"]
		!= bool(snapshot_values.get("vsync_enabled", true))
	):
		return {"ok": false, "error": "原垂直同步状态恢复失败"}
	return {"ok": true, "error": ""}

func _center_window(size: Vector2i) -> void:
	var screen := DisplayServer.window_get_current_screen()
	var usable_rect := DisplayServer.screen_get_usable_rect(screen)
	var position := usable_rect.position + (usable_rect.size - size) / 2
	DisplayServer.window_set_position(position)

func _mode_name(mode: DisplayServer.WindowMode) -> String:
	return (
		"fullscreen"
		if mode in [
			DisplayServer.WINDOW_MODE_FULLSCREEN,
			DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN,
		]
		else "windowed"
	)
