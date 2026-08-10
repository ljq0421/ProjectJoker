extends SceneTree

const StartConfig = preload("res://scripts/run/expedition_start_config.gd")

var failures: Array[String] = []
var stamp := "%d" % Time.get_ticks_usec()
var meta_path := "res://tmp/phase-three-input-meta-%s.cfg" % stamp
var standard_save_path := "res://tmp/phase-three-input-standard-%s.cfg" % stamp
var daily_save_path := "res://tmp/phase-three-input-daily-%s.cfg" % stamp
var custom_save_path := "res://tmp/phase-three-input-custom-%s.cfg" % stamp
var custom_meta_path := "res://tmp/phase-three-input-custom-meta-%s.cfg" % stamp
var leaderboard_path := "res://tmp/phase-three-input-board-%s.cfg" % stamp
var tutorial_path := "res://tmp/phase-three-input-tutorial-%s.cfg" % stamp

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.content_scale_size = Vector2i(1920, 1080)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.size = Vector2i(1920, 1080)
	_configure_paths()
	_assert_true(_unlock_extended_modes(), "standard clear fixture should unlock extended modes")
	await _check_archive_entry()
	await _check_daily_entry()
	await _check_custom_entry_and_controls()
	_cleanup()
	_finish()

func _configure_paths() -> void:
	root.set_meta("standard_expedition_meta_path", meta_path)
	root.set_meta("expedition_meta_path", meta_path)
	root.set_meta("standard_expedition_save_path", standard_save_path)
	root.set_meta("daily_expedition_save_path", daily_save_path)
	root.set_meta("custom_expedition_save_path", custom_save_path)
	root.set_meta("custom_expedition_meta_path", custom_meta_path)
	root.set_meta("daily_leaderboard_path", leaderboard_path)
	root.set_meta("tutorial_config_path", tutorial_path)

func _unlock_extended_modes() -> bool:
	var deck_id: StringName = ExpeditionConfigCatalog.new().deck_ids()[0]
	return ExpeditionMetaStore.new(meta_path).record_run({
		"run_id": &"phase_three_input_unlock",
		"ended_at": 1,
		"result": &"complete",
		"mode": StartConfig.STANDARD,
		"seed_value": 20260810,
		"starting_deck_id": deck_id,
		"challenge_ids": [],
		"completed_areas": StartConfig.STANDARD_AREAS.duplicate(),
		"route_ids": [],
		"reward_ids": [],
		"final_deck_count": 12,
		"intel_tickets": 0,
		"failure_reason": "",
	}).accepted

func _check_archive_entry() -> void:
	var menu := await _open_menu()
	_assert_false(menu.get_node("%AchievementArchiveButton").disabled, "archive entry is available")
	await _click(menu.get_node("%AchievementArchiveButton"))
	await _settle(8)
	_assert_true(current_scene is AchievementArchiveScreen, "archive opens through a mouse click")
	if current_scene is AchievementArchiveScreen:
		_assert_equal(
			current_scene.get_node("%AchievementList").get_child_count(),
			AchievementCatalog.new().ids().size(),
			"archive renders all twelve achievements"
		)
		await _click(current_scene.get_node("%ReturnButton"))
		await _settle(6)
		_assert_true(current_scene is MainMenuScreen, "archive return uses the real button path")

func _check_daily_entry() -> void:
	var menu: MainMenuScreen = current_scene as MainMenuScreen
	if menu == null:
		menu = await _open_menu()
	_assert_false(menu.get_node("%DailyChallengeButton").disabled, "daily unlocks after standard clear")
	await _click(menu.get_node("%DailyChallengeButton"))
	await _settle(12)
	_assert_true(current_scene is ExpeditionRunScreen, "daily click reaches expedition host")
	if current_scene is ExpeditionRunScreen:
		_assert_equal(
			current_scene.expedition.start_config.mode,
			StartConfig.DAILY,
			"daily click launches daily config"
		)
	await _discard_current_scene()

func _check_custom_entry_and_controls() -> void:
	var menu := await _open_menu()
	_assert_false(menu.get_node("%CustomExpeditionButton").disabled, "custom unlocks after standard clear")
	await _click(menu.get_node("%CustomExpeditionButton"))
	await _settle(8)
	_assert_true(current_scene is CustomExpeditionSetupScreen, "custom setup opens through a mouse click")
	if not current_scene is CustomExpeditionSetupScreen:
		return
	var custom: CustomExpeditionSetupScreen = current_scene
	var first_challenge: CheckButton = custom.get_node("%CustomChallengeList").get_child(0)
	await _click(first_challenge)
	_assert_equal(custom.selected_challenges.size(), 1, "challenge toggles through injected mouse input")
	var enabled_modifiers: Array[CheckButton] = []
	for node in custom.get_node("%CustomModifierList").get_children():
		if node is CheckButton and not node.disabled:
			enabled_modifiers.append(node)
	for index in mini(2, enabled_modifiers.size()):
		await _click(enabled_modifiers[index])
	_assert_equal(
		custom.selected_modifiers[StartConfig.STANDARD_AREAS[0]].size(),
		mini(2, enabled_modifiers.size()),
		"custom modifier selection follows the real checkbox path"
	)
	await _click(custom.get_node("%StartCustomButton"))
	await _settle(12)
	_assert_true(current_scene is ExpeditionRunScreen, "custom start reaches its independent expedition host")
	if current_scene is ExpeditionRunScreen:
		_assert_equal(
			current_scene.expedition.start_config.mode,
			StartConfig.CUSTOM,
			"custom click launches custom config"
		)
	await _discard_current_scene()

func _open_menu() -> MainMenuScreen:
	await _discard_current_scene()
	var menu: MainMenuScreen = load("res://scenes/run/main_menu_screen.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await _settle(6)
	return menu

func _discard_current_scene() -> void:
	if current_scene != null:
		current_scene.queue_free()
		current_scene = null
		await process_frame

func _click(control: Control) -> void:
	_assert_true(control != null, "click target should exist")
	if control == null:
		return
	var point := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	await process_frame
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = point
	root.push_input(press, true)
	await process_frame
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = point
	root.push_input(release, true)
	await process_frame

func _settle(frames := 3) -> void:
	for _frame in frames:
		await process_frame

func _assert_true(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func _assert_false(value: bool, message: String) -> void:
	if value:
		failures.append(message)

func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		failures.append("%s; expected=%s actual=%s" % [message, expected, actual])

func _cleanup() -> void:
	for path in [
		meta_path, standard_save_path, daily_save_path, custom_save_path,
		custom_meta_path, leaderboard_path, tutorial_path,
	]:
		for suffix in ["", ".tmp", ".bak"]:
			var absolute := ProjectSettings.globalize_path(path + suffix)
			if FileAccess.file_exists(absolute):
				DirAccess.remove_absolute(absolute)

func _finish() -> void:
	if failures.is_empty():
		print("PASS phase_three_meta_input_self_check")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
