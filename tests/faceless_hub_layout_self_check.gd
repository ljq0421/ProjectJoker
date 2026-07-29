extends SceneTree

var _failed := false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.content_scale_size = Vector2i(1920, 1080)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.size = Vector2i(1920, 1080)
	await _verify_entry()
	var screen: FacelessHubRunScreen = load(
		"res://scenes/run/faceless_hub_run_screen.tscn"
	).instantiate()
	screen.guide_auto_start = false
	root.add_child(screen)
	await _settle()

	screen._on_route_selected(screen.area_session.current_route_ids()[0])
	await _settle()
	var encounter := screen.encounter_screen
	for node_path in [
		"%DirectionBadge",
		"%LeftLane",
		"%MiddleLane",
		"%RightLane",
		"%DiceTray",
		"%Hand",
		"%ResolutionPanel",
	]:
		_assert_inside(
			screen.get_global_rect(),
			encounter.get_node(node_path).get_global_rect(),
			"normal encounter %s" % node_path
		)

	var history: Array[ShopPurchaseRecord] = []
	var service_history: Array[ShopServiceRecord] = []
	_assert(
		screen.area_session._create_dealer(
			screen.area_session.deck_ids,
			screen.area_session.intel_tickets,
			history,
			service_history
		).accepted,
		"dealer layout fixture should start"
	)
	screen.bind_current_encounter()
	await _settle()
	_assert_inside(
		screen.get_global_rect(),
		screen.round_schedule_strip.get_global_rect(),
		"round schedule"
	)
	for child in screen.round_schedule_strip.round_cards:
		_assert_inside(
			screen.get_global_rect(),
			child.get_global_rect(),
			"round schedule card"
		)

	_assert(
		screen.final_restriction_panel.open_options(
			screen.area_session.encounter_session.public_restriction_options()
		),
		"restriction panel should open"
	)
	await _settle()
	for node_path in [
		"%OperationRestrictionButton",
		"%DistributionRestrictionButton",
		"%RestrictionConfirmButton",
	]:
		_assert_inside(
			screen.get_global_rect(),
			screen.final_restriction_panel.get_node(node_path).get_global_rect(),
			"restriction %s" % node_path
		)
	_assert(
		screen.get_node("%RoundSummaryPanel").z_index
			< screen.get_node("%RouteChoicePanel").z_index
			and screen.get_node("%RouteChoicePanel").z_index
				< screen.get_node("%EngravingRewardPanel").z_index
			and screen.get_node("%EngravingRewardPanel").z_index
				< screen.get_node("%FinalRestrictionPanel").z_index
			and screen.get_node("%FinalRestrictionPanel").z_index
				< screen.get_node("%AreaCompletePanel").z_index
			and screen.get_node("%AreaCompletePanel").z_index
				< screen.get_node("%FacelessHubGuideOverlay").z_index,
		"modal z-order should keep guide above restriction and completion"
	)

	screen.free()
	if _failed:
		quit(1)
	else:
		print("FACELESS HUB LAYOUT SELF CHECK PASSED")
		quit(0)

func _verify_entry() -> void:
	var entry: SingleEncounterScreen = load(
		"res://scenes/run/single_encounter_screen.tscn"
	).instantiate()
	entry.tutorial_auto_start = false
	root.add_child(entry)
	await _settle()
	for node_path in [
		"%FacelessHubRunButton",
		"%ReplayFacelessHubGuideButton",
	]:
		_assert_inside(
			entry.get_global_rect(),
			entry.get_node(node_path).get_global_rect(),
			"entry %s" % node_path
		)
	entry.free()
	await process_frame

func _assert_inside(parent: Rect2, child: Rect2, label: String) -> void:
	_assert(
		parent.encloses(child),
		"%s outside bounds; parent=%s child=%s" % [label, parent, child]
	)

func _settle() -> void:
	await process_frame
	await process_frame

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
