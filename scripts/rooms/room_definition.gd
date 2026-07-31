class_name RoomDefinition
extends Resource

enum ActivityKind {
	STANDARD,
	SINGLE_ROUND_CONTRACT,
	FIXED_HAND_PUZZLE,
	RULE_MUTATION,
}

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var encounter: EncounterDefinition
@export var restriction: FinalRestrictionDefinition
@export var activity_kind: ActivityKind = ActivityKind.STANDARD
@export_range(1, 3, 1) var round_count := 3
@export var fixed_hand_ids: Array[StringName] = []
@export var round_plans: Array[EncounterRoundPlan] = []
@export var build_identity_id: StringName = &"table_chain"
@export var target_total: int
@export var success_intel_reward: int
@export var tags: PackedStringArray = []
@export var synergy_tags: PackedStringArray = []
