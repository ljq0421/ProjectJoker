extends "res://tests/test_case.gd"

func run() -> void:
	for entry in RuleArchiveCatalog.new().all_entries():
		var solution_count := _multi_table_solution_count(entry, 2)
		assert_true(
			solution_count >= 2,
			"archive %s should expose at least two multi-table allocations"
			% entry.id
		)

func _multi_table_solution_count(
	entry: RuleArchiveDefinition,
	stop_after: int
) -> int:
	var die_ids: Array = []
	for index in range(entry.dice_values.size()):
		die_ids.append(StringName("d%d" % (index + 1)))
	var count := 0
	for order in _permutations(die_ids):
		var state := entry.make_state()
		var cursor := 0
		for rule in entry.encounter.rules:
			state.assignments[rule.id] = order.slice(
				cursor,
				cursor + rule.slot_count
			)
			cursor += rule.slot_count
		var report := RoundResolver.new().resolve(state, entry.encounter)
		var passed_tables: Dictionary = {}
		for event in report.events:
			if (
				event.source_id in [&"left", &"middle", &"right"]
				and event.delta > 0
			):
				passed_tables[event.source_id] = true
		if passed_tables.size() >= 2:
			count += 1
			if count >= stop_after:
				return count
	return count

func _permutations(values: Array) -> Array:
	var result: Array = []
	_append_permutations(values, [], result)
	return result

func _append_permutations(
	remaining: Array,
	prefix: Array,
	result: Array
) -> void:
	if remaining.is_empty():
		result.append(prefix)
		return
	for index in range(remaining.size()):
		var next_remaining := remaining.duplicate()
		var value = next_remaining.pop_at(index)
		var next_prefix := prefix.duplicate()
		next_prefix.append(value)
		_append_permutations(next_remaining, next_prefix, result)
