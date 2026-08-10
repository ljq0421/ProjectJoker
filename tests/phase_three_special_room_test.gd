extends "res://tests/test_case.gd"

const SEED := 20260810
const SpecialRooms = preload("res://scripts/run/special_room_catalog.gd")
const EngravingSets = preload("res://scripts/engravings/engraving_set_resolver.gd")

func run() -> void:
	_test_mirror_elite_contract_and_restore()
	_test_faceless_choice_costs_and_checkpoint()
	_test_faceless_engraving_guarantee_install_and_skip()

func _test_mirror_elite_contract_and_restore() -> void:
	var area := AreaRunSession.new(SEED, AreaCatalog.new().mirror_hall())
	assert_true(area.start().accepted, "mirror elite fixture starts")
	area.room_index = 1
	area.flow_cursor = 6
	assert_true(area._create_elite_room().accepted, "mirror elite starts")
	assert_equal(area.phase, AreaRunSession.Phase.ELITE_ROOM, "elite has its own phase")
	assert_equal(area.encounter_session.target_total, 150, "elite target is fixed at 150")
	assert_equal(area.encounter_session.round_count, 2, "elite lasts exactly two rounds")
	assert_equal(
		area.encounter_session.setup.encounter.id,
		SpecialRooms.MIRROR_ELITE_ID,
		"elite uses its stable content ID"
	)
	var checkpoint := area.checkpoint_snapshot()
	var restored := AreaRunSession.new(SEED, AreaCatalog.new().mirror_hall())
	assert_true(restored.restore_checkpoint(checkpoint).accepted, "elite restores")
	assert_equal(restored.phase, area.phase, "elite phase round-trips")
	assert_equal(
		restored.encounter_session.to_snapshot(),
		area.encounter_session.to_snapshot(),
		"elite encounter state round-trips exactly"
	)
	assert_equal(
		restored.run_rng.snapshot_state(),
		area.run_rng.snapshot_state(),
		"elite restore preserves shared RNG"
	)
	restored.encounter_session.target_total = 0
	for round_index in restored.encounter_session.round_count:
		_prepare_distribution_restriction(
			restored.encounter_session.current_session.controller
		)
		var report := restored.encounter_session.current_session.commit()
		assert_true(report.valid, "elite fixture report commits")
		assert_true(restored.accept_encounter_report(report).accepted, "elite report is accepted")
		if round_index < restored.encounter_session.round_count - 1:
			assert_true(restored.advance_encounter_round().accepted, "elite fixture advances")
	assert_equal(
		int(restored.balance_telemetry.get("elite_wins", 0)),
		1,
		"successful elite encounter records exactly one elite win"
	)

func _test_faceless_choice_costs_and_checkpoint() -> void:
	var area := _reach_first_faceless_special()
	assert_equal(area.phase, AreaRunSession.Phase.CHOICE_ROOM, "first special is choice")
	var checkpoint := area.checkpoint_snapshot()
	var restored := AreaRunSession.new(SEED, AreaCatalog.new().faceless_hub())
	assert_true(restored.restore_checkpoint(checkpoint).accepted, "choice room restores")
	assert_equal(restored.flow_cursor, 2, "choice cursor round-trips")
	assert_equal(
		restored.run_rng.snapshot_state(),
		area.run_rng.snapshot_state(),
		"choice restore preserves shared RNG"
	)
	restored.intel_tickets = 1
	assert_equal(
		restored.choice_room_block_reason(&"buy_calibration"),
		"情报不足：该选项需要 2 情报",
		"choice exposes the real intel shortage"
	)
	var before_intel := area.intel_tickets
	assert_true(area.resolve_choice_room(&"raise_target").accepted, "target bargain resolves")
	assert_equal(area.intel_tickets, before_intel + 3, "target bargain grants three intel")
	assert_equal(area.next_encounter_target_multiplier, 1.1, "next target stores ten percent")
	assert_equal(area.phase, AreaRunSession.Phase.AFTER_NORMAL_ROOM, "choice reaches shop boundary")
	assert_equal(area.special_room_history.size(), 1, "choice result is checkpointed")

func _test_faceless_engraving_guarantee_install_and_skip() -> void:
	var area := AreaRunSession.new(SEED, AreaCatalog.new().faceless_hub())
	assert_true(area.start().accepted, "engraving fixture starts")
	area.flow_cursor = 6
	assert_true(area._prepare_engraving_room().accepted, "engraving offers prepare")
	assert_equal(area.special_engraving_offer_ids.size(), 3, "engraving room offers three")
	var resolver := EngravingSets.new()
	var installed_family := resolver.family_for(
		area.engraving_catalog.find_engraving(area.die_profiles[2].engraving_id)
	)
	var has_matching := false
	for engraving_id in area.special_engraving_offer_ids:
		if resolver.family_for(area.engraving_catalog.find_engraving(engraving_id)) == installed_family:
			has_matching = true
	assert_true(has_matching, "offer guarantees a matching installed family")
	var checkpoint := area.checkpoint_snapshot()
	var restored := AreaRunSession.new(SEED, AreaCatalog.new().faceless_hub())
	assert_true(restored.restore_checkpoint(checkpoint).accepted, "engraving room restores")
	assert_equal(
		restored.special_engraving_offer_ids,
		area.special_engraving_offer_ids,
		"seed-fixed engraving candidates round-trip"
	)
	var offer_id: StringName = area.special_engraving_offer_ids[0]
	assert_true(
		area.resolve_engraving_room(offer_id, &"d1").accepted,
		"free engraving installs on an empty die"
	)
	assert_equal(area.die_profiles[0].engraving_id, offer_id, "installation persists")
	assert_equal(
		area.die_profiles[0].engraved_face,
		int(area.lucky_faces[&"d1"]),
		"default installation uses the published lucky face"
	)
	assert_equal(
		int(area.special_room_history[-1].face),
		area.die_profiles[0].engraved_face,
		"engraving history stores the resolved default face"
	)
	var skip := AreaRunSession.new(SEED, AreaCatalog.new().faceless_hub())
	assert_true(skip.start().accepted, "skip fixture starts")
	skip.flow_cursor = 6
	assert_true(skip._prepare_engraving_room().accepted, "skip offers prepare")
	assert_true(skip.resolve_engraving_room().accepted, "engraving room can always be skipped")
	assert_equal(skip.phase, AreaRunSession.Phase.AFTER_NORMAL_ROOM, "skip cannot deadlock flow")

func _reach_first_faceless_special() -> AreaRunSession:
	var area := AreaRunSession.new(SEED, AreaCatalog.new().faceless_hub())
	assert_true(area.start().accepted, "choice fixture starts")
	assert_true(area.select_route(area.current_route_ids()[0]).accepted, "choice route starts")
	area.encounter_session.target_total = 0
	for round_index in area.encounter_session.round_count:
		_prepare_distribution_restriction(
			area.encounter_session.current_session.controller
		)
		var report := area.encounter_session.current_session.commit()
		assert_true(report.valid, "choice fixture report commits")
		assert_true(area.accept_encounter_report(report).accepted, "choice report is accepted")
		if round_index < area.encounter_session.round_count - 1:
			assert_true(area.advance_encounter_round().accepted, "choice fixture advances")
	assert_equal(
		int(area.balance_telemetry.get("elite_wins", 0)),
		0,
		"normal room success does not count as an elite win"
	)
	return area

func _prepare_distribution_restriction(controller: RoundController) -> void:
	var restriction := controller.active_restriction
	if (
		restriction == null
		or restriction.operation
			!= FinalRestrictionDefinition.Operation.REQUIRE_ALL_TABLES_OCCUPIED
	):
		return
	for index in range(3):
		var rule := controller.encounter.rules[index]
		assert_true(
			controller.assign_die(
				StringName("d%d" % (index + 1)),
				rule.id,
				controller.effective_slot_count(rule.id)
			).accepted,
			"choice fixture occupies every required table"
		)
