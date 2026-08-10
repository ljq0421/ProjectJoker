extends SceneTree

var _failed := false
var _pointer_position := Vector2.ZERO

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var definition := AreaCatalog.new().gold_corridor()
	var seed := 20260810
	var checkpoint := _legacy_engraving_checkpoint(seed, definition)

	var screen: GoldCorridorRunScreen = load(
		"res://scenes/run/gold_corridor_run_screen.tscn"
	).instantiate()
	screen.guide_auto_start = false
	screen.configure_for_expedition(definition, seed, {}, checkpoint, true)
	root.add_child(screen)
	current_scene = screen
	await _settle(5)

	_assert(
		screen.area_session.phase == AreaRunSession.Phase.ENGRAVING_INSTALL,
		"legacy checkpoint should resume at engraving installation"
	)
	_assert(
		screen.area_session.encounter_session == null,
		"reward checkpoint restore should keep the transient encounter released"
	)
	var reward: EngravingRewardPanel = screen.get_node("%EngravingRewardPanel")
	_assert(reward.visible, "restored engraving reward should be visible")

	await _click(reward.get_node("%DieRow").get_child(0) as Button)
	await _click(reward.get_node("%FaceGrid").get_child(1) as Button)
	await _click(reward.get_node("%InstallEngravingButton") as Button)
	await _settle(5)

	var complete: AreaCompletePanel = screen.get_node("%AreaCompletePanel")
	_assert(complete.visible, "real install click should show the area completion panel")
	_assert(
		"已达成 / 150（历史分数未记录）"
			in complete.get_node("%ScoreHistoryLabel").text,
		"legacy completion should disclose that its dealer score was not recorded"
	)
	var completion := screen.area_session.completion_snapshot()
	_assert(not completion.is_empty(), "legacy completion snapshot should be available")
	_assert(
		completion.get("dealer", {}).get("cumulative_total") == null,
		"legacy completion should keep the unknown dealer score explicit"
	)

	screen.queue_free()
	await _settle()
	if _failed:
		quit(1)
	else:
		print("PASS reward_checkpoint_resume_input_self_check")
		quit(0)

func _legacy_engraving_checkpoint(
	seed: int,
	definition: AreaDefinition
) -> Dictionary:
	var session := AreaRunSession.new(seed, definition)
	_assert(session.start().accepted, "legacy fixture should start")
	var first_room := definition.find_room(definition.first_route_ids[0])
	var second_room := definition.find_room(definition.second_route_ids[0])
	session.selected_room_ids.assign([first_room.id, second_room.id])
	session.completed_rooms.assign([
		{
			"room_id": first_room.id,
			"target_total": first_room.target_total,
			"cumulative_total": first_room.target_total + 9,
		},
		{
			"room_id": second_room.id,
			"target_total": second_room.target_total,
			"cumulative_total": second_room.target_total + 11,
		},
	])
	session.room_index = 1
	session.encounter_session = ThreeRoundEncounterSession.new(
		session.card_catalog,
		seed,
		definition.dealer_target
	)
	session.encounter_session.cumulative_total = definition.dealer_target + 23
	session.phase = AreaRunSession.Phase.DEALER
	_assert(session._prepare_dealer_rewards().accepted, "legacy fixture should prepare rewards")
	_assert(
		session.select_engraving(session.engraving_offer_ids[0]).accepted,
		"legacy fixture should select an engraving"
	)
	var checkpoint := session.checkpoint_snapshot()
	checkpoint.erase("dealer_summary")
	return checkpoint

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
