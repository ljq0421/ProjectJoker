extends "res://tests/test_case.gd"

const ExpeditionConfigs = preload("res://scripts/run/expedition_config_catalog.gd")

func run() -> void:
	var configs := ExpeditionConfigs.new()
	var challenge_sets: Array[Array] = [[]]
	var challenge_ids := configs.challenge_ids()
	for challenge_id in challenge_ids:
		challenge_sets.append([challenge_id])
	for left_index in challenge_ids.size():
		for right_index in range(left_index + 1, challenge_ids.size()):
			challenge_sets.append([
				challenge_ids[left_index],
				challenge_ids[right_index],
			])
	assert_equal(challenge_sets.size(), 22, "challenge matrix should contain 22 sets")

	for deck_id in configs.deck_ids():
		for challenge_set in challenge_sets:
			var typed_challenges: Array[StringName] = []
			typed_challenges.assign(challenge_set)
			var expedition := ExpeditionSession.new()
			assert_true(
				expedition.start_new(510000 + challenge_sets.find(challenge_set), deck_id, typed_challenges).accepted,
				"%s with %s should start" % [deck_id, challenge_set]
			)
			var area := AreaRunSession.new(
				expedition.seed_value,
				AreaCatalog.new().gold_corridor()
			)
			assert_true(
				area.configure_entry_state(expedition.current_entry_state()).accepted,
				"%s with %s should configure the first area" % [deck_id, challenge_set]
			)
			assert_true(
				area.start().accepted,
				"%s with %s should build a legal market" % [deck_id, challenge_set]
			)
			assert_true(
				area.select_route(area.current_route_ids()[0]).accepted,
				"%s with %s should enter its first encounter" % [deck_id, challenge_set]
			)
