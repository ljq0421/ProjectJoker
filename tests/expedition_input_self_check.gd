extends SceneTree

var _failed := false
var _pointer_position := Vector2.ZERO
var _save_path := ""
var _guide_path := ""

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	_save_path = OS.get_environment("TEMP").path_join(
		"project-joker-expedition-input-%d.cfg" % Time.get_ticks_usec()
	)
	_guide_path = OS.get_environment("TEMP").path_join(
		"project-joker-expedition-guide-%d.cfg" % Time.get_ticks_usec()
	)
	GoldCorridorGuideProgressStore.new(_guide_path).dismiss_all()
	TutorialProgressStore.new(_guide_path).mark_done()
	root.set_meta("expedition_save_path", _save_path)
	root.set_meta("gold_corridor_guide_config_path", _guide_path)
	root.set_meta("tutorial_config_path", _guide_path)
	change_scene_to_file("res://scenes/run/main_menu_screen.tscn")
	await _settle()

	var menu := current_scene as MainMenuScreen
	_assert(menu != null, "main menu should open")
	if menu == null:
		_finish()
		return
	await _click(menu.get_node("%StartExpeditionButton") as Button)
	await _settle(5)
	var setup := current_scene as ExpeditionSetupScreen
	_assert(setup != null, "start click should open expedition setup")
	if setup == null:
		_finish()
		return
	await _click(setup.get_node("%StartConfiguredExpeditionButton") as Button)
	await _settle(8)
	var host := current_scene as ExpeditionRunScreen
	_assert(host != null, "configured expedition should open expedition host")
	_assert(
		ExpeditionSaveStore.new(_save_path).has_save(),
		"new expedition should persist before its transition card"
	)
	_assert(
		host != null and host.narrative_card.is_open(),
		"new expedition should begin with the Gold Corridor transition"
	)
	_assert(
		"手牌 12 张" in host.narrative_card.get_node("%NarrativeContextLabel").text,
		"first transition should show the effective starting deck"
	)
	_assert(
		host != null and host.current_area_screen == null,
		"transition should block area mounting"
	)
	await _click(host.narrative_card.get_node("%NarrativeExitButton") as Button)
	await _settle(5)
	menu = current_scene as MainMenuScreen
	_assert(menu != null, "transition safe exit should return to menu")
	if menu == null:
		_finish()
		return
	_assert(
		not (menu.get_node("%ContinueExpeditionButton") as Button).disabled,
		"transition safe exit should preserve the empty checkpoint"
	)
	root.set_meta("gold_corridor_guide_config_path", _guide_path)
	await _click(menu.get_node("%ContinueExpeditionButton") as Button)
	await _settle(5)
	host = current_scene as ExpeditionRunScreen
	_assert(
		host != null and host.narrative_card.is_open(),
		"empty-checkpoint restore should re-show the transition"
	)
	await _click(host.narrative_card.get_node("%NarrativeContinueButton") as Button)
	await _settle(6)
	var area := host.current_area_screen if host != null else null
	_assert(area is GoldCorridorRunScreen, "transition confirmation should mount gold corridor")
	if area == null:
		_finish()
		return
	if area.narrative_card.is_open():
		await _click(area.narrative_card.get_node("%NarrativeContinueButton") as Button)
		await _settle(4)

	await _click(area.route_panel.get_node("%LeftRouteButton") as Button)
	await _settle(5)
	_assert(
		area.area_session.phase == AreaRunSession.Phase.NORMAL_ROOM,
		"real route click should enter a room"
	)
	if area.area_session.phase != AreaRunSession.Phase.NORMAL_ROOM:
		_finish()
		return
	var room_id: StringName = area.area_session.selected_room_ids[-1]
	var opening := _opening_signature(area.area_session)
	await _click(area.get_node("%HomeButton") as Button)
	await _settle(5)

	menu = current_scene as MainMenuScreen
	_assert(menu != null, "safe exit should return to menu")
	if menu == null:
		_finish()
		return
	var continue_button := menu.get_node("%ContinueExpeditionButton") as Button
	_assert(not continue_button.disabled, "continue should be enabled after safe exit")
	root.set_meta("gold_corridor_guide_config_path", _guide_path)
	await _click(continue_button)
	await _settle(6)
	host = current_scene as ExpeditionRunScreen
	area = host.current_area_screen if host != null else null
	_assert(area is GoldCorridorRunScreen, "continue should remount gold corridor")
	_assert(
		host != null and not host.narrative_card.is_open(),
		"non-empty checkpoint restore should not repeat the area transition"
	)
	if area != null:
		_assert(
			area.area_session.phase == AreaRunSession.Phase.NORMAL_ROOM,
			"continue should restore room-entry phase"
		)
		_assert_equal(
			area.area_session.selected_room_ids[-1],
			room_id,
			"continue should keep the selected route"
		)
		_assert_equal(
			_opening_signature(area.area_session),
			opening,
			"continue should replay identical dice and hand"
		)
		await _click(area.get_node("%HomeButton") as Button)
		await _settle(5)

	menu = current_scene as MainMenuScreen
	if menu != null:
		await _click(menu.get_node("%AbandonExpeditionButton") as Button)
		await _settle()
		var dialog := menu.get_node("%AbandonExpeditionDialog") as ConfirmationDialog
		_assert(dialog.visible, "abandon click should open confirmation")
		dialog.confirmed.emit()
		await _settle(4)
		_assert(
			not ExpeditionSaveStore.new(_save_path).has_save(),
			"confirmed abandon should clear the checkpoint"
		)
		_assert(
			(menu.get_node("%ContinueExpeditionButton") as Button).disabled,
			"continue should disable after abandon"
		)
	_finish()

func _opening_signature(session: AreaRunSession) -> Dictionary:
	var current := session.encounter_session.current_session
	var dice: Array[int] = []
	for die in current.controller.state.dice:
		dice.append(die.rolled_value)
	var hand: Array[StringName] = []
	for card in current.hand:
		hand.append(card.id)
	return {"dice": dice, "hand": hand}

func _settle(frames := 3) -> void:
	for _index in range(frames):
		await process_frame

func _click(control: Control) -> void:
	_assert(control != null, "click target should exist")
	if control == null:
		return
	var point := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.relative = point - _pointer_position
	root.push_input(motion, true)
	_pointer_position = point
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

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)

func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual == expected:
		return
	_failed = true
	push_error("%s; expected=%s actual=%s" % [message, expected, actual])

func _finish() -> void:
	for path in [_save_path, _save_path + ".tmp", _save_path + ".bak", _guide_path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	if _failed:
		quit(1)
	else:
		print("EXPEDITION INPUT SELF CHECK PASSED")
		quit(0)
