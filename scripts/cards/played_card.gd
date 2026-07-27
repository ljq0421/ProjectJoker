class_name PlayedCard
extends RefCounted

var definition: CardDefinition
var primary_target: StringName
var secondary_target: StringName
var play_id: StringName = &""
var is_mirror_copy: bool = false
var source_card_id: StringName = &""
var source_play_id: StringName = &""
var source_slot_id: StringName = &""
var runtime_effects: Array[EffectSpec] = []

func _init(
	p_definition: CardDefinition,
	p_primary_target: StringName = &"",
	p_secondary_target: StringName = &""
) -> void:
	definition = p_definition
	primary_target = p_primary_target
	secondary_target = p_secondary_target

func effective_effects() -> Array[EffectSpec]:
	if not runtime_effects.is_empty():
		return runtime_effects
	return definition.effects if definition != null else []

func modified_die_ids() -> Array[StringName]:
	var die_ids: Array[StringName] = []
	for effect in effective_effects():
		match effect.operation:
			EffectSpec.Operation.ADJUST_DIE, EffectSpec.Operation.FLIP_DIE:
				_append_unique(die_ids, primary_target)
			EffectSpec.Operation.SWAP_DICE:
				_append_unique(die_ids, primary_target)
				_append_unique(die_ids, secondary_target)
			EffectSpec.Operation.COPY_DIE:
				_append_unique(die_ids, secondary_target)
	return die_ids

func locked_die_ids() -> Array[StringName]:
	var die_ids: Array[StringName] = []
	for effect in effective_effects():
		if effect.operation == EffectSpec.Operation.LOCK_DIE_WITH_BONUS:
			_append_unique(die_ids, primary_target)
	return die_ids

func clone() -> PlayedCard:
	var copy := PlayedCard.new(definition, primary_target, secondary_target)
	copy.play_id = play_id
	copy.is_mirror_copy = is_mirror_copy
	copy.source_card_id = source_card_id
	copy.source_play_id = source_play_id
	copy.source_slot_id = source_slot_id
	for effect in runtime_effects:
		copy.runtime_effects.append(_clone_effect(effect))
	return copy

func _clone_effect(effect: EffectSpec) -> EffectSpec:
	var copy := EffectSpec.new()
	copy.operation = effect.operation
	copy.amount = effect.amount
	return copy

func _append_unique(values: Array[StringName], value: StringName) -> void:
	if value != &"" and value not in values:
		values.append(value)
