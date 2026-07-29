class_name DealerDefinition
extends Resource

@export var id: StringName
@export var display_name: String
@export_multiline var rule_text: String
@export_multiline var opening_text: String
@export var fixed_reward: int
@export var penalty_per_unassigned_die: int
@export var tags: PackedStringArray = []
