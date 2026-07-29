extends "res://tests/test_case.gd"

func run() -> void:
	var areas := AreaCatalog.new().all_areas()
	var migrated_rules: Array[RuleDefinition] = []
	for area in areas:
		for room in area.rooms:
			migrated_rules.append_array(room.encounter.rules)
		if area.dealer_encounter != null:
			migrated_rules.append_array(area.dealer_encounter.rules)
		if area.dealer_round_schedule != null:
			for plan in area.dealer_round_schedule.round_plans:
				migrated_rules.append_array(plan.encounter.rules)

	assert_equal(
		migrated_rules.size(),
		51,
		"the three shipped areas should expose 51 migrated rule instances"
	)
	for rule in migrated_rules:
		assert_true(
			rule.template != null,
			"shipped rule %s should reference a rule template" % rule.id
		)
		if rule.template == null:
			continue
		assert_equal(
			rule.template.id,
			_expected_template_id(rule.condition_type),
			"rule %s should preserve its legacy condition semantics" % rule.id
		)

	var fixture := SingleEncounterFixture.make_encounter()
	for rule in fixture.rules:
		assert_true(
			rule.template != null,
			"teaching fixture rule %s should reference a template" % rule.id
		)

func _expected_template_id(condition_type: int) -> StringName:
	match condition_type:
		RuleDefinition.ConditionType.EXACT_SUM:
			return &"rule_exact_sum"
		RuleDefinition.ConditionType.ALL_EVEN:
			return &"rule_all_even"
		RuleDefinition.ConditionType.CONSECUTIVE:
			return &"rule_consecutive"
	return &""
