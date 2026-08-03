extends SceneTree

var failures: Array[String] = []
var slice_screen: IronAbacusSliceScreen

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	slice_screen = load(
		"res://scenes/run/iron_abacus_slice_screen.tscn"
	).instantiate()
	slice_screen.guide_auto_start = false
	slice_screen.normal_target = 0
	slice_screen.dealer_target = 0
	root.add_child(slice_screen)
	await _settle()

	var encounter: SingleEncounterScreen = slice_screen.get_node("%EncounterScreen")
	var root_rect := slice_screen.get_global_rect()
	for node_path in [
		"%EncounterScreen",
		"%DealerPanel",
		"%LeftLane",
		"%MiddleLane",
		"%RightLane",
		"%DiceTray",
		"%Hand",
		"%ResolutionPanel",
	]:
		var node: Control = (
			slice_screen.get_node(node_path)
			if node_path == "%EncounterScreen"
			else encounter.get_node(node_path)
		)
		_assert_inside(root_rect, node.get_global_rect(), node_path)

	_commit_three_rounds()
	assert(
		slice_screen.slice_session.phase == IronAbacusSliceSession.Phase.NORMAL_ROOM
	)
	assert(slice_screen.slice_session.open_shop().accepted)
	encounter.visible = false
	var shop: ShopScreen = slice_screen.get_node("%ShopScreen")
	shop.bind_session(
		slice_screen.slice_session.shop_session,
		slice_screen.slice_session.card_catalog
	)
	await _settle()
	_assert_inside(root_rect, shop.get_global_rect(), "shop screen")
	_assert_inside(root_rect, shop.get_node("%DeckGrid").get_global_rect(), "shop deck grid")
	_assert_inside(root_rect, shop.get_node("%OfferColumn").get_global_rect(), "shop offers")
	_assert_true(shop.get_node("%DeckGrid").get_child_count() == 12, "shop shows twelve cards")
	_assert_true(shop.get_node("%OfferColumn").get_child_count() == 3, "shop shows three offers")

	assert(slice_screen.slice_session.leave_shop().accepted)
	assert(slice_screen.slice_session.start_dealer().accepted)
	slice_screen.bind_current_encounter()
	await _settle()
	_assert_inside(
		root_rect,
		encounter.get_node("%DealerPanel").get_global_rect(),
		"dealer panel"
	)
	_assert_true(
		"铁算盘" in encounter.get_node("%DealerName").text,
		"dealer name should be visible"
	)
	_assert_true(
		"当前固定奖励" in encounter.get_node("%DealerHint").text,
		"dealer live reward should be visible"
	)

	_commit_three_rounds()
	var reward: EngravingRewardPanel = slice_screen.get_node("%EngravingRewardPanel")
	reward.bind_reward(
		slice_screen.slice_session.engraving_offer_ids,
		slice_screen.slice_session.die_profiles,
		slice_screen.slice_session.engraving_catalog
	)
	await _settle()
	_assert_inside(root_rect, reward.get_global_rect(), "engraving reward overlay")
	_assert_inside(root_rect, reward.get_node("%OfferRow").get_global_rect(), "engraving offers")
	_assert_inside(root_rect, reward.get_node("%DieRow").get_global_rect(), "engraving dice")
	_assert_inside(root_rect, reward.get_node("%FaceGrid").get_global_rect(), "engraving faces")
	_assert_true(reward.get_node("%OfferRow").get_child_count() == 3, "reward shows three offers")
	_assert_true(reward.get_node("%DieRow").get_child_count() == 6, "reward shows six dice")
	_assert_true(reward.get_node("%FaceGrid").get_child_count() == 6, "reward shows six faces")

	var choice := _verifiable_offer()
	assert(slice_screen.slice_session.select_engraving(choice.id).accepted)
	assert(
		slice_screen.slice_session.install_selected_engraving(&"d1", choice.face).accepted
	)
	slice_screen.bind_current_encounter()
	assert(slice_screen.slice_session.verification_session.activate_die(&"d1"))
	assert(slice_screen.slice_session.verification_session.activate_table(&"right"))
	encounter.refresh_from_session()
	await _settle()
	for node in encounter.find_children("*", "Button", true, false):
		if node is DieToken and not node.is_queued_for_deletion():
			_assert_inside(root_rect, node.get_global_rect(), "engraved die %s" % node.die_id)
	var assigned_d1 := _find_die(encounter, &"d1")
	_assert_true(assigned_d1 != null, "engraved d1 should render in a rule lane")
	if assigned_d1 != null:
		var engraving_status := assigned_d1.get_node_or_null(
			"%EngravingStatus"
		) as Label
		_assert_true(
			engraving_status != null and "激活" in engraving_status.text,
			"assigned engraved die should show active text"
		)

	slice_screen.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS stage5_layout_self_check")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _commit_three_rounds() -> void:
	for round_index in range(ThreeRoundEncounterSession.ROUND_COUNT):
		var report := slice_screen.slice_session.encounter_session.current_session.commit()
		assert(slice_screen.slice_session.accept_encounter_report(report).accepted)
		if round_index < ThreeRoundEncounterSession.ROUND_COUNT - 1:
			assert(slice_screen.slice_session.advance_encounter_round().accepted)

func _verifiable_offer() -> Dictionary:
	if &"engraving_prism" in slice_screen.slice_session.engraving_offer_ids:
		return {"id": &"engraving_prism", "face": 1}
	return {"id": &"engraving_anchor", "face": 2}

func _find_die(parent: Node, die_id: StringName) -> DieToken:
	for node in parent.find_children("*", "Button", true, false):
		if (
			node is DieToken
			and not node.is_queued_for_deletion()
			and node.die_id == die_id
		):
			return node
	return null

func _settle() -> void:
	await process_frame
	await process_frame
	await process_frame

func _assert_inside(parent_rect: Rect2, child_rect: Rect2, label: String) -> void:
	_assert_true(
		parent_rect.encloses(child_rect),
		"%s outside root; root=%s child=%s" % [label, parent_rect, child_rect]
	)

func _assert_true(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
