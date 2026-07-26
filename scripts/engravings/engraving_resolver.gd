class_name EngravingResolver
extends RefCounted

func active_definition(
	die: DieState,
	context: ResolutionContext
) -> EngravingDefinition:
	if (
		die == null
		or die.engraving_id == &""
		or die.engraved_face < 1
		or die.engraved_face > 6
		or die.rolled_value != die.engraved_face
		or context == null
		or context.engraving_catalog == null
	):
		return null
	return context.engraving_catalog.find_engraving(die.engraving_id)

func modification_block_reason(
	state: RoundState,
	die_id: StringName,
	context: ResolutionContext
) -> String:
	var definition := active_definition(state.find_die(die_id), context)
	if (
		definition != null
		and definition.operation == EngravingDefinition.Operation.ANCHOR_DIE
	):
		return "锚定刻印已激活，这颗骰子本轮不能修改点数"
	return ""
