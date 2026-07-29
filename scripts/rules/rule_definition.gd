class_name RuleDefinition
extends Resource

enum ConditionType {
	EXACT_SUM,
	ALL_EVEN,
	CONSECUTIVE,
}

@export var id: StringName
@export var display_name: String
@export var template: RuleTableTemplate
@export var condition_type: ConditionType = ConditionType.EXACT_SUM
@export_range(1, 6, 1) var slot_count: int = 1
@export var target_value: int = 0
@export var minimum_value: int = 0
@export var maximum_value: int = 0
@export_range(2, 5, 1) var difference: int = 2
@export var slot_targets: PackedInt32Array = PackedInt32Array()
@export_range(1, 20, 1) var coefficient: int = 1
@export var flat_bonus: int = 0
