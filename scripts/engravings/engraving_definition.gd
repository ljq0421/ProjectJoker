class_name EngravingDefinition
extends Resource

enum Operation {
	ECHO_ADJACENT,
	ANCHOR_DIE,
	BRIDGE_FORWARD,
	PRISM_PARITY,
	BRIDGE_BACKWARD,
	MIRROR_PRISM,
	ECHO_LOWER_ADJACENT,
	ANCHOR_LAST_TABLE,
	BRIDGE_BIDIRECTIONAL,
	PRISM_SEQUENCE,
}

@export var id: StringName
@export var display_name: String
@export_multiline var rule_text: String
@export var operation: Operation = Operation.ECHO_ADJACENT
@export var amount: int
@export var tags: PackedStringArray = []
