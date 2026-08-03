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

	var expedition_save_path := (
		"res://tmp/codex-expedition-layout-%d.cfg" % Time.get_ticks_usec()
	)
	root.set_meta("expedition_launch_mode", &"new")
	root.set_meta("expedition_seed", 20260803)
	root.set_meta("expedition_save_path", expedition_save_path)
	var host: Control = load(
		"res://scenes/run/expedition_run_screen.tscn"
	).instantiate()
	root.add_child(host)
	for _frame in range(12):
		await process_frame
	var narrative := host.get_node("%NarrativeCard") as Control
	var initial_narrative_card: Control = narrative.get_node("%NarrativeCard")
	_assert(
		initial_narrative_card.get_global_rect().get_center().is_equal_approx(
			Vector2(root.size) * 0.5
		),
		"initial narrative card should be centered after startup layout; rect=%s"
			% initial_narrative_card.get_global_rect()
	)
	host.get_node("%ExpeditionSummaryPanel").visible = true
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
	var narrative_card: Control = narrative.get_node("%NarrativeCard")
	_assert(
		narrative_card.get_global_rect().get_center().is_equal_approx(
			Vector2(root.size) * 0.5
		),
		"narrative card should be centered in the viewport; rect=%s"
			% narrative_card.get_global_rect()
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
	for path in [
		expedition_save_path,
		expedition_save_path + ".tmp",
		expedition_save_path + ".bak",
	]:
		var absolute_path := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(absolute_path):
			DirAccess.remove_absolute(absolute_path)
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
