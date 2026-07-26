extends SceneTree

var failures: Array[String] = []
var slice_screen: IronAbacusSliceScreen
var guide_path: String

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await _verify_size(Vector2i(1280, 720))
	await _verify_size(Vector2i(1920, 1080))
	if failures.is_empty():
		print("PASS stage5_guide_layout_self_check")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _verify_size(viewport_size: Vector2i) -> void:
	root.size = viewport_size
	guide_path = OS.get_temp_dir().path_join(
		"project-joker-stage5-guide-layout-%dx%d-%d.cfg" % [
			viewport_size.x,
			viewport_size.y,
			Time.get_ticks_usec(),
		]
	)
	DirAccess.remove_absolute(guide_path)
	slice_screen = load(
		"res://scenes/run/iron_abacus_slice_screen.tscn"
	).instantiate()
	slice_screen.normal_target = 0
	slice_screen.dealer_target = 0
	slice_screen.guide_config_path = guide_path
	root.add_child(slice_screen)
	await _settle()

	await _assert_card(&"normal", viewport_size)
	_commit_three_rounds()
	_assert_true(slice_screen.slice_session.open_shop().accepted, "shop should open")
	var encounter: SingleEncounterScreen = slice_screen.get_node("%EncounterScreen")
	encounter.visible = false
	var shop: ShopScreen = slice_screen.get_node("%ShopScreen")
	shop.bind_session(
		slice_screen.slice_session.shop_session,
		slice_screen.slice_session.card_catalog
	)
	slice_screen._request_guide(&"shop")
	await _settle()
	await _assert_card(&"shop", viewport_size)

	_assert_true(slice_screen.slice_session.leave_shop().accepted, "shop should close")
	_assert_true(slice_screen.slice_session.start_dealer().accepted, "dealer should start")
	slice_screen.bind_current_encounter()
	await _settle()
	await _assert_card(&"dealer", viewport_size)

	_commit_three_rounds()
	var reward: EngravingRewardPanel = slice_screen.get_node("%EngravingRewardPanel")
	reward.bind_reward(
		slice_screen.slice_session.engraving_offer_ids,
		slice_screen.slice_session.die_profiles,
		slice_screen.slice_session.engraving_catalog
	)
	slice_screen._request_guide(&"reward")
	await _settle()
	await _assert_card(&"reward", viewport_size)

	var choice := _verifiable_offer()
	_assert_true(
		slice_screen.slice_session.select_engraving(choice.id).accepted,
		"layout fixture should select engraving"
	)
	_assert_true(
		slice_screen.slice_session.install_selected_engraving(&"d1", choice.face).accepted,
		"layout fixture should install engraving"
	)
	slice_screen.bind_current_encounter()
	await _settle()
	await _assert_card(&"verification", viewport_size)

	slice_screen.queue_free()
	await process_frame
	slice_screen = null
	DirAccess.remove_absolute(guide_path)

func _assert_card(checkpoint_id: StringName, viewport_size: Vector2i) -> void:
	var overlay: IronAbacusGuideOverlay = slice_screen.get_node("%IronAbacusGuideOverlay")
	_assert_true(
		overlay.is_open() and overlay.active_checkpoint_id() == checkpoint_id,
		"%s card should open at %s" % [checkpoint_id, viewport_size]
	)
	_assert_true(
		overlay.get_node("%GuideProgress").text.begins_with("进阶提示 "),
		"%s old guide should retain the advanced-guide label" % checkpoint_id
	)
	var overlay_bounds := Rect2(Vector2.ZERO, overlay.size)
	var card: Control = overlay.get_node("%GuideCard")
	_assert_true(
		overlay_bounds.encloses(card.get_rect()),
		"%s card outside overlay at %s; overlay=%s card=%s" % [
			checkpoint_id,
			viewport_size,
			overlay_bounds,
			card.get_rect(),
		]
	)
	_assert_true(
		overlay.mouse_filter == Control.MOUSE_FILTER_STOP,
		"%s overlay should block input" % checkpoint_id
	)
	_assert_true(overlay.z_index > 0, "%s overlay should render above phase UI" % checkpoint_id)
	var focus_layer: Control = overlay.get_node("%GuideFocusFrames")
	var card_spec := slice_screen.guide_flow.card_spec(checkpoint_id)
	var targets := slice_screen._resolve_guide_targets(card_spec.get("target_ids", []))
	_assert_true(
		focus_layer.get_child_count() == targets.size() and not targets.is_empty(),
		"%s should expose one focus frame per target" % checkpoint_id
	)
	for frame_index in range(focus_layer.get_child_count()):
		var frame: Control = focus_layer.get_child(frame_index)
		var target: Control = targets[frame_index]
		_assert_true(
			overlay_bounds.encloses(frame.get_rect()),
			"%s focus frame outside overlay at %s" % [checkpoint_id, viewport_size]
		)
		var expected := _expected_focus_rect(overlay, target, overlay_bounds)
		_assert_true(
			frame.position.is_equal_approx(expected.position)
				and frame.size.is_equal_approx(expected.size),
			"%s focus frame should track its target at %s; expected=%s actual=%s"
				% [checkpoint_id, viewport_size, expected, frame.get_rect()]
		)
		var overlap := card.get_rect().intersection(frame.get_rect())
		_assert_true(
			not overlap.has_area(),
			"%s card overlaps focus frame at %s; overlap=%s" % [
				checkpoint_id,
				viewport_size,
				overlap,
			]
		)
	var card_global := card.get_global_rect()
	for button_name in ["GuideDismissButton", "GuideAcknowledgeButton"]:
		var button: Button = overlay.get_node("%" + button_name)
		_assert_true(
			card_global.encloses(button.get_global_rect()),
			"%s %s should remain inside card" % [checkpoint_id, button_name]
		)
	overlay.acknowledge_current()
	_assert_true(not overlay.is_open(), "%s acknowledgement should close card" % checkpoint_id)
	_assert_true(
		focus_layer.get_child_count() == 0,
		"%s close should remove focus frames" % checkpoint_id
	)

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
	var fitted_size := Vector2(
		min(candidate.size.x, overlay_bounds.size.x),
		min(candidate.size.y, overlay_bounds.size.y)
	)
	var fitted_position := Vector2(
		clampf(
			candidate.position.x,
			overlay_bounds.position.x,
			overlay_bounds.end.x - fitted_size.x
		),
		clampf(
			candidate.position.y,
			overlay_bounds.position.y,
			overlay_bounds.end.y - fitted_size.y
		)
	)
	return Rect2(fitted_position, fitted_size)

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

func _commit_three_rounds() -> void:
	for round_index in range(ThreeRoundEncounterSession.ROUND_COUNT):
		var report := slice_screen.slice_session.encounter_session.current_session.commit()
		_assert_true(
			slice_screen.slice_session.accept_encounter_report(report).accepted,
			"layout fixture report should be accepted"
		)
		if round_index < ThreeRoundEncounterSession.ROUND_COUNT - 1:
			_assert_true(
				slice_screen.slice_session.advance_encounter_round().accepted,
				"layout fixture should advance round"
			)

func _verifiable_offer() -> Dictionary:
	if &"engraving_prism" in slice_screen.slice_session.engraving_offer_ids:
		return {"id": &"engraving_prism", "face": 1}
	return {"id": &"engraving_anchor", "face": 2}

func _settle() -> void:
	await process_frame
	await process_frame
	await process_frame

func _assert_true(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
