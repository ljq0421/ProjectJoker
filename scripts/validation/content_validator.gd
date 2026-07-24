class_name ContentValidator
extends RefCounted

func validate(rules: Array, cards: Array) -> Array[String]:
	var errors: Array[String] = []
	var seen_rule_ids := {}
	for rule in rules:
		if rule.id == &"":
			errors.append("rule ID is empty")
		elif seen_rule_ids.has(rule.id):
			errors.append("duplicate rule ID: %s" % rule.id)
		else:
			seen_rule_ids[rule.id] = true
		if rule.display_name.strip_edges().is_empty():
			errors.append("rule %s has no display name" % rule.id)
		if rule.slot_count < 1 or rule.slot_count > 6:
			errors.append("rule %s slot count is outside 1..6" % rule.id)
		if rule.coefficient < 1:
			errors.append("rule %s coefficient must be positive" % rule.id)
		if (
			rule.condition_type == RuleDefinition.ConditionType.EXACT_SUM
			and (
				rule.target_value < rule.slot_count
				or rule.target_value > rule.slot_count * 6
			)
		):
			errors.append("rule %s exact-sum target is unreachable" % rule.id)

	var seen_card_ids := {}
	for card in cards:
		if card.id == &"":
			errors.append("card ID is empty")
		elif seen_card_ids.has(card.id):
			errors.append("duplicate card ID: %s" % card.id)
		else:
			seen_card_ids[card.id] = true
		if card.display_name.strip_edges().is_empty():
			errors.append("card %s has no display name" % card.id)
		if card.effects.is_empty():
			errors.append("card %s has no effects" % card.id)
		for effect in card.effects:
			match effect.operation:
				EffectSpec.Operation.ADJUST_DIE:
					if card.target_type != CardDefinition.TargetType.DIE:
						errors.append("card %s adjust-die effect requires a die target" % card.id)
					if effect.amount == 0:
						errors.append("card %s adjust-die amount cannot be zero" % card.id)
				EffectSpec.Operation.MODIFY_COEFFICIENT:
					if card.target_type != CardDefinition.TargetType.TABLE:
						errors.append("card %s coefficient effect requires a table target" % card.id)
					if effect.amount == 0:
						errors.append("card %s coefficient amount cannot be zero" % card.id)
				EffectSpec.Operation.REPEAT_TABLE:
					if card.target_type != CardDefinition.TargetType.TABLE:
						errors.append("card %s repeat effect requires a table target" % card.id)
					if effect.amount < 1:
						errors.append("card %s repeat amount must be positive" % card.id)
				EffectSpec.Operation.REVERSE_RESOLUTION:
					if card.target_type != CardDefinition.TargetType.GLOBAL:
						errors.append("card %s reverse effect requires a global target" % card.id)
				EffectSpec.Operation.LINK_NEIGHBORS:
					if card.target_type != CardDefinition.TargetType.GAP:
						errors.append("card %s link effect requires a gap target" % card.id)
					if effect.amount != 1:
						errors.append("card %s link amount must equal one" % card.id)
	return errors
