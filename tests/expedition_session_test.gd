extends "res://tests/test_case.gd"

const SEED := 20260729

func run() -> void:
	_test_fixed_order_and_full_inheritance()
	_test_failure_and_final_completion()
	_test_snapshot_round_trip()

func _test_fixed_order_and_full_inheritance() -> void:
	var expedition := ExpeditionSession.new()
	assert_true(expedition.start_new(SEED).accepted, "new expedition should start")
	assert_equal(expedition.current_area_id(), &"gold_corridor", "gold is first")
	assert_equal(expedition.seed_value, SEED, "seed is retained")

	var gold := _completion(&"gold_corridor", 17, &"engraving_anchor", &"d1", 2)
	assert_true(expedition.complete_current_area(gold).accepted, "gold should complete")
	assert_equal(expedition.current_area_id(), &"mirror_hall", "mirror is second")
	var entry := expedition.current_entry_state()
	assert_equal(entry.deck_ids, gold.deck_ids, "deck carries into mirror")
	assert_equal(entry.intel_tickets, 17, "tickets carry into mirror")
	assert_equal(entry.rng_state, gold.rng_state, "rng carries into mirror")
	assert_equal(entry.die_profiles, gold.die_profiles, "engravings carry into mirror")

	var mirror := _completion(
		&"mirror_hall",
		11,
		&"engraving_afterimage",
		&"d2",
		3,
		gold.die_profiles
	)
	assert_true(expedition.complete_current_area(mirror).accepted, "mirror should complete")
	assert_equal(expedition.current_area_id(), &"faceless_hub", "faceless is third")
	entry = expedition.current_entry_state()
	assert_equal(entry.deck_ids, mirror.deck_ids, "mirror deck carries")
	assert_equal(entry.die_profiles, mirror.die_profiles, "two engravings carry")

func _test_failure_and_final_completion() -> void:
	var failed := ExpeditionSession.new()
	failed.start_new(SEED)
	assert_true(failed.fail_run("未达标").accepted, "active expedition may fail")
	assert_equal(failed.status, ExpeditionSession.Status.FAILED, "failure ends run")
	assert_false(failed.can_continue(), "failed run cannot continue")

	var completed := ExpeditionSession.new()
	completed.start_new(SEED)
	for area_id in ExpeditionSession.AREA_ORDER:
		assert_true(
			completed.complete_current_area(_completion(area_id, 5)).accepted,
			"each ordered area should complete"
		)
	assert_equal(
		completed.status,
		ExpeditionSession.Status.COMPLETE,
		"third area completes expedition"
	)
	assert_equal(completed.completed_areas.size(), 3, "three summaries are retained")

func _test_snapshot_round_trip() -> void:
	var original := ExpeditionSession.new()
	original.start_new(SEED)
	original.complete_current_area(_completion(&"gold_corridor", 9))
	var mirror := AreaRunSession.new(SEED, AreaCatalog.new().mirror_hall())
	mirror.configure_entry_state(original.current_entry_state())
	mirror.start()
	original.set_area_checkpoint(mirror.checkpoint_snapshot())
	var restored := ExpeditionSession.new()
	var result := restored.restore_snapshot(original.to_snapshot())
	assert_true(result.accepted, "valid expedition snapshot should restore")
	assert_equal(restored.to_snapshot(), original.to_snapshot(), "round trip is exact")

	var malformed := original.to_snapshot()
	malformed["current_area_index"] = 9
	var before := restored.to_snapshot()
	assert_false(restored.restore_snapshot(malformed).accepted, "invalid index rejects")
	assert_equal(restored.to_snapshot(), before, "rejected restore is atomic")

func _completion(
	area_id: StringName,
	tickets: int,
	engraving_id: StringName = &"engraving_anchor",
	die_id: StringName = &"d1",
	face: int = 2,
	previous_profiles: Array = []
) -> Dictionary:
	var area := AreaCatalog.new().gold_corridor()
	var deck: Array[StringName] = area.starting_deck_ids
	var profiles: Array[Dictionary] = []
	if previous_profiles.is_empty():
		for index in range(1, 7):
			profiles.append({
				"id": StringName("d%d" % index),
				"rolled_value": 1,
				"value": 1,
				"engraving_id": &"",
				"engraved_face": 0,
			})
	else:
		profiles.assign(previous_profiles.duplicate(true))
	for profile in profiles:
		if profile["id"] == die_id:
			profile["engraving_id"] = engraving_id
			profile["engraved_face"] = face
	return {
		"area_id": area_id,
		"rng_state": 1000 + tickets,
		"rooms": [
			{"room_id": &"room_a", "target_total": 1, "cumulative_total": 1},
			{"room_id": &"room_b", "target_total": 1, "cumulative_total": 1},
		],
		"dealer": {"id": &"dealer", "target_total": 1, "cumulative_total": 1},
		"purchases": [],
		"services": [],
		"deck_ids": deck,
		"intel_tickets": tickets,
		"engraving_id": engraving_id,
		"die_id": die_id,
		"face": face,
		"die_profiles": profiles,
	}
