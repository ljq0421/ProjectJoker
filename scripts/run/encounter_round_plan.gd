class_name EncounterRoundPlan
extends Resource

@export var id: StringName
@export var display_name: String
@export var encounter: EncounterDefinition
@export_multiline var public_summary: String

func validate() -> Array[String]:
	var errors: Array[String] = []
	if id == &"":
		errors.append("round plan ID is empty")
	if display_name.strip_edges().is_empty():
		errors.append("round plan %s has no display name" % id)
	if public_summary.strip_edges().is_empty():
		errors.append("round plan %s has no public summary" % id)
	if encounter == null:
		errors.append("round plan %s has no encounter" % id)
		return errors
	if encounter.rules.size() != 3:
		errors.append("round plan %s must contain exactly three rules" % id)
	errors.append_array(ContentValidator.new().validate(encounter.rules, []))
	return errors
