extends "res://tests/test_case.gd"

const CARD_EXPECTATIONS := {
	&"mirror_folded_map": [[EffectSpec.Operation.MODIFY_COEFFICIENT, 2], [EffectSpec.Operation.MODIFY_COEFFICIENT, 1]],
	&"mirror_soft_echo": [[EffectSpec.Operation.REPEAT_TABLE, 2], [EffectSpec.Operation.REPEAT_TABLE, 1]],
	&"mirror_hinged_bridge": [[EffectSpec.Operation.LINK_NEIGHBORS, 1, EffectSpec.Operation.MODIFY_COEFFICIENT, 1], [EffectSpec.Operation.LINK_NEIGHBORS, 1]],
	&"mirror_double_exposure": [[EffectSpec.Operation.MODIFY_COEFFICIENT, 2, EffectSpec.Operation.REPEAT_TABLE, 1], [EffectSpec.Operation.MODIFY_COEFFICIENT, 1]],
	&"mirror_deep_echo": [[EffectSpec.Operation.MODIFY_COEFFICIENT, 1, EffectSpec.Operation.REPEAT_TABLE, 2], [EffectSpec.Operation.REPEAT_TABLE, 1]],
	&"mirror_silver_bridge": [[EffectSpec.Operation.LINK_NEIGHBORS, 1, EffectSpec.Operation.REPEAT_TABLE, 1], [EffectSpec.Operation.LINK_NEIGHBORS, 1]],
}

func run() -> void:
	var cards := CardCatalog.new()
	var engravings := EngravingCatalog.new()
	var dealers := DealerCatalog.new()
	var areas := AreaCatalog.new()
	var area := areas.mirror_hall()

	assert_equal(cards.all_cards().size(), 40, "repository should contain 40 cards")
	assert_equal(engravings.all_engravings().size(), 12, "repository should contain 12 engravings")
	assert_equal(dealers.all_dealers().size(), 3, "repository should contain 3 dealers")
	assert_true(area != null, "mirror area should load")
	if area == null:
		return
	assert_equal(area.rooms.size(), 4, "mirror area should contain 4 rooms")
	assert_equal(area.dealer_target, 190, "Mirror Lady target should be exact")
	assert_equal(area.starting_intel_tickets, 6, "mirror area starts with six tickets")
	assert_equal(area.initial_engraving_id, &"engraving_bridge", "bridge starts installed")
	assert_equal(area.initial_engraving_die_id, &"d3", "bridge starts on d3")
	assert_equal(area.initial_engraving_face, 4, "bridge starts on face four")
	assert_equal(area.validate(cards, dealers, engravings), [], "mirror area should validate")
	assert_equal(areas.validate(cards, dealers, engravings), [], "all areas should validate")

	assert_equal(cards.mirror_hall_card_ids().size(), 6, "mirror card group should be exact")
	for card_id in CARD_EXPECTATIONS:
		var card := cards.find_card(card_id)
		assert_true(card != null, "%s should load" % card_id)
		if card == null:
			continue
		assert_equal(card.target_type, CardDefinition.TargetType.GAP, "%s targets a gap" % card_id)
		assert_false(card.rule_text.strip_edges().is_empty(), "%s has public copy" % card_id)
		assert_equal(
			_effect_signature(card.effects),
			CARD_EXPECTATIONS[card_id][0],
			"%s original effects should match" % card_id
		)
		assert_equal(
			_effect_signature(card.mirror_effects),
			CARD_EXPECTATIONS[card_id][1],
			"%s mirror effects should match" % card_id
		)

	var expected_rooms := {
		&"mirror_room_reverse_drill": [EncounterRuleProfile.ResolutionDirection.RIGHT_TO_LEFT, 110, 5],
		&"mirror_room_double_ledger": [EncounterRuleProfile.ResolutionDirection.LEFT_TO_RIGHT, 116, 6],
		&"mirror_room_echo_bridge": [EncounterRuleProfile.ResolutionDirection.RIGHT_TO_LEFT, 132, 7],
		&"mirror_room_symmetric_page": [EncounterRuleProfile.ResolutionDirection.LEFT_TO_RIGHT, 140, 8],
	}
	for room_id in expected_rooms:
		var room := area.find_room(room_id)
		assert_true(room != null, "%s should load" % room_id)
		if room == null:
			continue
		assert_equal(room.encounter.rule_profile.resolution_direction, expected_rooms[room_id][0], "%s direction" % room_id)
		assert_true(room.encounter.rule_profile.mirror_first_table_card, "%s enables mirror" % room_id)
		assert_equal(room.encounter.rule_profile.mirror_limit_per_round, 1, "%s mirror limit" % room_id)
		assert_equal(room.target_total, expected_rooms[room_id][1], "%s target" % room_id)
		assert_equal(room.success_intel_reward, expected_rooms[room_id][2], "%s reward" % room_id)

	var dealer := dealers.mirror_lady()
	assert_true(dealer != null, "Mirror Lady should load")
	assert_equal(area.dealer_id, &"dealer_mirror_lady", "mirror area dealer should match")
	assert_equal(
		area.dealer_encounter.rule_profile.resolution_direction,
		EncounterRuleProfile.ResolutionDirection.RIGHT_TO_LEFT,
		"Mirror Lady resolves right to left"
	)
	assert_true(area.dealer_encounter.rule_profile.mirror_first_table_card, "Mirror Lady mirrors")
	assert_equal(engravings.mirror_hall_ids().size(), 4, "mirror engraving pool should be exact")

	var session := AreaRunSession.new(20260727, area)
	assert_true(session.start().accepted, "mirror seed fixture should start")
	assert_true(
		session.select_route(session.current_route_ids()[0]).accepted,
		"mirror seed fixture should enter its first room"
	)
	var first_hand := session.encounter_session.current_hand_ids
	var has_mirror_card := false
	for card_id in first_hand:
		if card_id in [
			&"mirror_folded_map",
			&"mirror_soft_echo",
			&"mirror_hinged_bridge",
		]:
			has_mirror_card = true
	assert_true(
		has_mirror_card,
		"fixed seed first hand should teach a mirror card: %s" % [first_hand]
	)
	var initial_profile: DieState = session.die_profiles.filter(
		func(profile: DieState) -> bool: return profile.id == &"d3"
	)[0]
	assert_equal(initial_profile.engraving_id, &"engraving_bridge", "d3 keeps bridge")
	assert_equal(initial_profile.engraved_face, 4, "d3 bridge keeps face four")

func _effect_signature(effects: Array[EffectSpec]) -> Array:
	var signature: Array = []
	for effect in effects:
		signature.append(effect.operation)
		signature.append(effect.amount)
	return signature
