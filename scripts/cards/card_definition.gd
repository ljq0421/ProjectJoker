class_name CardDefinition
extends Resource

enum TargetType {
	DIE,
	TABLE,
	GAP,
	GLOBAL,
}

@export var id: StringName
@export var display_name: String
@export_multiline var rule_text: String
@export var tags: PackedStringArray = []
@export var target_type: TargetType = TargetType.DIE
@export var effects: Array[EffectSpec] = []
