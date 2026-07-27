class_name EncounterRuleProfile
extends Resource

enum ResolutionDirection {
	LEFT_TO_RIGHT,
	RIGHT_TO_LEFT,
}

@export var resolution_direction: ResolutionDirection = (
	ResolutionDirection.LEFT_TO_RIGHT
)
@export var mirror_first_table_card: bool = false
@export_range(0, 1, 1) var mirror_limit_per_round: int = 0
