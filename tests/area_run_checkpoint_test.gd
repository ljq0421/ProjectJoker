extends "res://tests/test_case.gd"

func run() -> void:
	_test_cross_area_entry_ignores_sample_defaults()
	_test_cross_area_market_keeps_two_offer_batches()
	_test_route_entry_checkpoint_replays_opening()
	_test_boundary_restore_is_atomic()

func _test_cross_area_entry_ignores_sample_defaults() -> void:
	var gold := AreaCatalog.new().gold_corridor()
	var mirror := AreaCatalog.new().mirror_hall()
	var profiles := _profiles()
	profiles[0]["engraving_id"] = &"engraving_anchor"
	profiles[0]["engraved_face"] = 2
	var session := AreaRunSession.new(20260729, mirror)
	var configured := session.configure_entry_state({
		"deck_ids": gold.starting_deck_ids,
		"intel_tickets": 3,
		"die_profiles": profiles,
		"rng_state": 987654,
	})
	assert_true(configured.accepted, "valid inherited state should configure")
	assert_true(session.start().accepted, "configured area should start")
	assert_equal(session.deck_ids, gold.starting_deck_ids, "inherited deck wins")
	assert_equal(session.intel_tickets, 3, "inherited balance wins")
	var replay := AreaRunSession.new(20260729, mirror)
	replay.configure_entry_state({
		"deck_ids": gold.starting_deck_ids,
		"intel_tickets": 3,
		"die_profiles": profiles,
		"rng_state": 987654,
	})
	replay.start()
	assert_equal(
		session.run_rng.snapshot_state(),
		replay.run_rng.snapshot_state(),
		"inherited rng advances deterministically"
	)
	assert_equal(
		session.die_profiles[0].engraving_id,
		&"engraving_anchor",
		"inherited engraving wins"
	)

func _test_route_entry_checkpoint_replays_opening() -> void:
	var original := AreaRunSession.new(20260729, AreaCatalog.new().gold_corridor())
	assert_true(original.start().accepted, "area should start")
	var room_id: StringName = original.current_route_ids()[0]
	assert_true(original.select_route(room_id).accepted, "room should open")
	var opening := _opening_signature(original)
	var checkpoint := original.checkpoint_snapshot()

	var restored := AreaRunSession.new(20260729, AreaCatalog.new().gold_corridor())
	assert_true(restored.restore_checkpoint(checkpoint).accepted, "checkpoint restores")
	assert_equal(restored.phase, AreaRunSession.Phase.NORMAL_ROOM, "room reopens")
	assert_equal(restored.selected_room_ids[-1], room_id, "same route is fixed")
	assert_equal(_opening_signature(restored), opening, "opening dice and hand replay")

func _test_cross_area_market_keeps_two_offer_batches() -> void:
	var gold := AreaCatalog.new().gold_corridor()
	var mirror := AreaCatalog.new().mirror_hall()
	var deck: Array[StringName] = gold.starting_deck_ids
	for replacement in [
		[&"starter_nudge_down_2", &"shop_precision_map"],
		[&"starter_nudge_up_2", &"shop_triple_repeat"],
		[&"starter_repeat_2", &"shop_amplified_chain"],
	]:
		deck[deck.find(replacement[0])] = replacement[1]
	var session := AreaRunSession.new(20260729, mirror)
	assert_true(session.configure_entry_state({
		"deck_ids": deck,
		"intel_tickets": 4,
		"die_profiles": _profiles(),
		"rng_state": 987654,
	}).accepted, "overlapping carried deck should configure")
	assert_true(session.start().accepted, "mirror should still have six outside offers")
	var outside := 0
	for card_id in session.market_ids:
		if card_id not in session.deck_ids:
			outside += 1
	assert_true(outside >= 6, "cross-area market preserves paid refresh capacity")
	for card_id in CardCatalog.new().mirror_hall_card_ids():
		assert_true(card_id in session.market_ids, "all mirror cards enter expedition market")

func _test_boundary_restore_is_atomic() -> void:
	var session := AreaRunSession.new(20260729, AreaCatalog.new().gold_corridor())
	session.start()
	var before := session.checkpoint_snapshot()
	var malformed := before.duplicate(true)
	malformed["deck_ids"] = [&"missing"]
	assert_false(session.restore_checkpoint(malformed).accepted, "bad checkpoint rejects")
	assert_equal(session.checkpoint_snapshot(), before, "rejected restore is atomic")

func _opening_signature(session: AreaRunSession) -> Dictionary:
	var current := session.encounter_session.current_session
	var dice: Array[int] = []
	for die in current.controller.state.dice:
		dice.append(die.rolled_value)
	var hand: Array[StringName] = []
	for card in current.hand:
		hand.append(card.id)
	return {"dice": dice, "hand": hand}

func _profiles() -> Array[Dictionary]:
	var profiles: Array[Dictionary] = []
	for index in range(1, 7):
		profiles.append({
			"id": StringName("d%d" % index),
			"rolled_value": 1,
			"value": 1,
			"engraving_id": &"",
			"engraved_face": 0,
		})
	return profiles
