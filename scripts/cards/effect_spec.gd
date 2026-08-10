class_name EffectSpec
extends Resource

enum Operation {
	ADJUST_DIE,
	MODIFY_COEFFICIENT,
	REPEAT_TABLE,
	REVERSE_RESOLUTION,
	LINK_NEIGHBORS,
	SWAP_DICE,
	COPY_DIE,
	FLIP_DIE,
	LOCK_DIE_WITH_BONUS,
	REFUND_CALIBRATION,
	MODIFY_CONDITION,
	GRANT_INTEL_ON_CONDITION,
	QUEUE_SEARCH,
}

enum ConditionModifier {
	EXACT_TOLERANCE,
	ALLOW_ONE_ODD,
	ALLOW_ONE_GAP,
	INCREASE_SLOT_COUNT,
}

enum IntelCondition {
	TARGET_TABLE_PASSED,
	ALL_DICE_ASSIGNED,
	ALL_TABLES_OCCUPIED,
	ALL_TABLES_PASSED,
}

@export var operation: Operation = Operation.ADJUST_DIE
@export var amount: int = 0
@export var condition_modifier: ConditionModifier = (
	ConditionModifier.EXACT_TOLERANCE
)
@export var intel_condition: IntelCondition = IntelCondition.TARGET_TABLE_PASSED
@export var search_identity: StringName = &""
