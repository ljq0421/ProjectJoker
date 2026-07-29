extends SceneTree

var _failed := false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var menu: Control = load(
		"res://scenes/run/main_menu_screen.tscn"
	).instantiate()
	root.add_child(menu)
	await process_frame
	_assert_rect_inside(menu.get_node("%StartExpeditionButton"), Rect2(Vector2.ZERO, root.size))
	_assert_rect_inside(menu.get_node("%ContinueExpeditionButton"), Rect2(Vector2.ZERO, root.size))
	_assert_rect_inside(menu.get_node("%AbandonExpeditionButton"), Rect2(Vector2.ZERO, root.size))
	var route_grid := menu.get_node("SafeArea/Content/RouteGrid") as Control
	_assert(route_grid.size.y >= 240.0, "route trial cards should retain readable height")
	menu.free()

	var host: Control = load(
		"res://scenes/run/expedition_run_screen.tscn"
	).instantiate()
	root.add_child(host)
	host.get_node("%ExpeditionSummaryPanel").visible = true
	await process_frame
	await process_frame
	for node_name in [
		"ExpeditionSeedLabel",
		"ExpeditionAreaHistoryLabel",
		"ExpeditionFinalBuildLabel",
		"ExpeditionEpilogueLabel",
		"ReturnFromExpeditionButton",
	]:
		_assert_rect_inside(
			host.get_node("%" + node_name),
			Rect2(Vector2.ZERO, root.size)
		)
	var narrative := host.get_node("%NarrativeCard") as Control
	var area := AreaCatalog.new().gold_corridor()
	narrative.show_area_transition(area, {
		"deck_ids": area.starting_deck_ids,
		"intel_tickets": 0,
		"die_profiles": [],
	}, {
		"reduce_flashes": true,
		"disable_distortion": true,
	})
	await process_frame
	_assert(
		narrative.get_node("%NarrativeCard").get_meta("flash_suppressed", false),
		"reduced flashes should suppress narrative brightness motion"
	)
	_assert(
		narrative.get_node("%NarrativeCard").get_meta("motion_suppressed", false),
		"disabled distortion should suppress narrative movement"
	)
	for node_name in [
		"NarrativeCard",
		"NarrativeTitle",
		"NarrativeBody",
		"NarrativeContextLabel",
		"NarrativeContinueButton",
		"NarrativeExitButton",
	]:
		_assert_rect_inside(
			narrative.get_node("%" + node_name),
			Rect2(Vector2.ZERO, root.size)
		)
	host.free()
	if _failed:
		quit(1)
	else:
		print("EXPEDITION LAYOUT SELF CHECK PASSED")
		quit(0)

func _assert_rect_inside(control: Control, bounds: Rect2) -> void:
	var rect := control.get_global_rect()
	if bounds.encloses(rect) and rect.size.x > 0.0 and rect.size.y > 0.0:
		return
	_failed = true
	push_error("%s should stay inside viewport; rect=%s" % [control.name, rect])

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
