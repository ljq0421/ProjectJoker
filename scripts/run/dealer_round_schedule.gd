class_name DealerRoundSchedule
extends Resource

@export var round_plans: Array[EncounterRoundPlan] = []
@export var operation_restriction: FinalRestrictionDefinition
@export var distribution_restriction: FinalRestrictionDefinition

func restriction_options() -> Array[FinalRestrictionDefinition]:
	var options: Array[FinalRestrictionDefinition] = []
	if operation_restriction != null:
		options.append(operation_restriction)
	if distribution_restriction != null:
		options.append(distribution_restriction)
	return options

func validate() -> Array[String]:
	var errors: Array[String] = []
	if round_plans.size() != 3:
		errors.append("dealer schedule must contain exactly three round plans")
	var seen_plan_ids: Dictionary = {}
	for index in range(round_plans.size()):
		var plan := round_plans[index]
		if plan == null:
			errors.append("dealer schedule round %d is null" % (index + 1))
			continue
		if seen_plan_ids.has(plan.id):
			errors.append("dealer schedule has duplicate round plan ID: %s" % plan.id)
		else:
			seen_plan_ids[plan.id] = true
		errors.append_array(plan.validate())

	if operation_restriction == null:
		errors.append("dealer schedule has no operation restriction")
	else:
		errors.append_array(operation_restriction.validate())
		if (
			operation_restriction.category
			!= FinalRestrictionDefinition.Category.OPERATION
		):
			errors.append("dealer schedule operation restriction has wrong category")

	if distribution_restriction == null:
		errors.append("dealer schedule has no distribution restriction")
	else:
		errors.append_array(distribution_restriction.validate())
		if (
			distribution_restriction.category
			!= FinalRestrictionDefinition.Category.DISTRIBUTION
		):
			errors.append(
				"dealer schedule distribution restriction has wrong category"
			)

	if (
		operation_restriction != null
		and distribution_restriction != null
		and operation_restriction.id == distribution_restriction.id
	):
		errors.append("dealer schedule restrictions must use distinct IDs")
	return errors
