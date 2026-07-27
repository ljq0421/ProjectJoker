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
		if card.rule_text.strip_edges().is_empty():
			errors.append("card %s has no rule text" % card.id)
		if card.tags.is_empty():
			errors.append("card %s has no display tags" % card.id)
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
					if card.target_type not in [
						CardDefinition.TargetType.TABLE,
						CardDefinition.TargetType.GAP,
					]:
						errors.append(
							"card %s coefficient effect requires a table or gap target"
							% card.id
						)
					if effect.amount == 0:
						errors.append("card %s coefficient amount cannot be zero" % card.id)
				EffectSpec.Operation.REPEAT_TABLE:
					if card.target_type not in [
						CardDefinition.TargetType.TABLE,
						CardDefinition.TargetType.GAP,
					]:
						errors.append(
							"card %s repeat effect requires a table or gap target"
							% card.id
						)
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
		if not card.mirror_effects.is_empty():
			if card.target_type != CardDefinition.TargetType.GAP:
				errors.append(
					"card %s mirror effects require a gap target" % card.id
				)
			for effect in card.mirror_effects:
				if effect.operation not in [
					EffectSpec.Operation.MODIFY_COEFFICIENT,
					EffectSpec.Operation.REPEAT_TABLE,
					EffectSpec.Operation.LINK_NEIGHBORS,
				]:
					errors.append(
						"card %s has forbidden mirror operation" % card.id
					)
					continue
				match effect.operation:
					EffectSpec.Operation.MODIFY_COEFFICIENT:
						if effect.amount == 0:
							errors.append(
								"card %s mirror coefficient amount cannot be zero"
								% card.id
							)
					EffectSpec.Operation.REPEAT_TABLE:
						if effect.amount < 1:
							errors.append(
								"card %s mirror repeat amount must be positive"
								% card.id
							)
					EffectSpec.Operation.LINK_NEIGHBORS:
						if effect.amount != 1:
							errors.append(
								"card %s mirror link amount must equal one"
								% card.id
							)
	return errors

func validate_dealers(dealers: Array) -> Array[String]:
	var errors: Array[String] = []
	var seen: Dictionary = {}
	for dealer in dealers:
		if dealer == null:
			errors.append("dealer resource is null")
			continue
		if dealer.id == &"":
			errors.append("dealer ID is empty")
		elif seen.has(dealer.id):
			errors.append("duplicate dealer ID: %s" % dealer.id)
		else:
			seen[dealer.id] = true
		if dealer.display_name.strip_edges().is_empty():
			errors.append("dealer %s has no display name" % dealer.id)
		if dealer.rule_text.strip_edges().is_empty():
			errors.append("dealer %s has no rule text" % dealer.id)
		if dealer.fixed_reward <= 0:
			errors.append("dealer %s reward must be positive" % dealer.id)
		if dealer.penalty_per_unassigned_die <= 0:
			errors.append("dealer %s penalty must be positive" % dealer.id)
		if dealer.fixed_reward - dealer.penalty_per_unassigned_die * 6 < 0:
			errors.append("dealer %s penalty exceeds full reward" % dealer.id)
		if dealer.tags.is_empty():
			errors.append("dealer %s has no display tags" % dealer.id)
	return errors

func validate_restriction(
	restriction: FinalRestrictionDefinition
) -> Array[String]:
	if restriction == null:
		return ["restriction resource is null"]
	return restriction.validate()

func validate_round_schedule(schedule: DealerRoundSchedule) -> Array[String]:
	if schedule == null:
		return ["dealer round schedule resource is null"]
	return schedule.validate()

func validate_engravings(engravings: Array) -> Array[String]:
	var errors: Array[String] = []
	var seen: Dictionary = {}
	for engraving in engravings:
		if engraving == null:
			errors.append("engraving resource is null")
			continue
		if engraving.id == &"":
			errors.append("engraving ID is empty")
		elif seen.has(engraving.id):
			errors.append("duplicate engraving ID: %s" % engraving.id)
		else:
			seen[engraving.id] = true
		if engraving.display_name.strip_edges().is_empty():
			errors.append("engraving %s has no display name" % engraving.id)
		if engraving.rule_text.strip_edges().is_empty():
			errors.append("engraving %s has no rule text" % engraving.id)
		if engraving.tags.is_empty():
			errors.append("engraving %s has no display tags" % engraving.id)
		match engraving.operation:
			EngravingDefinition.Operation.ECHO_ADJACENT:
				if engraving.amount < 1:
					errors.append("echo engraving divisor must be positive")
			EngravingDefinition.Operation.ANCHOR_DIE:
				if engraving.amount < 1:
					errors.append("anchor engraving reward must be positive")
			EngravingDefinition.Operation.BRIDGE_FORWARD, EngravingDefinition.Operation.BRIDGE_BACKWARD:
				if engraving.amount != 1:
					errors.append("bridge engraving amount must equal one")
			EngravingDefinition.Operation.PRISM_PARITY, EngravingDefinition.Operation.MIRROR_PRISM:
				if engraving.amount != 0:
					errors.append("prism engraving amount must equal zero")
			_:
				errors.append("engraving %s has unknown operation" % engraving.id)
	return errors

func validate_rooms(rooms: Array) -> Array[String]:
	var errors: Array[String] = []
	var seen: Dictionary = {}
	for room in rooms:
		if room == null:
			errors.append("room resource is null")
			continue
		if room.id == &"":
			errors.append("room ID is empty")
		elif seen.has(room.id):
			errors.append("duplicate room ID: %s" % room.id)
		else:
			seen[room.id] = true
		if room.display_name.strip_edges().is_empty():
			errors.append("room %s has no display name" % room.id)
		if room.description.strip_edges().is_empty():
			errors.append("room %s has no description" % room.id)
		if room.target_total <= 0:
			errors.append("room %s target must be positive" % room.id)
		if room.success_intel_reward < 0:
			errors.append("room %s reward cannot be negative" % room.id)
		if room.tags.is_empty():
			errors.append("room %s has no display tags" % room.id)
		if room.synergy_tags.is_empty():
			errors.append("room %s has no synergy tags" % room.id)
		if room.restriction != null:
			errors.append_array(validate_restriction(room.restriction))
		if room.encounter == null:
			errors.append("room %s has no encounter" % room.id)
			continue
		if room.encounter.rules.size() != 3:
			errors.append("room %s must contain exactly three rules" % room.id)
		var slot_total := 0
		for rule in room.encounter.rules:
			if rule != null:
				slot_total += rule.slot_count
		if slot_total != 6:
			errors.append("room %s must contain exactly six slots" % room.id)
		errors.append_array(validate(room.encounter.rules, []))
	return errors
