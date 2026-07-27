extends SceneTree

var _failed := false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var screen: FacelessHubRunScreen = load(
		"res://scenes/run/faceless_hub_run_screen.tscn"
	).instantiate()
	screen.guide_auto_start = false
	root.add_child(screen)
	await _settle()

	screen._on_route_selected(screen.area_session.current_route_ids()[0])
	await _settle()
	await _open_and_verify(screen, &"composite")

	var history: Array[ShopPurchaseRecord] = []
	_assert(
		screen.area_session._create_dealer(
			screen.area_session.deck_ids,
			screen.area_session.intel_tickets,
			history
		).accepted,
		"dealer layout fixture should start"
	)
	screen.bind_current_encounter()
	await _settle()
	await _open_and_verify(screen, &"schedule")

	_assert(
		screen.final_restriction_panel.open_options(
			screen.area_session.encounter_session.public_restriction_options()
		),
		"restriction panel should open"
	)
	await _settle()
	await _open_and_verify(screen, &"restriction")
	screen.free()
	if _failed:
		quit(1)
	else:
		print("FACELESS HUB GUIDE LAYOUT SELF CHECK PASSED")
		quit(0)

func _open_and_verify(
	screen: FacelessHubRunScreen,
	checkpoint_id: StringName
) -> void:
	var spec := screen.guide_flow.card_spec(checkpoint_id)
	var targets: Array[Control] = []
	for target_id in spec.target_ids:
		targets.append(screen._resolve_guide_target(target_id))
	_assert(
		screen.guide_overlay.open_card(spec, targets),
		"%s guide should open" % checkpoint_id
	)
	await _settle()
	var bounds := screen.get_global_rect()
	_assert_inside(
		bounds,
		screen.guide_overlay.get_node("%GuideCard").get_global_rect(),
		"%s guide card" % checkpoint_id
	)
	var frames := screen.guide_overlay.get_node("%GuideFocusFrames")
	_assert(
		frames.get_child_count() == targets.size(),
		"%s guide should focus every requested target" % checkpoint_id
	)
	for frame in frames.get_children():
		_assert_inside(
			bounds,
			frame.get_global_rect(),
			"%s guide focus" % checkpoint_id
		)
	screen.guide_overlay.close_card()

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
