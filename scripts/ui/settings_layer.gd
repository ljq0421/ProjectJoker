class_name SettingsLayer
extends CanvasLayer

const AUDIO_CHANNELS: Array[StringName] = [
	&"master",
	&"music",
	&"ui",
	&"gameplay",
]
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
]
const ACTIVE_LAYER_GROUP := &"active_settings_layer"
const ENTRY_BLOCKER_GROUP := &"settings_entry_blocker"

@onready var settings_button: Button = %SettingsButton
@onready var overlay: Control = %SettingsOverlay
@onready var audio_tab_button: Button = %AudioTabButton
@onready var display_tab_button: Button = %DisplayTabButton
@onready var accessibility_tab_button: Button = %AccessibilityTabButton
@onready var audio_page: Control = %AudioPage
@onready var display_page: Control = %DisplayPage
@onready var accessibility_page: Control = %AccessibilityPage
@onready var master_slider: HSlider = %MasterSlider
@onready var music_slider: HSlider = %MusicSlider
@onready var ui_slider: HSlider = %UiSlider
@onready var gameplay_slider: HSlider = %GameplaySlider
@onready var master_value_label: Label = %MasterValueLabel
@onready var music_value_label: Label = %MusicValueLabel
@onready var ui_value_label: Label = %UiValueLabel
@onready var gameplay_value_label: Label = %GameplayValueLabel
@onready var master_mute_check: CheckButton = %MasterMuteCheck
@onready var music_mute_check: CheckButton = %MusicMuteCheck
@onready var ui_mute_check: CheckButton = %UiMuteCheck
@onready var gameplay_mute_check: CheckButton = %GameplayMuteCheck
@onready var mode_option: OptionButton = %DisplayModeOption
@onready var resolution_option: OptionButton = %ResolutionOption
@onready var vsync_check: CheckButton = %VsyncCheck
@onready var display_hint_label: Label = %DisplayHintLabel
@onready var apply_display_button: Button = %ApplyDisplayButton
@onready var status_label: Label = %SettingsStatusLabel
@onready var confirmation_layer: Control = %DisplayConfirmationLayer
@onready var confirmation_countdown_label: Label = %ConfirmationCountdownLabel
@onready var reduce_flashes_check: CheckButton = %ReduceFlashesCheck
@onready var disable_distortion_check: CheckButton = %DisableDistortionCheck
@onready var resolution_speed_option: OptionButton = %ResolutionSpeedOption
@onready var ui_scale_option: OptionButton = %UiScaleOption

var _settings_service: Node
var _previous_tree_paused := false
var _open := false
var _refreshing := false
var _entry_blockers: Array[CanvasItem] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var active_layer := get_tree().get_first_node_in_group(ACTIVE_LAYER_GROUP)
	if active_layer != null and active_layer != self:
		settings_button.visible = false
		overlay.visible = false
		process_mode = Node.PROCESS_MODE_DISABLED
		return
	add_to_group(ACTIVE_LAYER_GROUP)
	_settings_service = get_node_or_null("/root/SettingsService")
	_bind_controls()
	_populate_display_options()
	_populate_accessibility_options()
	overlay.visible = false
	confirmation_layer.visible = false
	settings_button.visible = true
	_show_audio_page(false)
	if _settings_service != null:
		_bind_service()
		_refresh_all()
	else:
		status_label.text = "设置服务不可用"
	call_deferred("_bind_entry_blockers")

func open_settings() -> void:
	if _open:
		return
	_settings_service = get_node_or_null("/root/SettingsService")
	if _settings_service == null:
		status_label.text = "设置服务不可用"
		return
	_previous_tree_paused = get_tree().paused
	_open = true
	layer = 100
	settings_button.visible = false
	overlay.visible = true
	_settings_service.call("begin_display_draft")
	_refresh_all()
	get_tree().paused = true
	audio_tab_button.grab_focus()
	SfxAccess.play(self, &"panel_open")

func close_settings() -> void:
	if not _open:
		return
	if (
		_settings_service != null
		and bool(_settings_service.call("display_confirmation_active"))
	):
		_settings_service.call("revert_display_settings")
	if _settings_service != null:
		_settings_service.call("discard_display_draft")
	confirmation_layer.visible = false
	overlay.visible = false
	_open = false
	layer = 0
	_update_entry_visibility()
	get_tree().paused = _previous_tree_paused
	settings_button.grab_focus()
	SfxAccess.play(self, &"panel_close")

func is_open() -> bool:
	return _open

func _input(event: InputEvent) -> void:
	if (
		_open
		and event.is_action_pressed("ui_cancel")
		and not event.is_echo()
	):
		close_settings()
		get_viewport().set_input_as_handled()

func _bind_controls() -> void:
	settings_button.pressed.connect(open_settings)
	%CloseSettingsButton.pressed.connect(close_settings)
	audio_tab_button.pressed.connect(func() -> void: _show_audio_page(true))
	display_tab_button.pressed.connect(
		func() -> void: _show_display_page(true)
	)
	accessibility_tab_button.pressed.connect(
		func() -> void: _show_accessibility_page(true)
	)

	for channel in AUDIO_CHANNELS:
		var slider := _slider_for(channel)
		var mute_check := _mute_check_for(channel)
		slider.value_changed.connect(
			func(value: float) -> void:
				_on_audio_value_changed(channel, value)
		)
		slider.drag_ended.connect(
			func(_value_changed: bool) -> void:
				_on_audio_drag_ended(channel)
		)
		mute_check.toggled.connect(
			func(muted: bool) -> void:
				_on_audio_muted(channel, muted)
		)

	%RestoreAudioDefaultsButton.pressed.connect(_on_restore_audio_defaults)
	mode_option.item_selected.connect(_on_display_mode_selected)
	resolution_option.item_selected.connect(_on_resolution_selected)
	vsync_check.toggled.connect(_on_vsync_toggled)
	%RestoreDisplayDefaultsButton.pressed.connect(
		_on_restore_display_defaults
	)
	apply_display_button.pressed.connect(_on_apply_display)
	%KeepDisplayButton.pressed.connect(_on_keep_display)
	%RevertDisplayButton.pressed.connect(_on_revert_display)
	reduce_flashes_check.toggled.connect(
		func(enabled: bool) -> void:
			_on_accessibility_changed(&"reduce_flashes", enabled)
	)
	disable_distortion_check.toggled.connect(
		func(enabled: bool) -> void:
			_on_accessibility_changed(&"disable_distortion", enabled)
	)
	resolution_speed_option.item_selected.connect(
		_on_resolution_speed_selected
	)
	ui_scale_option.item_selected.connect(_on_ui_scale_selected)
	%RestoreAccessibilityDefaultsButton.pressed.connect(
		_on_restore_accessibility_defaults
	)

func _bind_service() -> void:
	_settings_service.connect(
		"audio_changed",
		Callable(self, "_on_service_audio_changed")
	)
	_settings_service.connect(
		"preview_requested",
		Callable(self, "_on_preview_requested")
	)
	_settings_service.connect(
		"display_draft_changed",
		Callable(self, "_on_display_draft_changed")
	)
	_settings_service.connect(
		"display_confirmation_changed",
		Callable(self, "_on_display_confirmation_changed")
	)
	_settings_service.connect(
		"settings_error",
		Callable(self, "_on_settings_error")
	)
	_settings_service.connect(
		"accessibility_changed",
		Callable(self, "_on_service_accessibility_changed")
	)

func _bind_entry_blockers() -> void:
	_entry_blockers.clear()
	for node in get_tree().get_nodes_in_group(ENTRY_BLOCKER_GROUP):
		if node is not CanvasItem:
			continue
		var blocker := node as CanvasItem
		_entry_blockers.append(blocker)
		if not blocker.visibility_changed.is_connected(
			_update_entry_visibility
		):
			blocker.visibility_changed.connect(_update_entry_visibility)
	_update_entry_visibility()

func _update_entry_visibility() -> void:
	if _open or process_mode == Node.PROCESS_MODE_DISABLED:
		settings_button.visible = false
		return
	for blocker in _entry_blockers:
		if is_instance_valid(blocker) and blocker.is_visible_in_tree():
			settings_button.visible = false
			return
	settings_button.visible = true

func _populate_display_options() -> void:
	mode_option.clear()
	mode_option.add_item("窗口")
	mode_option.set_item_metadata(0, "windowed")
	mode_option.add_item("全屏")
	mode_option.set_item_metadata(1, "fullscreen")
	resolution_option.clear()
	for resolution in RESOLUTIONS:
		resolution_option.add_item("%d × %d" % [resolution.x, resolution.y])
		resolution_option.set_item_metadata(
			resolution_option.item_count - 1,
			resolution
		)

func _populate_accessibility_options() -> void:
	resolution_speed_option.clear()
	for item in [
		["正常", "normal"],
		["快速", "fast"],
		["立即", "instant"],
	]:
		resolution_speed_option.add_item(item[0])
		resolution_speed_option.set_item_metadata(
			resolution_speed_option.item_count - 1,
			item[1]
		)
	ui_scale_option.clear()
	for percent in [100, 110, 125]:
		ui_scale_option.add_item("%d%%" % percent)
		ui_scale_option.set_item_metadata(
			ui_scale_option.item_count - 1,
			percent
		)

func _show_audio_page(play_sound: bool) -> void:
	var changed := not audio_page.visible
	audio_page.visible = true
	display_page.visible = false
	accessibility_page.visible = false
	audio_tab_button.button_pressed = true
	display_tab_button.button_pressed = false
	accessibility_tab_button.button_pressed = false
	if play_sound and changed:
		SfxAccess.play(self, &"ui_confirm")

func _show_display_page(play_sound: bool) -> void:
	var changed := not display_page.visible
	audio_page.visible = false
	display_page.visible = true
	accessibility_page.visible = false
	audio_tab_button.button_pressed = false
	display_tab_button.button_pressed = true
	accessibility_tab_button.button_pressed = false
	if play_sound and changed:
		SfxAccess.play(self, &"ui_confirm")

func _show_accessibility_page(play_sound: bool) -> void:
	var changed := not accessibility_page.visible
	audio_page.visible = false
	display_page.visible = false
	accessibility_page.visible = true
	audio_tab_button.button_pressed = false
	display_tab_button.button_pressed = false
	accessibility_tab_button.button_pressed = true
	if play_sound and changed:
		SfxAccess.play(self, &"ui_confirm")

func _on_audio_value_changed(channel: StringName, value: float) -> void:
	if _refreshing or _settings_service == null:
		return
	_settings_service.call("set_audio_linear", channel, value / 100.0)
	_refresh_audio_channel(channel)

func _on_audio_drag_ended(channel: StringName) -> void:
	if _settings_service == null:
		return
	_settings_service.call("finish_audio_adjustment", channel)

func _on_audio_muted(channel: StringName, muted: bool) -> void:
	if _refreshing or _settings_service == null:
		return
	if muted:
		SfxAccess.play(self, &"ui_confirm")
	_settings_service.call("set_audio_muted", channel, muted)
	_refresh_audio_channel(channel)

func _on_restore_audio_defaults() -> void:
	if _settings_service == null:
		return
	_settings_service.call("restore_audio_defaults")
	_refresh_audio()

func _on_display_mode_selected(index: int) -> void:
	if _refreshing or _settings_service == null:
		return
	_settings_service.call(
		"set_display_draft_mode",
		String(mode_option.get_item_metadata(index))
	)

func _on_resolution_selected(index: int) -> void:
	if _refreshing or _settings_service == null:
		return
	_settings_service.call(
		"set_display_draft_resolution",
		resolution_option.get_item_metadata(index)
	)

func _on_vsync_toggled(enabled: bool) -> void:
	if _refreshing or _settings_service == null:
		return
	_settings_service.call("set_display_draft_vsync", enabled)

func _on_restore_display_defaults() -> void:
	if _settings_service == null:
		return
	_settings_service.call("restore_display_defaults")
	SfxAccess.play(self, &"ui_confirm")

func _on_apply_display() -> void:
	if _settings_service == null:
		return
	status_label.text = ""
	if bool(_settings_service.call("apply_display_draft")):
		SfxAccess.play(self, &"ui_confirm")

func _on_keep_display() -> void:
	if _settings_service == null:
		return
	if bool(_settings_service.call("confirm_display_settings")):
		SfxAccess.play(self, &"ui_confirm")

func _on_revert_display() -> void:
	if _settings_service == null:
		return
	if bool(_settings_service.call("revert_display_settings")):
		SfxAccess.play(self, &"ui_back")

func _on_accessibility_changed(key: StringName, value: Variant) -> void:
	if _refreshing or _settings_service == null:
		return
	if bool(
		_settings_service.call("set_accessibility_value", key, value)
	):
		SfxAccess.play(self, &"ui_confirm")

func _on_resolution_speed_selected(index: int) -> void:
	if _refreshing:
		return
	_on_accessibility_changed(
		&"resolution_speed",
		String(resolution_speed_option.get_item_metadata(index))
	)

func _on_ui_scale_selected(index: int) -> void:
	if _refreshing:
		return
	_on_accessibility_changed(
		&"ui_scale_percent",
		int(ui_scale_option.get_item_metadata(index))
	)

func _on_restore_accessibility_defaults() -> void:
	if _settings_service == null:
		return
	if bool(_settings_service.call("restore_accessibility_defaults")):
		_refresh_accessibility()
		SfxAccess.play(self, &"ui_confirm")

func _on_service_audio_changed(channel: StringName) -> void:
	_refresh_audio_channel(channel)

func _on_preview_requested(cue_id: StringName) -> void:
	SfxAccess.play(self, cue_id)

func _on_service_accessibility_changed(_key: StringName) -> void:
	_refresh_accessibility()

func _on_display_draft_changed() -> void:
	_refresh_display()

func _on_display_confirmation_changed(
	active: bool,
	seconds_remaining: int
) -> void:
	confirmation_layer.visible = active
	confirmation_countdown_label.text = (
		"%d 秒后自动恢复" % seconds_remaining
		if active
		else ""
	)
	if active:
		%KeepDisplayButton.grab_focus()

func _on_settings_error(message: String) -> void:
	status_label.text = message
	if _open and not message.is_empty():
		SfxAccess.play(self, &"error")

func _refresh_all() -> void:
	if _settings_service == null:
		return
	_refresh_audio()
	_refresh_display()
	_refresh_accessibility()
	var service_error := String(_settings_service.call("last_error"))
	if not service_error.is_empty():
		status_label.text = service_error

func _refresh_audio() -> void:
	for channel in AUDIO_CHANNELS:
		_refresh_audio_channel(channel)

func _refresh_audio_channel(channel: StringName) -> void:
	if _settings_service == null:
		return
	_refreshing = true
	var percent := int(_settings_service.call("audio_percent", channel))
	_slider_for(channel).value = percent
	_value_label_for(channel).text = "%d%%" % percent
	_mute_check_for(channel).button_pressed = bool(
		_settings_service.call("audio_muted", channel)
	)
	_refreshing = false

func _refresh_display() -> void:
	if _settings_service == null:
		return
	_refreshing = true
	var draft: Dictionary = _settings_service.call("display_draft")
	var mode := String(draft.get("mode", "windowed"))
	mode_option.select(0 if mode == "windowed" else 1)
	var available: Array[Vector2i] = []
	for value in _settings_service.call("available_resolutions"):
		available.append(value)
	var selected_resolution := Vector2i(
		int(draft.get("window_width", 1280)),
		int(draft.get("window_height", 720))
	)
	for index in range(resolution_option.item_count):
		var resolution: Vector2i = resolution_option.get_item_metadata(index)
		resolution_option.set_item_disabled(
			index,
			mode == "fullscreen" or resolution not in available
		)
		if resolution == selected_resolution:
			resolution_option.select(index)
	resolution_option.disabled = mode == "fullscreen" or available.is_empty()
	display_hint_label.text = (
		"全屏分辨率跟随当前显示器"
		if mode == "fullscreen"
		else (
			"当前屏幕不足以容纳最低窗口分辨率"
			if available.is_empty()
			else "窗口模式将使用所选 16:9 分辨率"
		)
	)
	vsync_check.button_pressed = bool(
		draft.get("vsync_enabled", true)
	)
	apply_display_button.disabled = not bool(
		_settings_service.call("can_apply_display_draft")
	)
	_refreshing = false

func _refresh_accessibility() -> void:
	if _settings_service == null:
		return
	_refreshing = true
	reduce_flashes_check.button_pressed = bool(
		_settings_service.call(
			"accessibility_value",
			&"reduce_flashes"
		)
	)
	disable_distortion_check.button_pressed = bool(
		_settings_service.call(
			"accessibility_value",
			&"disable_distortion"
		)
	)
	_select_option_by_metadata(
		resolution_speed_option,
		String(
			_settings_service.call(
				"accessibility_value",
				&"resolution_speed"
			)
		)
	)
	_select_option_by_metadata(
		ui_scale_option,
		int(
			_settings_service.call(
				"accessibility_value",
				&"ui_scale_percent"
			)
		)
	)
	_refreshing = false

func _select_option_by_metadata(option: OptionButton, value: Variant) -> void:
	for index in range(option.item_count):
		if option.get_item_metadata(index) == value:
			option.select(index)
			return

func _slider_for(channel: StringName) -> HSlider:
	match channel:
		&"master":
			return master_slider
		&"music":
			return music_slider
		&"ui":
			return ui_slider
		_:
			return gameplay_slider

func _value_label_for(channel: StringName) -> Label:
	match channel:
		&"master":
			return master_value_label
		&"music":
			return music_value_label
		&"ui":
			return ui_value_label
		_:
			return gameplay_value_label

func _mute_check_for(channel: StringName) -> CheckButton:
	match channel:
		&"master":
			return master_mute_check
		&"music":
			return music_mute_check
		&"ui":
			return ui_mute_check
		_:
			return gameplay_mute_check
