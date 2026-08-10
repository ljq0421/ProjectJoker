class_name EngravingSetResolver
extends RefCounted

const ECHO := &"echo"
const ANCHOR := &"anchor"
const BRIDGE := &"bridge"
const PRISM := &"prism"

enum SetState {
	NOT_FORMED,
	FORMED,
	ACTIVATED,
}

func family_for(definition: EngravingDefinition) -> StringName:
	if definition == null:
		return &""
	match definition.operation:
		EngravingDefinition.Operation.ECHO_ADJACENT, \
		EngravingDefinition.Operation.ECHO_LOWER_ADJACENT:
			return ECHO
		EngravingDefinition.Operation.ANCHOR_DIE, \
		EngravingDefinition.Operation.ANCHOR_LAST_TABLE:
			return ANCHOR
		EngravingDefinition.Operation.BRIDGE_FORWARD, \
		EngravingDefinition.Operation.BRIDGE_BACKWARD, \
		EngravingDefinition.Operation.BRIDGE_BIDIRECTIONAL:
			return BRIDGE
		EngravingDefinition.Operation.PRISM_PARITY, \
		EngravingDefinition.Operation.MIRROR_PRISM, \
		EngravingDefinition.Operation.PRISM_SEQUENCE:
			return PRISM
	return &""

func family_counts(
	dice: Array[DieState],
	catalog: EngravingCatalog
) -> Dictionary:
	var counts: Dictionary = {}
	if catalog == null:
		return counts
	for die in dice:
		var family := family_for(catalog.find_engraving(die.engraving_id))
		if family != &"":
			counts[family] = int(counts.get(family, 0)) + 1
	return counts

func active_families(
	dice: Array[DieState],
	catalog: EngravingCatalog
) -> Array[StringName]:
	var result: Array[StringName] = []
	for family in family_counts(dice, catalog):
		if int(family_counts(dice, catalog)[family]) >= 2:
			result.append(family)
	return result

func family_states(
	dice: Array[DieState],
	catalog: EngravingCatalog,
	activated_families: Array[StringName] = []
) -> Dictionary:
	var result: Dictionary = {}
	var counts := family_counts(dice, catalog)
	for family in [ECHO, ANCHOR, BRIDGE, PRISM]:
		var state := SetState.NOT_FORMED
		if int(counts.get(family, 0)) >= 2:
			state = (
				SetState.ACTIVATED
				if family in activated_families
				else SetState.FORMED
			)
		result[family] = {
			"state": state,
			"copy": _state_copy(state),
			"count": int(counts.get(family, 0)),
		}
	return result

func _state_copy(state: SetState) -> String:
	match state:
		SetState.FORMED:
			return "已组成"
		SetState.ACTIVATED:
			return "已激活"
	return "未满足"

func bonus_outcomes(
	state: RoundState,
	report: ResolutionReport,
	passed_rule_ids: Dictionary,
	context: ResolutionContext
) -> Array[EngravingOutcome]:
	var outcomes: Array[EngravingOutcome] = []
	if context == null or context.engraving_catalog == null:
		return outcomes
	var active := active_families(state.dice, context.engraving_catalog)
	if active.is_empty():
		return outcomes
	var triggered_families: Dictionary = {}
	var active_die_ids: Dictionary = {}
	for event in report.events:
		if not event.effect_applied:
			continue
		var definition := context.engraving_catalog.find_engraving(event.source_id)
		var family := family_for(definition)
		if family != &"":
			triggered_families[family] = true
			if event.source_die_id != &"":
				active_die_ids[event.source_die_id] = true
	if ECHO in active and triggered_families.has(ECHO):
		outcomes.append(_bonus(ECHO, "回声二件套：首次回声追加 +4", 4))
	if BRIDGE in active and triggered_families.has(BRIDGE):
		outcomes.append(_bonus(BRIDGE, "桥接二件套：首次桥接追加 +4", 4))
	if ANCHOR in active and _both_family_dice_on_passed_tables(
		state, passed_rule_ids, context.engraving_catalog, ANCHOR
	):
		outcomes.append(_bonus(ANCHOR, "锚定二件套：双锚位于通过台，追加 +6", 6))
	if PRISM in active and _active_family_die_count(
		state, active_die_ids, context.engraving_catalog, PRISM
	) >= 2:
		outcomes.append(_bonus(PRISM, "棱镜二件套：双棱镜同轮激活，追加 +8", 8))
	return outcomes

func _bonus(family: StringName, label: String, amount: int) -> EngravingOutcome:
	return EngravingOutcome.new(
		StringName("engraving_set_%s" % family), label, amount, &"", true
	)

func _both_family_dice_on_passed_tables(
	state: RoundState,
	passed_rule_ids: Dictionary,
	catalog: EngravingCatalog,
	family: StringName
) -> bool:
	var matching := 0
	for die in state.dice:
		if family_for(catalog.find_engraving(die.engraving_id)) != family:
			continue
		var assignment := state.find_assignment(die.id)
		if assignment.is_empty() or not passed_rule_ids.has(assignment.get("table_id")):
			return false
		matching += 1
	return matching >= 2

func _active_family_die_count(
	state: RoundState,
	active_die_ids: Dictionary,
	catalog: EngravingCatalog,
	family: StringName
) -> int:
	var count := 0
	for die in state.dice:
		if active_die_ids.has(die.id) and family_for(
			catalog.find_engraving(die.engraving_id)
		) == family:
			count += 1
	return count
