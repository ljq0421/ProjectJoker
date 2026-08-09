extends SceneTree

var area_id := "gold"
var state := "encounter"
var output := ""
var width := 1920
var height := 1080
var capture_viewport: SubViewport
var screen: AreaRunScreen

func _initialize() -> void:
	_parse_arguments()
	call_deferred("_run")

func _run() -> void:
	if output.is_empty():
		push_error("area presentation capture requires --output")
		quit(1)
		return
	capture_viewport = SubViewport.new()
	capture_viewport.size = Vector2i(1920, 1080)
	capture_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(capture_viewport)

	screen = load("res://scenes/run/area_run_screen.tscn").instantiate()
	screen.configure(_area_definition(), 731031)
	capture_viewport.add_child(screen)
	await _settle()
	if state == "mutation_reveal":
		await _settle()
	else:
		_confirm_area_modifier_reveal_if_needed()
		await _settle()
		_select_first_route()
		await _settle()
	if state == "failure":
		await _show_failure_review()
	elif state not in ["encounter", "mutation_reveal"]:
		push_error("unknown area presentation state: %s" % state)
		quit(1)
		return

	var image := capture_viewport.get_texture().get_image()
	if image == null:
		push_error("area presentation viewport image is unavailable")
		quit(1)
		return
	if Vector2i(width, height) != Vector2i(1920, 1080):
		image.resize(width, height, Image.INTERPOLATE_LANCZOS)
	if image.save_png(output) != OK:
		push_error("failed to save area presentation capture")
		quit(1)
		return
	print(
		"CAPTURED area=%s state=%s %dx%d -> %s"
		% [area_id, state, width, height, output]
	)
	quit(0)

func _area_definition() -> AreaDefinition:
	var catalog := AreaCatalog.new()
	match area_id:
		"mirror":
			return catalog.mirror_hall()
		"faceless":
			return catalog.faceless_hub()
		_:
			return catalog.gold_corridor()

func _select_first_route() -> void:
	var route: RouteChoicePanel = screen.get_node("%RouteChoicePanel")
	var button: Button = route.get_node("%LeftRouteButton")
	screen._on_route_selected(button.get_meta("room_id"))

func _confirm_area_modifier_reveal_if_needed() -> void:
	if screen.narrative_card.is_open():
		screen._on_narrative_confirmed()

func _show_failure_review() -> void:
	screen.area_session.encounter_session.target_total = 9999
	for round_index in range(ThreeRoundEncounterSession.ROUND_COUNT):
		var report: ResolutionReport = (
			screen.area_session.encounter_session.current_session.commit()
		)
		screen._on_round_committed(report)
		await _settle()
		if round_index < ThreeRoundEncounterSession.ROUND_COUNT - 1:
			screen._on_next_round_requested()
			await _settle()

func _parse_arguments() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--area="):
			area_id = argument.trim_prefix("--area=")
		elif argument.begins_with("--state="):
			state = argument.trim_prefix("--state=")
		elif argument.begins_with("--width="):
			width = int(argument.trim_prefix("--width="))
		elif argument.begins_with("--height="):
			height = int(argument.trim_prefix("--height="))
		elif argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")

func _settle() -> void:
	await process_frame
	await process_frame
	await process_frame
