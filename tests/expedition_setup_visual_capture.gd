extends SceneTree

const ExpeditionMeta = preload("res://scripts/run/expedition_meta_store.gd")

var output := ""
var meta_path := ""
var capture_viewport: SubViewport

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	call_deferred("_run")

func _run() -> void:
	if output.is_empty():
		push_error("expedition setup capture requires --output")
		quit(1)
		return
	capture_viewport = SubViewport.new()
	capture_viewport.size = Vector2i(1920, 1080)
	capture_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(capture_viewport)
	meta_path = OS.get_temp_dir().path_join(
		"project-joker-setup-capture-%d.cfg" % Time.get_ticks_usec()
	)
	var meta_store = ExpeditionMeta.new(meta_path)
	meta_store.clear()
	meta_store.record_run(_complete_record())
	root.set_meta("expedition_meta_path", meta_path)

	var setup: Control = load(
		"res://scenes/run/expedition_setup_screen.tscn"
	).instantiate()
	capture_viewport.add_child(setup)
	await _settle()
	_press_choice(setup.get_node("%DeckChoiceRow"), &"deck_id", &"table_chain")
	_press_choice(setup.get_node("%ChallengeGrid"), &"challenge_id", &"high_pressure")
	_press_choice(setup.get_node("%ChallengeGrid"), &"challenge_id", &"no_undo")
	setup.get_node("%ExpeditionSeedInput").text = "424242"
	await _settle()

	var image := capture_viewport.get_texture().get_image()
	if image == null or image.save_png(output) != OK:
		push_error("failed to save expedition setup capture")
		meta_store.clear()
		quit(1)
		return
	print("CAPTURED expedition setup 1920x1080 -> %s" % output)
	meta_store.clear()
	quit(0)

func _press_choice(parent: Node, meta_name: StringName, value: Variant) -> void:
	for child in parent.get_children():
		if child is Button and child.get_meta(meta_name, null) == value:
			child.emit_signal("pressed")
			return

func _settle() -> void:
	await process_frame
	await process_frame
	await process_frame

func _complete_record() -> Dictionary:
	return {
		"run_id": &"visual-capture-unlock",
		"ended_at": 10,
		"result": &"complete",
		"seed_value": 777777,
		"starting_deck_id": &"intel_economy",
		"challenge_ids": [],
		"completed_areas": [],
		"route_ids": [],
		"reward_ids": [],
		"final_deck_count": 12,
		"intel_tickets": 0,
		"failure_reason": "",
	}
