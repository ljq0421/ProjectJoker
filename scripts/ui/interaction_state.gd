class_name InteractionState
extends RefCounted

enum Kind { NONE, DIE, CARD }

var kind: Kind = Kind.NONE
var die_id: StringName
var card_index: int = -1
var card_primary_target: StringName

func select_die(value: StringName) -> void:
	kind = Kind.DIE
	die_id = value
	card_index = -1
	card_primary_target = &""

func select_card(value: int) -> void:
	kind = Kind.CARD
	card_index = value
	die_id = &""
	card_primary_target = &""

func select_card_primary(value: StringName) -> void:
	if kind == Kind.CARD:
		card_primary_target = value

func clear() -> void:
	kind = Kind.NONE
	die_id = &""
	card_index = -1
	card_primary_target = &""
