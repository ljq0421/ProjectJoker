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
}

@export var operation: Operation = Operation.ADJUST_DIE
@export var amount: int = 0
