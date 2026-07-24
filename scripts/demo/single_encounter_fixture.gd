class_name SingleEncounterFixture
extends RefCounted

static func make_state() -> RoundState:
	var state := RoundState.new()
	for value in range(1, 7):
		state.dice.append(DieState.new(StringName("d%d" % value), value))
	return state

static func make_encounter() -> EncounterDefinition:
	var encounter := EncounterDefinition.new()
	encounter.id = &"neon_training_room"
	encounter.rules = [
		_rule(
			&"left",
			"精确为 7",
			RuleDefinition.ConditionType.EXACT_SUM,
			2,
			2,
			7
		),
		_rule(
			&"middle",
			"连续三数",
			RuleDefinition.ConditionType.CONSECUTIVE,
			3,
			2
		),
		_rule(
			&"right",
			"单枚偶数",
			RuleDefinition.ConditionType.ALL_EVEN,
			1,
			3
		),
	]
	return encounter

static func make_hand() -> Array[CardDefinition]:
	return [
		_card(
			&"club_nudge",
			"拨码",
			CardDefinition.TargetType.DIE,
			EffectSpec.Operation.ADJUST_DIE,
			-1
		),
		_card(
			&"diamond_map",
			"映射",
			CardDefinition.TargetType.TABLE,
			EffectSpec.Operation.MODIFY_COEFFICIENT,
			1
		),
		_card(
			&"spade_link",
			"桥接",
			CardDefinition.TargetType.GAP,
			EffectSpec.Operation.LINK_NEIGHBORS,
			1
		),
		_card(
			&"heart_reverse",
			"倒序",
			CardDefinition.TargetType.GLOBAL,
			EffectSpec.Operation.REVERSE_RESOLUTION,
			0
		),
	]

static func _rule(
	id: StringName,
	display_name: String,
	condition_type: RuleDefinition.ConditionType,
	slot_count: int,
	coefficient: int,
	target_value: int = 0
) -> RuleDefinition:
	var rule := RuleDefinition.new()
	rule.id = id
	rule.display_name = display_name
	rule.condition_type = condition_type
	rule.slot_count = slot_count
	rule.coefficient = coefficient
	rule.target_value = target_value
	return rule

static func _card(
	id: StringName,
	display_name: String,
	target_type: CardDefinition.TargetType,
	operation: EffectSpec.Operation,
	amount: int
) -> CardDefinition:
	var effect := EffectSpec.new()
	effect.operation = operation
	effect.amount = amount
	var card := CardDefinition.new()
	card.id = id
	card.display_name = display_name
	card.target_type = target_type
	card.effects = [effect]
	return card
