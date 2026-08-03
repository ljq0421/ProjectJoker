extends "res://tests/test_case.gd"

const EXPECTED_DECK: Array[StringName] = [
	&"starter_nudge_up_1",
	&"starter_nudge_down_1",
	&"starter_map_2",
	&"starter_repeat_1",
	&"starter_link",
	&"starter_reverse",
	&"mirror_folded_map",
	&"mirror_soft_echo",
	&"mirror_hinged_bridge",
	&"faceless_swap_values",
	&"faceless_refund_calibration",
	&"faceless_three_seats",
]
const ROOM_RULE_TEMPLATES := {
	&"faceless_room_crossed_archive": [
		&"rule_sum_range",
		&"rule_bridge_table",
		&"rule_strict_descending",
	],
	&"faceless_room_reverse_index": [
		&"rule_reverse_table",
		&"rule_slot_targets",
		&"rule_all_distinct",
	],
	&"faceless_room_single_hand_agenda": [
		&"rule_minimum_sum",
		&"rule_echo_table",
		&"rule_all_equal",
	],
	&"faceless_room_three_seat_protocol": [
		&"rule_all_odd",
		&"rule_fixed_difference",
		&"rule_maximum_sum",
	],
}

func run() -> void:
	var cards := CardCatalog.new()
	var dealers := DealerCatalog.new()
	var engravings := EngravingCatalog.new()
	var areas := AreaCatalog.new()
	var area := areas.faceless_hub()
	assert_equal(areas.all_areas().size(), 3, "catalog should expose three areas")
	assert_equal(dealers.all_dealers().size(), 3, "catalog should expose three dealers")
	assert_true(area != null, "faceless hub should load")
	if area == null:
		return
	assert_equal(area.validate(cards, dealers, engravings), [], "faceless area validates")
	assert_equal(areas.validate(cards, dealers, engravings), [], "all areas validate")
	assert_equal(area.rooms.size(), 4, "faceless area has four rooms")
	assert_equal(area.first_route_ids.size(), 2, "first route has two rooms")
	assert_equal(area.second_route_ids.size(), 2, "second route has two rooms")
	var route_ids: Dictionary = {}
	for room_id in area.first_route_ids + area.second_route_ids:
		assert_false(route_ids.has(room_id), "route room IDs are unique")
		route_ids[room_id] = true
	assert_equal(area.starting_deck_ids, EXPECTED_DECK, "fixed deck matches design")
	assert_equal(area.starting_intel_tickets, 8, "faceless area starts with eight intel")
	assert_equal(area.initial_engraving_id, &"engraving_backflow_bridge", "backflow starts installed")
	assert_equal(area.initial_engraving_die_id, &"d3", "backflow starts on d3")
	assert_equal(area.initial_engraving_face, 4, "backflow starts on face four")
	assert_equal(area.engraving_offer_ids, engravings.faceless_hub_ids(), "reward pool is faceless-only")
	for room in area.rooms:
		assert_equal(
			_template_ids(room.encounter),
			ROOM_RULE_TEMPLATES[room.id],
			"%s formal rule templates" % room.id
		)
		_assert_reverse_table_public_name(
			room.encounter,
			"%s reverse table" % room.id,
			"反向台"
		)
	var unowned_shop_count := 0
	for card_id in area.shop_offer_ids:
		if card_id not in area.starting_deck_ids:
			unowned_shop_count += 1
	assert_true(unowned_shop_count >= 3, "shop can always expose three unowned cards")

	var schedule := area.dealer_round_schedule
	assert_true(schedule != null, "faceless master uses a round schedule")
	if schedule == null:
		return
	assert_equal(schedule.round_plans.size(), 3, "schedule has three rounds")
	assert_equal(
		_template_ids(schedule.round_plans[0].encounter),
		[&"rule_exact_sum", &"rule_same_parity", &"rule_strict_ascending"],
		"round one formal rule templates"
	)
	assert_equal(
		_template_ids(schedule.round_plans[1].encounter),
		[&"rule_reverse_table", &"rule_bridge_table", &"rule_strict_descending"],
		"round two formal rule templates"
	)
	assert_equal(
		_template_ids(schedule.round_plans[2].encounter),
		[&"rule_slot_targets", &"rule_echo_table", &"rule_mirrored"],
		"round three formal rule templates"
	)
	assert_equal(schedule.round_plans[0].display_name, "正面", "round one is front")
	assert_equal(schedule.round_plans[1].display_name, "反面", "round two is reverse")
	assert_equal(schedule.round_plans[2].display_name, "无面", "round three is unmasked")
	_assert_reverse_table_public_name(
		schedule.round_plans[1].encounter,
		"faceless dealer reverse round",
		"反面：反向台"
	)
	assert_equal(
		schedule.round_plans[0].encounter.rule_profile.resolution_direction,
		EncounterRuleProfile.ResolutionDirection.LEFT_TO_RIGHT,
		"round one resolves left to right"
	)
	assert_equal(
		schedule.round_plans[1].encounter.rule_profile.resolution_direction,
		EncounterRuleProfile.ResolutionDirection.RIGHT_TO_LEFT,
		"round two resolves right to left"
	)
	assert_true(
		schedule.round_plans[2].encounter.rule_profile.mirror_first_table_card,
		"round three enables one mirror copy"
	)
	assert_equal(schedule.operation_restriction.id, &"solo_verdict", "operation restriction reused")
	assert_equal(schedule.operation_restriction.amount, 1, "solo verdict limits one real card")
	assert_equal(
		schedule.distribution_restriction.id,
		&"three_seats_present",
		"distribution restriction reused"
	)
	assert_equal(schedule.distribution_restriction.amount, 3, "three seats requires all tables")

func _template_ids(encounter: EncounterDefinition) -> Array[StringName]:
	var ids: Array[StringName] = []
	for rule in encounter.rules:
		ids.append(rule.template.id)
	return ids

func _assert_reverse_table_public_name(
	encounter: EncounterDefinition,
	context: String,
	expected_name: String
) -> void:
	for rule in encounter.rules:
		if rule.template.id == &"rule_reverse_table":
			assert_equal(rule.display_name, expected_name, "%s uses canonical public name" % context)
