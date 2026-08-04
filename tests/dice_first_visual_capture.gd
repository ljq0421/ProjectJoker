extends SceneTree

const OUTPUT_DIR := "res://tmp/dice-first-captures"
var viewport: SubViewport
var screen: DiceFirstPrototypeScreen

func _initialize() -> void: call_deferred("_capture")

func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	root.set_meta("dice_first_seed", 8042026)
	root.set_meta("dice_first_rule_id", &"echo")
	viewport = SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	screen = load("res://scenes/run/dice_first_prototype_screen.tscn").instantiate()
	viewport.add_child(screen)
	await _settle(2)
	screen._on_roll_pressed()
	await create_timer(0.46).timeout
	await _settle(2)
	if not _save("01-roll-reroll-choice.png"): return

	screen._on_die_activated(&"d1")
	await create_timer(0.25).timeout
	await _settle(3)
	if not _save("02-reroll-plan.png"): return

	screen._on_reroll_pressed()
	screen._on_instruction_pressed(1)
	screen._on_die_activated(&"d5")
	for die_id in [&"d1", &"d2", &"d3"]:
		screen.selected_die_id = die_id
		screen._on_table_pressed(&"left")
	for die_id in [&"d4", &"d5", &"d6"]:
		screen.selected_die_id = die_id
		screen._on_table_pressed(&"right")
	screen.controller.toggle_breakthrough()
	screen._refresh()
	await create_timer(0.75).timeout
	await _settle(3)
	if not _save("03-upgrade-break-preview.png"): return

	screen._on_commit_pressed()
	await create_timer(0.28).timeout
	await _settle(2)
	if not _save("04-breakthrough-climax.png"): return
	await _capture_public_rule(&"polar", "05-polar-rule-public.png")
	await _capture_public_rule(&"charge", "06-charge-rule-public.png")
	await _capture_rule_result(&"polar", [&"d1", &"d2", &"d3"], [&"d4", &"d5", &"d6"], "07-polar-rule-result.png")
	await _capture_rule_result(&"charge", [&"d1", &"d4", &"d6"], [&"d2", &"d3", &"d5"], "08-charge-rule-result.png")
	root.remove_meta("dice_first_seed")
	root.remove_meta("dice_first_rule_id")
	print("DICE_FIRST_VISUAL_CAPTURE: PASS -> %s" % OUTPUT_DIR)
	quit(0)

func _settle(frames: int) -> void:
	for _index in range(frames): await process_frame

func _capture_public_rule(rule_id: StringName, file_name: String) -> void:
	if screen != null:
		screen.queue_free()
		await _settle(2)
	root.set_meta("dice_first_rule_id", rule_id)
	screen = load("res://scenes/run/dice_first_prototype_screen.tscn").instantiate()
	viewport.add_child(screen)
	await _settle(2)
	screen._on_roll_pressed()
	await create_timer(0.46).timeout
	await _settle(2)
	_save(file_name)

func _capture_rule_result(rule_id: StringName, left_ids: Array[StringName], right_ids: Array[StringName], file_name: String) -> void:
	if screen != null:
		screen.queue_free()
		await _settle(2)
	root.set_meta("dice_first_rule_id", rule_id)
	screen = load("res://scenes/run/dice_first_prototype_screen.tscn").instantiate()
	viewport.add_child(screen)
	await _settle(2)
	screen._on_roll_pressed()
	await create_timer(0.46).timeout
	await _settle(2)
	screen._on_keep_all_pressed()
	for die_id in left_ids:
		screen.selected_die_id = die_id
		screen._on_table_pressed(&"left")
	for die_id in right_ids:
		screen.selected_die_id = die_id
		screen._on_table_pressed(&"right")
	await _settle(3)
	_save(file_name)

func _save(file_name: String) -> bool:
	var image := viewport.get_texture().get_image()
	var path := "%s/%s" % [OUTPUT_DIR, file_name]
	if image == null or image.save_png(path) != OK:
		push_error("failed to capture dice-first frame: %s" % file_name)
		quit(1)
		return false
	return true
