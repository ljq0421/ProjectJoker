extends "res://tests/test_case.gd"

const EncounterRoundPlanScript = preload(
	"res://scripts/run/encounter_round_plan.gd"
)
const FinalRestrictionDefinitionScript = preload(
	"res://scripts/run/final_restriction_definition.gd"
)
const DealerRoundScheduleScript = preload(
	"res://scripts/run/dealer_round_schedule.gd"
)

func run() -> void:
	_test_valid_schedule()
	_test_schedule_requires_three_rounds()
	_test_schedule_requires_distinct_restriction_categories()
	_test_restriction_parameters()
	_test_optional_contracts_keep_legacy_content_compatible()

func _test_valid_schedule() -> void:
	var schedule = _valid_schedule()
	assert_equal(schedule.validate(), [], "valid round schedule should pass")

func _test_schedule_requires_three_rounds() -> void:
	var schedule = _valid_schedule()
	schedule.round_plans.resize(2)
	assert_true(
		schedule.validate().any(
			func(error: String) -> bool: return "exactly three round plans" in error
		),
		"dealer schedule should require exactly three rounds"
	)

func _test_schedule_requires_distinct_restriction_categories() -> void:
	var schedule = _valid_schedule()
	schedule.distribution_restriction.category = (
		FinalRestrictionDefinitionScript.Category.OPERATION
	)
	assert_true(
		schedule.validate().any(
			func(error: String) -> bool: return "distribution restriction" in error
		),
		"dealer schedule should require a distribution restriction"
	)

func _test_restriction_parameters() -> void:
	var operation = _operation_restriction()
	operation.amount = 0
	assert_true(
		operation.validate().any(
			func(error: String) -> bool: return "positive card limit" in error
		),
		"card limit should be positive"
	)

	var distribution = _distribution_restriction()
	distribution.amount = 2
	assert_true(
		distribution.validate().any(
			func(error: String) -> bool: return "exactly three tables" in error
		),
		"all-table restriction should require three tables"
	)

func _test_optional_contracts_keep_legacy_content_compatible() -> void:
	var setup := EncounterRunSetup.new()
	assert_true(setup.round_schedule == null, "legacy setup should have no schedule")
	assert_true(
		setup.fixed_restriction == null,
		"legacy setup should have no fixed restriction"
	)

	var room := RoomDefinition.new()
	assert_true(room.restriction == null, "legacy room should have no restriction")

	var gold_area := AreaCatalog.new().gold_corridor()
	assert_true(
		gold_area.dealer_round_schedule == null,
		"gold corridor should keep its single dealer encounter"
	)
	assert_equal(
		gold_area.validate(CardCatalog.new(), DealerCatalog.new(), EngravingCatalog.new()),
		[],
		"legacy area should still validate without a schedule"
	)

func _valid_schedule():
	var schedule = DealerRoundScheduleScript.new()
	schedule.round_plans.assign([
		_round_plan(&"round_one"),
		_round_plan(&"round_two"),
		_round_plan(&"round_three"),
	])
	schedule.operation_restriction = _operation_restriction()
	schedule.distribution_restriction = _distribution_restriction()
	return schedule

func _round_plan(plan_id: StringName):
	var plan = EncounterRoundPlanScript.new()
	plan.id = plan_id
	plan.display_name = String(plan_id)
	plan.public_summary = "公开空间规则"
	plan.encounter = _encounter(StringName("%s_encounter" % plan_id))
	return plan

func _operation_restriction():
	var restriction = FinalRestrictionDefinitionScript.new()
	restriction.id = &"solo_verdict"
	restriction.display_name = "独手裁决"
	restriction.rule_text = "本轮最多使用一张真实手法牌。"
	restriction.category = FinalRestrictionDefinitionScript.Category.OPERATION
	restriction.operation = (
		FinalRestrictionDefinitionScript.Operation.MAX_REAL_CARDS
	)
	restriction.amount = 1
	return restriction

func _distribution_restriction():
	var restriction = FinalRestrictionDefinitionScript.new()
	restriction.id = &"three_seats_present"
	restriction.display_name = "三席到场"
	restriction.rule_text = "三张规则台都必须至少分配一颗骰子。"
	restriction.category = FinalRestrictionDefinitionScript.Category.DISTRIBUTION
	restriction.operation = (
		FinalRestrictionDefinitionScript.Operation.REQUIRE_ALL_TABLES_OCCUPIED
	)
	restriction.amount = 3
	return restriction

func _encounter(encounter_id: StringName) -> EncounterDefinition:
	var encounter := EncounterDefinition.new()
	encounter.id = encounter_id
	encounter.rules = [
		_rule(&"left", 7),
		_rule(&"middle", 8),
		_rule(&"right", 9),
	]
	return encounter

func _rule(rule_id: StringName, target: int) -> RuleDefinition:
	var rule := RuleDefinition.new()
	rule.id = rule_id
	rule.display_name = "精确为 %d" % target
	rule.slot_count = 2
	rule.target_value = target
	rule.coefficient = 2
	return rule
