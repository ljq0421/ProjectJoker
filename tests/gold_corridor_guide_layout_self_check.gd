extends SceneTree

const LOGICAL_SIZE := Vector2i(1920, 1080)
const RENDERED_SIZES := [
	Vector2i(1280, 720),
	Vector2i(1920, 1080),
]

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.content_scale_size = LOGICAL_SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	await _verify_shared_overlay_defaults()
	await _verify_invalid_focus_targets_fail_open()
	for rendered_size in RENDERED_SIZES:
		await _verify_size(rendered_size)
	if failures.is_empty():
		print("PASS gold_corridor_guide_layout_self_check")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _verify_shared_overlay_defaults() -> void:
	var overlay: IronAbacusGuideOverlay = load(
		"res://scenes/components/iron_abacus_guide_overlay.tscn"
	).instantiate()
	root.add_child(overlay)
	await _settle()
	_assert_true(not overlay.is_open(), "fresh shared overlay should start closed")
	_assert_standard_card_style(overlay, "fresh closed shared overlay")
	overlay.queue_free()
	await process_frame

func _verify_invalid_focus_targets_fail_open() -> void:
	root.size = LOGICAL_SIZE
	var overlay: IronAbacusGuideOverlay = load(
		"res://scenes/components/iron_abacus_guide_overlay.tscn"
	).instantiate()
	root.add_child(overlay)
	var valid_target := _make_focus_target(
		Vector2(120, 120),
		Vector2(180, 96)
	)
	var hidden_target := _make_focus_target(
		Vector2(360, 120),
		Vector2(180, 96)
	)
	hidden_target.visible = false
	var zero_area_target := _make_focus_target(
		Vector2(120, 300),
		Vector2.ZERO
	)
	var offscreen_target := _make_focus_target(
		Vector2(LOGICAL_SIZE.x + 80, 300),
		Vector2(180, 96)
	)
	await _settle()
	var spec := {
		"id": &"invalid_target_regression",
		"progress_label": "Regression",
		"progress_index": 1,
		"progress_total": 1,
		"title": "Invalid focus target",
		"instruction": "The overlay must fail open.",
	}
	_assert_false(
		overlay.open_card(spec, [valid_target, hidden_target]),
		"a partially invalid target set should fail open"
	)
	_assert_overlay_closed_without_frames(
		overlay,
		"partially invalid target set"
	)
	_assert_false(
		overlay.open_card(spec, [zero_area_target]),
		"a zero-area target should fail open"
	)
	_assert_overlay_closed_without_frames(overlay, "zero-area target")
	_assert_false(
		overlay.open_card(spec, [offscreen_target]),
		"an offscreen target should fail open"
	)
	_assert_overlay_closed_without_frames(overlay, "offscreen target")
	overlay.queue_free()
	valid_target.queue_free()
	hidden_target.queue_free()
	zero_area_target.queue_free()
	offscreen_target.queue_free()
	await process_frame

func _make_focus_target(position: Vector2, target_size: Vector2) -> Control:
	var target := Control.new()
	root.add_child(target)
	target.position = position
	target.size = target_size
	return target

func _assert_overlay_closed_without_frames(
	overlay: IronAbacusGuideOverlay,
	label: String
) -> void:
	_assert_false(overlay.is_open(), "%s should not leave a blocking card" % label)
	_assert_equal(
		overlay.get_node("%GuideFocusFrames").get_child_count(),
		0,
		"%s should not leave partial focus frames" % label
	)
	_assert_equal(
		overlay.mouse_filter,
		Control.MOUSE_FILTER_IGNORE,
		"%s should leave background input enabled" % label
	)

func _verify_size(rendered_size: Vector2i) -> void:
	root.size = rendered_size
	var size_label := "%dx%d" % [rendered_size.x, rendered_size.y]
	var guide_path := OS.get_temp_dir().path_join(
		"project-joker-gold-guide-layout-%s-%d.cfg" % [
			size_label,
			Time.get_ticks_usec(),
		]
	)
	DirAccess.remove_absolute(guide_path)
	var screen: GoldCorridorRunScreen = load(
		"res://scenes/run/gold_corridor_run_screen.tscn"
	).instantiate()
	screen.guide_config_path = guide_path
	root.add_child(screen)
	await _settle()
	_assert_equal(
		Vector2i(screen.size),
		LOGICAL_SIZE,
		"%s should preserve the logical canvas" % size_label
	)

	await _assert_checkpoint(screen, &"route", 1, size_label)
	screen._on_route_selected(
		screen.get_node("%RouteChoicePanel").get_node("%LeftRouteButton").get_meta("room_id")
	)
	await _settle()
	await _complete_active_encounter(screen)
	screen._on_shop_requested()
	await _settle()

	await _assert_checkpoint(screen, &"shop", 2, size_label)
	screen._on_shop_leave_requested()
	await _settle()
	screen._on_route_selected(
		screen.get_node("%RouteChoicePanel").get_node("%RightRouteButton").get_meta("room_id")
	)
	await _settle()
	await _complete_active_encounter(screen)
	screen._on_shop_requested()
	await _settle()
	screen._on_shop_leave_requested()
	await _settle()

	_assert_true(
		screen.area_session.phase == AreaRunSession.Phase.DEALER,
		"%s should reach the dealer after the second shop" % size_label
	)
	await _assert_checkpoint(screen, &"dealer", 3, size_label)
	await _complete_active_encounter(screen)
	await _settle()

	await _assert_checkpoint(screen, &"engraving", 4, size_label)
	screen.queue_free()
	await process_frame
	DirAccess.remove_absolute(guide_path)

func _assert_checkpoint(
	screen: GoldCorridorRunScreen,
	checkpoint_id: StringName,
	progress_index: int,
	size_label: String
) -> void:
	var overlay: IronAbacusGuideOverlay = screen.get_node(
		"%GoldCorridorGuideOverlay"
	)
	var bounds := Rect2(Vector2.ZERO, overlay.size)
	var card: Control = overlay.get_node("%GuideCard")
	_assert_true(overlay.is_open(), "%s %s guide should open" % [size_label, checkpoint_id])
	_assert_equal(
		overlay.active_checkpoint_id(),
		checkpoint_id,
		"%s active checkpoint should match" % size_label
	)
	_assert_true(
		bounds.encloses(card.get_rect()),
		"%s %s guide card should stay in bounds; bounds=%s card=%s"
			% [size_label, checkpoint_id, bounds, card.get_rect()]
	)
	_assert_equal(
		overlay.mouse_filter,
		Control.MOUSE_FILTER_STOP,
		"%s %s open guide should block background input" % [size_label, checkpoint_id]
	)
	_assert_true(
		overlay.z_index > screen.get_node("%AreaCompletePanel").z_index,
		"%s %s guide should render above completion" % [size_label, checkpoint_id]
	)
	_assert_equal(
		overlay.get_node("%GuideProgress").text,
		"区域提示 %d/4" % progress_index,
		"%s %s guide progress copy should be exact" % [size_label, checkpoint_id]
	)

	var card_spec := screen.guide_flow.card_spec(checkpoint_id)
	var targets := _approved_targets(screen, checkpoint_id, card_spec)
	var focus_layer: Control = overlay.get_node("%GuideFocusFrames")
	_assert_equal(
		focus_layer.get_child_count(),
		targets.size(),
		"%s %s should expose one focus frame per real target" % [size_label, checkpoint_id]
	)
	for frame_index in range(mini(focus_layer.get_child_count(), targets.size())):
		var frame: Control = focus_layer.get_child(frame_index)
		var expected := _expected_focus_rect(overlay, targets[frame_index], bounds)
		_assert_true(
			bounds.encloses(frame.get_rect()),
			"%s %s focus frame %d should stay in bounds; bounds=%s frame=%s"
				% [size_label, checkpoint_id, frame_index, bounds, frame.get_rect()]
		)
		_assert_true(
			frame.position.is_equal_approx(expected.position)
				and frame.size.is_equal_approx(expected.size),
			"%s %s focus frame %d should track its real target; expected=%s actual=%s"
				% [size_label, checkpoint_id, frame_index, expected, frame.get_rect()]
		)
		var overlap := card.get_rect().intersection(frame.get_rect())
		_assert_true(
			not overlap.has_area(),
			"%s %s guide card should not overlap focus frame %d; card=%s frame=%s overlap=%s"
				% [
					size_label,
					checkpoint_id,
					frame_index,
					card.get_rect(),
					frame.get_rect(),
					overlap,
				]
		)

	var card_global := card.get_global_rect()
	for label_name in ["GuideProgress", "GuideTitle", "GuideInstruction"]:
		var label: Label = overlay.get_node("%" + label_name)
		_assert_true(
			label.visible and card_global.encloses(label.get_global_rect()),
			"%s %s %s should remain visible inside the guide card"
				% [size_label, checkpoint_id, label_name]
		)
		_assert_true(
			label.size.y >= label.get_combined_minimum_size().y,
			"%s %s %s should have enough height for its copy"
				% [size_label, checkpoint_id, label_name]
		)
	for button_name in ["GuideDismissButton", "GuideAcknowledgeButton"]:
		var button: Button = overlay.get_node("%" + button_name)
		_assert_true(
			card_global.encloses(button.get_global_rect()),
			"%s %s %s should stay inside the guide card"
				% [size_label, checkpoint_id, button_name]
		)
	overlay.acknowledge_current()
	_assert_true(
		not overlay.is_open(),
		"%s %s acknowledgement should close the guide" % [size_label, checkpoint_id]
	)
	_assert_equal(
		focus_layer.get_child_count(),
		0,
		"%s %s close should remove all focus frames" % [size_label, checkpoint_id]
	)
	_assert_equal(
		overlay.mouse_filter,
		Control.MOUSE_FILTER_IGNORE,
		"%s %s close should restore ignored background input" % [size_label, checkpoint_id]
	)
	_assert_standard_card_style(
		overlay,
		"%s %s close should restore the shared overlay style" % [size_label, checkpoint_id]
	)
	await process_frame

func _assert_standard_card_style(
	overlay: IronAbacusGuideOverlay,
	label: String
) -> void:
	var margins: MarginContainer = overlay.get_node("GuideCard/Margins")
	var title: Label = overlay.get_node("%GuideTitle")
	for margin_name in [
		"margin_left",
		"margin_top",
		"margin_right",
		"margin_bottom",
	]:
		var expected := 18 if margin_name in ["margin_left", "margin_right"] else 16
		_assert_equal(
			margins.get_theme_constant(margin_name),
			expected,
			"%s should retain %s" % [label, margin_name]
		)
		_assert_true(
			margins.has_theme_constant_override(margin_name),
			"%s should retain the scene override for %s" % [label, margin_name]
		)
	_assert_equal(
		title.get_theme_font_size("font_size"),
		25,
		"%s should retain the 25px title font" % label
	)
	_assert_true(
		title.has_theme_font_size_override("font_size"),
		"%s should retain the scene title-font override" % label
	)

func _approved_targets(
	screen: GoldCorridorRunScreen,
	checkpoint_id: StringName,
	card_spec: Dictionary
) -> Array[Control]:
	var targets: Array[Control] = []
	var approved_ids := _approved_target_ids(checkpoint_id)
	_assert_equal(
		card_spec.get("target_ids", []),
		approved_ids,
		"%s guide spec should retain its approved target IDs" % checkpoint_id
	)
	for target_id in approved_ids:
		var expected := _approved_target(screen, target_id)
		var resolved := screen._resolve_guide_target(target_id)
		_assert_true(
			expected != null,
			"%s approved target %s should exist" % [checkpoint_id, target_id]
		)
		_assert_true(
			resolved == expected,
			"%s target %s should resolve to the approved node; expected=%s actual=%s"
				% [checkpoint_id, target_id, expected, resolved]
		)
		if expected != null:
			targets.append(expected)
	return targets

func _approved_target_ids(checkpoint_id: StringName) -> Array[StringName]:
	match checkpoint_id:
		&"route":
			return [&"route_left", &"route_right"]
		&"shop":
			return [&"shop_tickets", &"shop_deck", &"shop_offers"]
		&"dealer":
			return [&"dealer_panel", &"resolution_panel"]
		&"engraving":
			return [&"reward_offers", &"reward_dice", &"reward_faces"]
	return []

func _approved_target(
	screen: GoldCorridorRunScreen,
	target_id: StringName
) -> Control:
	match target_id:
		&"route_left":
			return screen.get_node("%RouteChoicePanel").get_node(
				"SafeArea/RouteLedger/LedgerColumn/RoutePages/LeftRoutePage"
			)
		&"route_right":
			return screen.get_node("%RouteChoicePanel").get_node(
				"SafeArea/RouteLedger/LedgerColumn/RoutePages/RightRoutePage"
			)
		&"shop_tickets":
			return screen.get_node("%ShopScreen").get_node("%TicketLabel")
		&"shop_deck":
			return screen.get_node("%ShopScreen").get_node("%DeckGrid")
		&"shop_offers":
			return screen.get_node("%ShopScreen").get_node("%OfferColumn")
		&"dealer_panel":
			return screen.get_node("%EncounterScreen").get_node("%DealerPanel")
		&"resolution_panel":
			return screen.get_node("%EncounterScreen").get_node("%ResolutionPanel")
		&"reward_offers":
			return screen.get_node("%EngravingRewardPanel").get_node("%OfferRow")
		&"reward_dice":
			return screen.get_node("%EngravingRewardPanel").get_node("%DieRow")
		&"reward_faces":
			return screen.get_node("%EngravingRewardPanel").get_node("%FaceGrid")
	return null

func _expected_focus_rect(
	overlay: IronAbacusGuideOverlay,
	target: Control,
	overlay_bounds: Rect2
) -> Rect2:
	var overlay_global := overlay.get_global_rect()
	var target_global := _target_content_rect(target)
	var candidate := Rect2(
		target_global.position - overlay_global.position,
		target_global.size
	).grow(IronAbacusGuideOverlay.FOCUS_PADDING)
	return candidate.intersection(overlay_bounds)

func _target_content_rect(target: Control) -> Rect2:
	if target is GridContainer:
		var child_bounds := Rect2()
		var has_child_bounds := false
		for child in target.get_children():
			var child_control := child as Control
			if child_control == null or not child_control.visible:
				continue
			if has_child_bounds:
				child_bounds = child_bounds.merge(child_control.get_global_rect())
			else:
				child_bounds = child_control.get_global_rect()
				has_child_bounds = true
		if has_child_bounds:
			return child_bounds
	return target.get_global_rect()

func _complete_active_encounter(screen: GoldCorridorRunScreen) -> void:
	screen.area_session.encounter_session.target_total = 0
	for round_index in range(ThreeRoundEncounterSession.ROUND_COUNT):
		var report := screen.area_session.encounter_session.current_session.commit()
		screen._on_round_committed(report)
		await _settle()
		if round_index < ThreeRoundEncounterSession.ROUND_COUNT - 1:
			screen._on_next_round_requested()
			await _settle()

func _settle() -> void:
	await process_frame
	await process_frame
	await process_frame

func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	_assert_true(actual == expected, "%s; expected=%s actual=%s" % [message, expected, actual])

func _assert_true(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func _assert_false(value: bool, message: String) -> void:
	_assert_true(not value, message)
