extends SceneTree

var _failed := false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var area := AreaCatalog.new().faceless_hub()
	for room in area.rooms:
		var solution_count := _count_solutions(room.encounter, 2)
		_assert(
			solution_count >= 2,
			"%s should have at least two deterministic scoring assignments"
				% room.display_name
		)
	_verify_restrictions_are_strategically_distinct(area)
	if _failed:
		quit(1)
	else:
		print("FACELESS HUB PLAYABILITY SELF CHECK PASSED")
		quit(0)

func _count_solutions(
	encounter: EncounterDefinition,
	limit: int
) -> int:
	var dice_ids: Array[StringName] = [
		&"d1", &"d2", &"d3", &"d4", &"d5", &"d6",
	]
	var permutations: Array = []
	_build_permutations(dice_ids, [], permutations)
	var found := 0
	for order in permutations:
		var state := RoundState.new()
		for die_index in range(6):
			state.dice.append(DieState.new(
				dice_ids[die_index],
				die_index + 1
			))
		var cursor := 0
		for rule in encounter.rules:
			var assigned: Array[StringName] = []
			for slot_index in range(rule.slot_count):
				assigned.append(order[cursor])
				cursor += 1
			state.assignments[rule.id] = assigned
		var report := RoundResolver.new().resolve(
			state,
			encounter,
			ResolutionContext.empty()
		)
		var passed_ids: Dictionary = {}
		for event in report.events:
			if event.source_id in [&"left", &"middle", &"right"] and event.delta > 0:
				passed_ids[event.source_id] = true
		# A room is cleared across three rounds; a useful single-round plan needs
		# multiple scoring tables, not a perfect sweep of every condition.
		if passed_ids.size() >= 2:
			found += 1
			if found >= limit:
				return found
	return found

func _build_permutations(
	remaining: Array[StringName],
	prefix: Array,
	output: Array
) -> void:
	if remaining.is_empty():
		output.append(prefix.duplicate())
		return
	for index in range(remaining.size()):
		var next_remaining := remaining.duplicate()
		var value: StringName = next_remaining.pop_at(index)
		var next_prefix := prefix.duplicate()
		next_prefix.append(value)
		_build_permutations(next_remaining, next_prefix, output)

func _verify_restrictions_are_strategically_distinct(
	area: AreaDefinition
) -> void:
	var schedule := area.dealer_round_schedule
	var operation := schedule.operation_restriction
	var distribution := schedule.distribution_restriction
	_assert(
		operation.operation
			== FinalRestrictionDefinition.Operation.MAX_REAL_CARDS,
		"operation option should constrain card economy"
	)
	_assert(
		distribution.operation
			== FinalRestrictionDefinition.Operation.REQUIRE_ALL_TABLES_OCCUPIED,
		"distribution option should constrain die placement"
	)
	var state := RoundState.new()
	for die_index in range(1, 7):
		state.dice.append(DieState.new(
			StringName("d%d" % die_index),
			die_index
		))
	var card := CardCatalog.new().find_card(&"starter_nudge_up_1")
	state.played_cards.append(PlayedCard.new(card, &"d1"))
	state.played_cards.append(PlayedCard.new(card, &"d2"))
	var evaluator := RoundRestrictionEvaluator.new()
	_assert(
		not evaluator.validate_card_play(state, operation).accepted,
		"operation option should reject a second real-card plan"
	)
	_assert(
		evaluator.validate_card_play(state, distribution).accepted,
		"distribution option should not reject card count"
	)
	var placement_state := RoundState.new()
	for die_index in range(1, 7):
		placement_state.dice.append(DieState.new(
			StringName("d%d" % die_index),
			die_index
		))
	_assert(
		not evaluator.evaluate_commit(
			placement_state,
			schedule.round_plans[2].encounter,
			distribution
		).accepted,
		"distribution option should reject empty tables"
	)
	_assert(
		evaluator.evaluate_commit(
			placement_state,
			schedule.round_plans[2].encounter,
			operation
		).accepted,
		"operation option should not impose table coverage"
	)

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
