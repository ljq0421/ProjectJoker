extends SceneTree

const LOGICAL_SIZE := Vector2i(1920, 1080)
const RENDERED_SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080)]

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.content_scale_size = LOGICAL_SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	for rendered_size in RENDERED_SIZES:
		await _verify_size(rendered_size)
	if failures.is_empty():
		print("PASS mirror_hall_guide_layout_self_check")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _verify_size(rendered_size: Vector2i) -> void:
	root.size = rendered_size
	var label := "%dx%d" % [rendered_size.x, rendered_size.y]
	var path := OS.get_temp_dir().path_join(
		"project-joker-mirror-guide-layout-%s-%d.cfg"
			% [label, Time.get_ticks_usec()]
	)
	DirAccess.remove_absolute(path)
	var screen: MirrorHallRunScreen = load(
		"res://scenes/run/mirror_hall_run_screen.tscn"
	).instantiate()
	screen.guide_config_path = path
	root.add_child(screen)
	await _settle()
	var route: RouteChoicePanel = screen.get_node("%RouteChoicePanel")
	screen._on_route_selected(route.get_node("%LeftRouteButton").get_meta("room_id"))
	await _settle()
	await _assert_checkpoint(screen, &"direction", 1, label)
	screen.get_node("%MirrorHallGuideOverlay").acknowledge_current()
	await _settle()

	var encounter: SingleEncounterScreen = screen.get_node("%EncounterScreen")
	var mirror_index := _find_mirror_gap_card_index(encounter)
	_assert_true(mirror_index >= 0, "%s should expose a mirror guide card" % label)
	if mirror_index >= 0:
		encounter._on_card_activated(mirror_index)
		await _settle()
	await _assert_checkpoint(screen, &"mirror", 2, label)
	screen.get_node("%MirrorHallGuideOverlay").acknowledge_current()
	await _settle()

	await _complete_active_encounter(screen)
	screen._on_shop_requested()
	await _settle()
	screen._on_shop_leave_requested()
	await _settle()
	screen._on_route_selected(route.get_node("%RightRouteButton").get_meta("room_id"))
	await _settle()
	await _complete_active_encounter(screen)
	screen._on_shop_requested()
	await _settle()
	screen._on_shop_leave_requested()
	await _settle()
	_diagnose_targets(screen, &"dealer", label)
	await _assert_checkpoint(screen, &"dealer", 3, label)
	screen.get_node("%MirrorHallGuideOverlay").acknowledge_current()
	await _settle()
	_assert_true(
		screen.get_node("%SettingsLayer").get_node("%SettingsButton").visible,
		"%s settings entry should return after guide closes" % label
	)
	screen.queue_free()
	await process_frame
	DirAccess.remove_absolute(path)

func _assert_checkpoint(
	screen: MirrorHallRunScreen,
	checkpoint_id: StringName,
	progress_index: int,
	label: String
) -> void:
	var overlay: IronAbacusGuideOverlay = screen.get_node("%MirrorHallGuideOverlay")
	var bounds := Rect2(Vector2.ZERO, overlay.size)
	var card: Control = overlay.get_node("%GuideCard")
	_assert_true(
		overlay.is_open(),
		"%s %s guide should open" % [label, checkpoint_id]
	)
	_assert_equal(
		overlay.active_checkpoint_id(),
		checkpoint_id,
		"%s active guide should match" % label
	)
	_assert_equal(
		overlay.get_node("%GuideProgress").text,
		"反照提示 %d/3" % progress_index,
		"%s guide progress copy should be exact" % label
	)
	_assert_true(
		bounds.encloses(card.get_rect()),
		"%s %s card should remain in the logical safe area" % [label, checkpoint_id]
	)
	_assert_true(
		overlay.z_index > screen.get_node("%AreaCompletePanel").z_index,
		"%s guide should render above all area modals" % label
	)
	_assert_true(
		not screen.get_node("%SettingsLayer").get_node("%SettingsButton").visible,
		"%s settings entry should hide while guide blocks input" % label
	)
	var focus_layer: Control = overlay.get_node("%GuideFocusFrames")
	var target_count: int = screen.guide_flow.card_spec(checkpoint_id).get(
		"target_ids", []
	).size()
	_assert_equal(
		focus_layer.get_child_count(),
		target_count,
		"%s %s should draw one frame per approved target"
			% [label, checkpoint_id]
	)
	for frame in focus_layer.get_children():
		var frame_control := frame as Control
		_assert_true(
			frame_control != null and bounds.encloses(frame_control.get_rect()),
			"%s %s focus frame should stay inside the safe area"
				% [label, checkpoint_id]
		)
	for label_name in ["GuideProgress", "GuideTitle", "GuideInstruction"]:
		_assert_true(
			card.get_global_rect().encloses(
				overlay.get_node("%" + label_name).get_global_rect()
			),
			"%s %s %s should remain inside the guide card"
				% [label, checkpoint_id, label_name]
		)

func _find_mirror_gap_card_index(encounter: SingleEncounterScreen) -> int:
	for index in range(encounter.session.hand.size()):
		var card := encounter.session.hand[index]
		if (
			card.target_type == CardDefinition.TargetType.GAP
			and not card.mirror_effects.is_empty()
		):
			return index
	return -1

func _diagnose_targets(
	screen: MirrorHallRunScreen,
	checkpoint_id: StringName,
	label: String
) -> void:
	var overlay: Control = screen.get_node("%MirrorHallGuideOverlay")
	var overlay_bounds := Rect2(Vector2.ZERO, overlay.size)
	_assert_true(
		overlay_bounds.has_area(),
		"%s %s overlay should have area; bounds=%s"
			% [label, checkpoint_id, overlay_bounds]
	)
	for target_id in screen.guide_flow.card_spec(checkpoint_id).get("target_ids", []):
		var target := screen._resolve_guide_target(target_id)
		_assert_true(
			target != null,
			"%s %s target %s should resolve" % [label, checkpoint_id, target_id]
		)
		if target == null:
			continue
		_assert_true(
			target.is_inside_tree() and target.is_visible_in_tree(),
			"%s %s target %s should be visible" % [label, checkpoint_id, target_id]
		)
		_assert_true(
			target.get_global_rect().has_area(),
			"%s %s target %s should have area; rect=%s"
				% [label, checkpoint_id, target_id, target.get_global_rect()]
		)
		var local_rect := Rect2(
			target.get_global_rect().position - overlay.get_global_rect().position,
			target.get_global_rect().size
		)
		_assert_true(
			local_rect.intersection(overlay_bounds).has_area(),
			"%s %s target %s should intersect overlay; local=%s bounds=%s"
				% [label, checkpoint_id, target_id, local_rect, overlay_bounds]
		)

func _complete_active_encounter(screen: MirrorHallRunScreen) -> void:
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

func _assert_true(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		failures.append("%s; expected=%s actual=%s" % [message, expected, actual])
