class_name EncounterDefinition
extends Resource

@export var id: StringName
@export var rules: Array[RuleDefinition] = []
@export var rule_profile: EncounterRuleProfile = EncounterRuleProfile.new()
