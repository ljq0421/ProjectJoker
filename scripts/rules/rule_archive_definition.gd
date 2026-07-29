class_name RuleArchiveDefinition
extends Resource

@export var id: StringName
@export var display_name: String
@export var group_label: String
@export_multiline var summary: String
@export_multiline var explanation: String
@export var encounter: EncounterDefinition
@export var dice_values: PackedInt32Array = PackedInt32Array([1, 2, 3, 4, 5, 6])
@export var hand_ids: Array[StringName] = []
@export_range(0, 6, 1) var calibration_points: int = 2

func make_state() -> RoundState:
	var state := RoundState.new()
	for index in range(dice_values.size()):
		state.dice.append(DieState.new(
			StringName("d%d" % (index + 1)),
			dice_values[index]
		))
	state.calibration_points = calibration_points
	return state

func resolve_hand(card_catalog: CardCatalog) -> Array[CardDefinition]:
	var hand: Array[CardDefinition] = []
	for card_id in hand_ids:
		var card := card_catalog.find_card(card_id)
		if card != null:
			hand.append(card)
	return hand
