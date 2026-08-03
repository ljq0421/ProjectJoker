extends SceneTree

const ExpeditionMeta = preload("res://scripts/run/expedition_meta_store.gd")

var failed := false
var pointer_position := Vector2.ZERO
var meta_path := ""
var save_path := ""
var tutorial_path := ""

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	meta_path = OS.get_temp_dir().path_join(
		"project-joker-setup-input-meta-%d.cfg" % Time.get_ticks_usec()
	)
	save_path = OS.get_temp_dir().path_join(
		"project-joker-setup-input-save-%d.cfg" % Time.get_ticks_usec()
	)
	tutorial_path = OS.get_temp_dir().path_join(
		"project-joker-setup-input-tutorial-%d.cfg" % Time.get_ticks_usec()
	)
	TutorialProgressStore.new(tutorial_path).mark_done()
	var meta_store = ExpeditionMeta.new(meta_path)
	meta_store.clear()
	meta_store.record_run(_complete_record())
	root.set_meta("expedition_meta_path", meta_path)
	root.set_meta("expedition_save_path", save_path)
	root.set_meta("tutorial_config_path", tutorial_path)

	var menu: Control = load("res://scenes/run/main_menu_screen.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await _settle()
	await _click(menu.get_node("%StartExpeditionButton"))
	await _settle()
	var navigated_setup := current_scene as Control
	_assert(
		navigated_setup != null
		and navigated_setup.get_node_or_null("%DeckChoiceRow") != null,
		"main-menu start click should open expedition setup"
	)
	if navigated_setup != null:
		await _click(navigated_setup.get_node("%ReturnFromSetupButton"))
		await _settle()
		var returned_menu := current_scene as Control
		_assert(
			returned_menu != null
			and returned_menu.get_node_or_null("%StartExpeditionButton") != null,
			"setup return click should restore the main menu"
		)
		if returned_menu != null:
			returned_menu.queue_free()
			await process_frame

	var setup := await _mount_setup()
	await _click(_button_with_meta(setup.get_node("%DeckChoiceRow"), &"deck_id", &"table_chain"))
	await _click(_button_with_meta(setup.get_node("%ChallengeGrid"), &"challenge_id", &"high_pressure"))
	await _click(_button_with_meta(setup.get_node("%ChallengeGrid"), &"challenge_id", &"no_undo"))
	await _click(_button_with_meta(setup.get_node("%ChallengeGrid"), &"challenge_id", &"market_surge"))
	_assert(setup.selected_challenge_ids.size() == 2, "third real challenge click should be rejected")
	_assert("最多" in setup.get_node("%SetupErrorLabel").text, "third click should explain the limit")
	setup.get_node("%ExpeditionSeedInput").text = "424242"
	await _click(setup.get_node("%StartConfiguredExpeditionButton"))
	await _settle()
	var expedition_screen := current_scene as ExpeditionRunScreen
	_assert(expedition_screen != null, "start click should open the expedition host")
	if expedition_screen != null:
		_assert(expedition_screen.expedition.seed_value == 424242, "manual seed should reach expedition")
		_assert(expedition_screen.expedition.starting_deck_id == &"table_chain", "deck click should reach expedition")
		_assert(
			expedition_screen.expedition.challenge_ids == [&"high_pressure", &"no_undo"],
			"two challenge clicks should reach expedition"
		)
		expedition_screen.queue_free()
		await process_frame
	ExpeditionSaveStore.new(save_path).clear()

	root.set_meta("expedition_meta_path", meta_path)
	root.set_meta("expedition_save_path", save_path)
	setup = await _mount_setup()
	var history_button := setup.get_node("%RunHistoryList").get_child(0) as Button
	await _click(history_button)
	await _settle()
	expedition_screen = current_scene as ExpeditionRunScreen
	_assert(expedition_screen != null, "history click should restart an expedition")
	if expedition_screen != null:
		_assert(expedition_screen.expedition.seed_value == 777777, "history should restore its seed")
		_assert(expedition_screen.expedition.starting_deck_id == &"intel_economy", "history should restore its deck")
		_assert(
			expedition_screen.expedition.challenge_ids == [&"short_hand"],
			"history should restore its challenges"
		)
		expedition_screen.queue_free()
		await process_frame

	ExpeditionSaveStore.new(save_path).clear()
	meta_store.clear()
	if FileAccess.file_exists(tutorial_path):
		DirAccess.remove_absolute(tutorial_path)
	if failed:
		quit(1)
	else:
		print("PASS expedition_setup_input_self_check")
		quit(0)

func _mount_setup() -> Control:
	var setup: Control = load(
		"res://scenes/run/expedition_setup_screen.tscn"
	).instantiate()
	root.add_child(setup)
	current_scene = setup
	await _settle()
	return setup

func _button_with_meta(parent: Node, meta_name: StringName, value: Variant) -> Button:
	for child in parent.get_children():
		if child is Button and child.get_meta(meta_name, null) == value:
			return child
	return null

func _click(control: Control) -> void:
	_assert(control != null, "click target should exist")
	if control == null:
		return
	var point := control.get_global_rect().get_center()
	await _move_pointer(point)
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

func _move_pointer(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.relative = point - pointer_position
	root.push_input(motion, true)
	pointer_position = point
	await process_frame

func _settle() -> void:
	await process_frame
	await process_frame
	await process_frame

func _complete_record() -> Dictionary:
	return {
		"run_id": &"input-history",
		"ended_at": 10,
		"result": &"complete",
		"seed_value": 777777,
		"starting_deck_id": &"intel_economy",
		"challenge_ids": [&"short_hand"],
		"completed_areas": [],
		"route_ids": [],
		"reward_ids": [],
		"final_deck_count": 12,
		"intel_tickets": 0,
		"failure_reason": "",
	}

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error(message)
