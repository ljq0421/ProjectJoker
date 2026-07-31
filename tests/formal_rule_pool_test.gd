extends "res://tests/test_case.gd"

const DICE_SAMPLES := [
	[1, 2, 3, 4, 5, 6],
	[1, 1, 2, 2, 3, 3],
	[2, 2, 4, 4, 5, 6],
	[1, 3, 3, 4, 5, 6],
]


func run() -> void:
	var catalog := RuleTableCatalog.new()
	var areas := AreaCatalog.new().all_areas()
	var formal_template_ids: Dictionary = {}
	var formal_rule_count := 0

	for area in areas:
		var area_template_ids: Dictionary = {}
		for room in area.rooms:
			var encounters: Array[EncounterDefinition] = [room.encounter]
			if not room.round_plans.is_empty():
				encounters.clear()
				for plan in room.round_plans:
					encounters.append(plan.encounter)
			for encounter in encounters:
				formal_rule_count += encounter.rules.size()
				_collect_templates(
					encounter,
					formal_template_ids,
					area_template_ids
				)
				assert_true(
					_multi_table_solution_count(encounter, 2) >= 2,
					"formal room %s should expose two multi-table allocations"
						% room.id
				)
		if area.dealer_encounter != null:
			formal_rule_count += area.dealer_encounter.rules.size()
			_collect_templates(
				area.dealer_encounter,
				formal_template_ids,
				area_template_ids
			)
		if area.dealer_round_schedule != null:
			for plan in area.dealer_round_schedule.round_plans:
				formal_rule_count += plan.encounter.rules.size()
				_collect_templates(
					plan.encounter,
					formal_template_ids,
					area_template_ids
				)

		assert_true(
			area_template_ids.size() >= 6,
			"area %s should use at least six formal rule templates, got %d"
				% [area.id, area_template_ids.size()]
		)
		_assert_route_pair_is_distinct(area, area.first_route_ids, "first")
		_assert_route_pair_is_distinct(area, area.second_route_ids, "second")

	assert_equal(
		formal_rule_count,
		54,
		"formal areas should expose fifty-four rule instances"
	)
	var expected_ids := PackedStringArray()
	for template_id in catalog.all_ids():
		expected_ids.append(String(template_id))
	expected_ids.sort()
	var actual_ids := PackedStringArray()
	for template_id in formal_template_ids:
		actual_ids.append(String(template_id))
	actual_ids.sort()
	assert_equal(
		actual_ids,
		expected_ids,
		"formal rooms and dealers should use all eighteen catalog templates"
	)


func _collect_templates(
	encounter: EncounterDefinition,
	global_ids: Dictionary,
	area_ids: Dictionary
) -> void:
	for rule in encounter.rules:
		if rule.template == null:
			continue
		global_ids[rule.template.id] = true
		area_ids[rule.template.id] = true


func _assert_route_pair_is_distinct(
	area: AreaDefinition,
	room_ids: Array[StringName],
	label: String
) -> void:
	assert_equal(
		room_ids.size(),
		2,
		"area %s %s route should retain two choices" % [area.id, label]
	)
	if room_ids.size() != 2:
		return
	var left := area.find_room(room_ids[0])
	var right := area.find_room(room_ids[1])
	assert_true(
		left != null and right != null,
		"area %s %s route choices should resolve" % [area.id, label]
	)
	if left == null or right == null:
		return
	assert_false(
		_template_signature(left.encounter)
			== _template_signature(right.encounter),
		"area %s %s route choices should use different template sets"
			% [area.id, label]
	)


func _template_signature(encounter: EncounterDefinition) -> PackedStringArray:
	var result := PackedStringArray()
	for rule in encounter.rules:
		result.append(
			String(rule.template.id)
			if rule.template != null
			else ""
		)
	result.sort()
	return result


func _multi_table_solution_count(
	encounter: EncounterDefinition,
	stop_after: int
) -> int:
	var dice_ids: Array[StringName] = [
		&"d1", &"d2", &"d3", &"d4", &"d5", &"d6",
	]
	var permutations: Array = []
	_append_permutations(dice_ids, [], permutations)
	var found := 0
	for values in DICE_SAMPLES:
		for order in permutations:
			var state := RoundState.new()
			for die_index in range(dice_ids.size()):
				state.dice.append(DieState.new(
					dice_ids[die_index],
					values[die_index]
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
			var passed_tables: Dictionary = {}
			for event in report.events:
				if (
					event.source_id in [&"left", &"middle", &"right"]
					and event.delta > 0
				):
					passed_tables[event.source_id] = true
			if passed_tables.size() >= 2:
				found += 1
				if found >= stop_after:
					return found
	return found


func _append_permutations(
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
		_append_permutations(next_remaining, next_prefix, output)
