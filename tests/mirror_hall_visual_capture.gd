extends SceneTree

var state := ""
var output := ""
var width := 1280
var height := 720
var screen: MirrorHallRunScreen
var config_path := ""
var capture_viewport: SubViewport

func _initialize() -> void:
	_parse_arguments()
	call_deferred("_run")

func _run() -> void:
	if state.is_empty() or output.is_empty():
		push_error("visual capture requires --state and --output")
		quit(1)
		return
	capture_viewport = SubViewport.new()
	capture_viewport.size = Vector2i(1920, 1080)
	capture_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(capture_viewport)
	config_path = OS.get_temp_dir().path_join(
		"project-joker-mirror-capture-%s-%d.cfg" % [state, Time.get_ticks_usec()]
	)
	DirAccess.remove_absolute(config_path)
	_seed_seen_for_state()
	screen = load("res://scenes/run/mirror_hall_run_screen.tscn").instantiate()
	screen.guide_config_path = config_path
	if not state.begins_with("guide_"):
		screen.guide_auto_start = false
	capture_viewport.add_child(screen)
	await _settle()
	await _prepare_state()
	await process_frame
	await process_frame
	var viewport_texture := capture_viewport.get_texture()
	if viewport_texture == null:
		push_error("viewport texture is unavailable under the active renderer")
		quit(1)
		return
	var image := viewport_texture.get_image()
	if image == null:
		push_error("viewport image is unavailable under the active renderer")
		quit(1)
		return
	if Vector2i(image.get_width(), image.get_height()) != Vector2i(1920, 1080):
		push_error(
			"capture viewport size mismatch: expected=1920x1080 actual=%dx%d"
				% [image.get_width(), image.get_height()]
		)
		quit(1)
		return
	if Vector2i(width, height) != Vector2i(1920, 1080):
		image.resize(width, height, Image.INTERPOLATE_LANCZOS)
	var result := image.save_png(output)
	if result != OK:
		push_error("failed to save visual capture: %s" % result)
		quit(1)
		return
	print("CAPTURED %s %dx%d -> %s" % [state, width, height, output])
	DirAccess.remove_absolute(config_path)
	quit(0)

func _prepare_state() -> void:
	match state:
		"guide_direction":
			_select_first_route()
			await _settle()
		"guide_mirror":
			_select_first_route()
			await _settle()
			_select_mirror_card()
			await _settle()
		"guide_dealer":
			await _reach_dealer()
			await _settle()
		"normal_mirror":
			_select_first_route()
			await _settle()
			_play_mirror_card()
			await _settle()
		"reverse_resolution":
			_select_route(&"mirror_room_reverse_drill")
			await _settle()
			_play_mirror_card()
			await _settle()
		"mirror_lady":
			await _reach_dealer()
			screen.get_node("%MirrorHallGuideOverlay").close_card()
			_play_mirror_card()
			await _settle()
		"area_complete":
			await _reach_dealer()
			await _complete_active_encounter()
			var engraving_id: StringName = screen.area_session.engraving_offer_ids[0]
			screen._on_engraving_selected(engraving_id)
			screen._on_install_requested(engraving_id, &"d1", 2)
			await _settle()
		_:
			push_error("unknown visual capture state: %s" % state)
			quit(1)

func _seed_seen_for_state() -> void:
	var config := ConfigFile.new()
	if state == "guide_mirror":
		config.set_value(MirrorHallGuideProgressStore.SECTION, "seen_direction", true)
	elif state == "guide_dealer":
		config.set_value(MirrorHallGuideProgressStore.SECTION, "seen_direction", true)
		config.set_value(MirrorHallGuideProgressStore.SECTION, "seen_mirror", true)
	if config.get_sections().is_empty():
		return
	config.save(config_path)

func _select_first_route() -> void:
	var route: RouteChoicePanel = screen.get_node("%RouteChoicePanel")
	screen._on_route_selected(route.get_node("%LeftRouteButton").get_meta("room_id"))

func _select_route(room_id: StringName) -> void:
	var route: RouteChoicePanel = screen.get_node("%RouteChoicePanel")
	for button_path in ["%LeftRouteButton", "%RightRouteButton"]:
		var button: Button = route.get_node(button_path)
		if button.get_meta("room_id", &"") == room_id:
			screen._on_route_selected(room_id)
			return
	_select_first_route()

func _select_mirror_card() -> void:
	var encounter: SingleEncounterScreen = screen.get_node("%EncounterScreen")
	var index := _mirror_card_index(encounter)
	if index >= 0:
		encounter._on_card_activated(index)

func _play_mirror_card() -> void:
	var encounter: SingleEncounterScreen = screen.get_node("%EncounterScreen")
	var index := _mirror_card_index(encounter)
	if index < 0:
		return
	encounter.session.activate_card(index)
	encounter.session.activate_gap(&"left", &"middle")
	encounter.refresh_from_session()

func _mirror_card_index(encounter: SingleEncounterScreen) -> int:
	for index in range(encounter.session.hand.size()):
		var card := encounter.session.hand[index]
		if (
			card.target_type == CardDefinition.TargetType.GAP
			and not card.mirror_effects.is_empty()
		):
			return index
	return -1

func _reach_dealer() -> void:
	var route: RouteChoicePanel = screen.get_node("%RouteChoicePanel")
	_select_first_route()
	await _settle()
	await _complete_active_encounter()
	screen._on_shop_requested()
	await _settle()
	screen._on_shop_leave_requested()
	await _settle()
	screen._on_route_selected(route.get_node("%RightRouteButton").get_meta("room_id"))
	await _settle()
	await _complete_active_encounter()
	screen._on_shop_requested()
	await _settle()
	screen._on_shop_leave_requested()
	await _settle()

func _complete_active_encounter() -> void:
	screen.area_session.encounter_session.target_total = 0
	for round_index in range(ThreeRoundEncounterSession.ROUND_COUNT):
		var report := screen.area_session.encounter_session.current_session.commit()
		screen._on_round_committed(report)
		await _settle()
		if round_index < ThreeRoundEncounterSession.ROUND_COUNT - 1:
			screen._on_next_round_requested()
			await _settle()

func _parse_arguments() -> void:
	var args := OS.get_cmdline_user_args()
	var index := 0
	while index < args.size():
		var key := args[index]
		if index + 1 >= args.size():
			break
		var value := args[index + 1]
		match key:
			"--state":
				state = value
			"--width":
				width = int(value)
			"--height":
				height = int(value)
			"--output":
				output = value
		index += 2

func _settle() -> void:
	await process_frame
	await process_frame
	await process_frame
