extends SceneTree

var _failed := false
var _pointer_position := Vector2.ZERO
var _save_path := ""

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	_save_path = OS.get_temp_dir().path_join(
		"project-joker-narrative-input-%d.cfg" % Time.get_ticks_usec()
	)
	root.set_meta("expedition_launch_mode", &"new")
	root.set_meta("expedition_seed", 20260729)
	root.set_meta("expedition_save_path", _save_path)
	var host: ExpeditionRunScreen = load(
		"res://scenes/run/expedition_run_screen.tscn"
	).instantiate()
	root.add_child(host)
	current_scene = host
	await _settle()

	_assert(host.narrative_card.is_open(), "new run should show Gold transition")
	var gold_completion := _completion(&"gold_corridor", 7, &"engraving_anchor")
	gold_completion["dealer"]["cumulative_total"] = null
	host._pending_completion = gold_completion
	host._on_continue_requested()
	await _settle()
	_assert(
		host.expedition.current_area_id() == &"mirror_hall",
		"completed Gold boundary should advance to Mirror Hall"
	)
	_assert(host.narrative_card.is_open(), "cross-area boundary should show transition")
	_assert(
		host.narrative_card.get_node("%NarrativeTitle").text
			== "第二梦层 · 反照牌厅",
		"cross-area card should use the confirmed Mirror Hall title"
	)
	var context: String = host.narrative_card.get_node(
		"%NarrativeContextLabel"
	).text
	_assert(
		"手牌 12 张" in context
			and "情报券 7" in context
			and "刻印 1 项" in context,
		"cross-area card should expose inherited deck, tickets, and engravings"
	)
	var persisted := ExpeditionSaveStore.new(_save_path).load_snapshot()
	_assert(persisted.accepted, "cross-area transition should already be saved")
	_assert(
		persisted.snapshot.get("current_area_index", -1) == 1
			and persisted.snapshot.get("area_checkpoint", {}).is_empty(),
		"saved transition should retain an empty Mirror checkpoint"
	)

	await _click(
		host.narrative_card.get_node("%NarrativeContinueButton") as Button
	)
	await _settle(6)
	_assert(
		host.current_area_screen is MirrorHallRunScreen,
		"real confirmation should mount Mirror Hall"
	)

	host.expedition.complete_current_area(
		_completion(&"mirror_hall", 5, &"engraving_afterimage")
	)
	host.expedition.complete_current_area(
		_completion(&"faceless_hub", 3, &"engraving_sequence_prism")
	)
	host._show_summary()
	await _settle()
	_assert(
		host.get_node("%ExpeditionSummaryPanel").visible,
		"completed expedition should show its summary"
	)
	_assert(
		"公开规则可以被理解、预演并拆解"
			in host.get_node("%ExpeditionEpilogueLabel").text,
		"final summary should include the confirmed epilogue"
	)
	_assert(
		"庄家解析 已达成 / 150（历史分数未记录）"
			in host.get_node("%ExpeditionAreaHistoryLabel").text,
		"final summary should disclose an unknown legacy dealer score"
	)
	await _finish()

func _completion(
	area_id: StringName,
	tickets: int,
	engraving_id: StringName
) -> Dictionary:
	var deck := AreaCatalog.new().gold_corridor().starting_deck_ids
	var area_catalog := AreaCatalog.new()
	var definition: AreaDefinition
	match area_id:
		&"gold_corridor":
			definition = area_catalog.gold_corridor()
		&"mirror_hall":
			definition = area_catalog.mirror_hall()
		&"faceless_hub":
			definition = area_catalog.faceless_hub()
	var profiles: Array[Dictionary] = []
	for index in range(1, 7):
		profiles.append({
			"id": StringName("d%d" % index),
			"rolled_value": 1,
			"value": 1,
			"engraving_id": engraving_id if index == 1 else &"",
			"engraved_face": 2 if index == 1 else 0,
		})
	return {
		"area_id": area_id,
		"rng_state": 1000 + tickets,
		"deck_ids": deck,
		"intel_tickets": tickets,
		"die_profiles": profiles,
		"dealer": {
			"id": definition.dealer_id,
			"target_total": definition.dealer_target,
			"cumulative_total": definition.dealer_target + 9,
		},
	}

func _settle(frames := 3) -> void:
	for _index in range(frames):
		await process_frame

func _click(control: Control) -> void:
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

func _finish() -> void:
	for path in [_save_path, _save_path + ".tmp", _save_path + ".bak"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	if _failed:
		quit(1)
	else:
		print("NARRATIVE INPUT SELF CHECK PASSED")
		quit(0)
