extends SceneTree

var _failed := false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	change_scene_to_file("res://scenes/run/mirror_hall_run_screen.tscn")
	await process_frame
	await process_frame
	var screen := current_scene as MirrorHallRunScreen
	_assert(screen != null, "mirror hall scene should become current")
	if screen == null:
		quit(1)
		return
	var narrative := screen.get_node("%NarrativeCard")
	_assert(narrative.is_open(), "Mirror Hall should reveal its locked random mutation")
	_assert(
		"随机锁定" in narrative.get_node("%NarrativeBody").text,
		"Mirror Hall reveal should explain the random contract"
	)
	narrative.get_node("%NarrativeContinueButton").emit_signal("pressed")
	await process_frame
	await process_frame

	var route_button := screen.get_node("%RouteChoicePanel").get_node(
		"%LeftRouteButton"
	) as Button
	var room_id: StringName = route_button.get_meta("room_id", &"")
	_assert(room_id != &"", "real route button should carry a room ID")
	route_button.emit_signal("pressed")
	await process_frame
	await process_frame

	var room := screen.area_session.area_definition.find_room(room_id)
	_assert(
		screen.get_node("%EncounterScreen").get_node("%AreaLabel").text.contains("反照牌厅"),
		"encounter header should name Mirror Hall"
	)
	_assert(
		screen.area_session.encounter_session.target_total == room.target_total,
		"encounter target should match selected room"
	)
	var expected_direction := (
		"← 从右向左结算"
		if room.encounter.rule_profile.resolution_direction
			== EncounterRuleProfile.ResolutionDirection.RIGHT_TO_LEFT
		else "→ 从左向右结算"
	)
	_assert(
		screen.get_node("%EncounterScreen").get_node("%DirectionBadge").text
			== expected_direction,
		"direction badge should match selected room resource"
	)
	var has_mirror_card := false
	for card_id in screen.area_session.encounter_session.current_hand_ids:
		var card := screen.area_session.card_catalog.find_card(card_id)
		if card != null and not card.mirror_effects.is_empty():
			has_mirror_card = true
	_assert(has_mirror_card, "first hand should contain a mirror-teaching card")

	screen.get_node("%RoundSummaryPanel").get_node(
		"%ReturnTeachingButton"
	).emit_signal("pressed")
	await process_frame
	await process_frame
	_assert(
		current_scene != null
		and current_scene.scene_file_path
			== "res://scenes/run/main_menu_screen.tscn",
		"return button should open the main menu"
	)

	if _failed:
		quit(1)
	else:
		print("MIRROR HALL INPUT SELF CHECK PASSED")
		quit(0)

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
