class_name RoomDefinition
extends Resource

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var encounter: EncounterDefinition
@export var restriction: FinalRestrictionDefinition
@export var target_total: int
@export var success_intel_reward: int
@export var tags: PackedStringArray = []
@export var synergy_tags: PackedStringArray = []
