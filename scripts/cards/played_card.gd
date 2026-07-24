class_name PlayedCard
extends RefCounted

var definition: CardDefinition
var primary_target: StringName
var secondary_target: StringName

func _init(
	p_definition: CardDefinition,
	p_primary_target: StringName = &"",
	p_secondary_target: StringName = &""
) -> void:
	definition = p_definition
	primary_target = p_primary_target
	secondary_target = p_secondary_target

func clone() -> PlayedCard:
	return PlayedCard.new(definition, primary_target, secondary_target)
