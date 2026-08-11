class_name ContentValidator
extends RefCounted

const BuildIdentities = preload("res://scripts/run/build_identity_catalog.gd")
const SuitRules = preload("res://scripts/cards/card_suit_rules.gd")

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
		errors.append_array(_validate_rule_parameters(rule))
	for rule_index in range(rules.size()):
		var rule: RuleDefinition = rules[rule_index]
		if (
			rule.template != null
			and rule.template.post_pass_effect
				== RuleTableTemplate.PostPassEffect.BRIDGE_FORWARD
			and (rules.size() != 3 or rule_index != 1)
		):
			errors.append(
				"rule %s bridge template must occupy the middle track"
				% rule.id
			)

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
		if card.suit not in [
			CardDefinition.Suit.CLUBS,
			CardDefinition.Suit.HEARTS,
			CardDefinition.Suit.DIAMONDS,
			CardDefinition.Suit.SPADES,
		]:
			errors.append("card %s has an unknown suit" % card.id)
		if card.rank_label.strip_edges().is_empty():
			errors.append("card %s has no rank label" % card.id)
		if card.rarity not in [
			CardDefinition.Rarity.COMMON,
			CardDefinition.Rarity.UNCOMMON,
			CardDefinition.Rarity.RARE,
		]:
			errors.append("card %s has an unknown rarity" % card.id)
		if card.effects.is_empty():
			errors.append("card %s has no effects" % card.id)
		var suit_error := SuitRules.validation_error(card)
		if not suit_error.is_empty():
			errors.append(suit_error)
		for effect in card.effects:
			match effect.operation:
				EffectSpec.Operation.ADJUST_DIE:
					if card.target_type != CardDefinition.TargetType.DIE:
						errors.append("card %s adjust-die effect requires a die target" % card.id)
					if effect.amount == 0:
						errors.append("card %s adjust-die amount cannot be zero" % card.id)
				EffectSpec.Operation.SWAP_DICE:
					if card.target_type != CardDefinition.TargetType.DICE_PAIR:
						errors.append(
							"card %s pair-die effect requires a dice-pair target"
							% card.id
						)
					if effect.amount < 0:
						errors.append(
							"card %s swap coefficient bonus cannot be negative"
							% card.id
						)
				EffectSpec.Operation.COPY_DIE:
					if card.target_type != CardDefinition.TargetType.DICE_PAIR:
						errors.append(
							"card %s pair-die effect requires a dice-pair target"
							% card.id
						)
					if effect.amount != 0:
						errors.append(
							"card %s copy-die amount must equal zero" % card.id
						)
				EffectSpec.Operation.FLIP_DIE:
					if card.target_type != CardDefinition.TargetType.DIE:
						errors.append(
							"card %s flip-die effect requires a die target" % card.id
						)
					if effect.amount != 0:
						errors.append(
							"card %s flip-die amount must equal zero" % card.id
						)
				EffectSpec.Operation.LOCK_DIE_WITH_BONUS:
					if card.target_type != CardDefinition.TargetType.DIE:
						errors.append(
							"card %s lock-die effect requires a die target" % card.id
						)
					if effect.amount < 1:
						errors.append(
							"card %s lock bonus must be positive" % card.id
						)
				EffectSpec.Operation.REFUND_CALIBRATION:
					if card.target_type != CardDefinition.TargetType.GLOBAL:
						errors.append(
							"card %s calibration refund requires a global target"
							% card.id
						)
					if effect.amount != 1:
						errors.append(
							"card %s calibration refund must equal one" % card.id
						)
				EffectSpec.Operation.MODIFY_CONDITION:
					if card.target_type != CardDefinition.TargetType.TABLE:
						errors.append(
							"card %s condition modifier requires a table target"
							% card.id
						)
					if effect.amount != 1:
						errors.append(
							"card %s condition modifier amount must equal one"
							% card.id
						)
					if effect.condition_modifier not in [
						EffectSpec.ConditionModifier.EXACT_TOLERANCE,
						EffectSpec.ConditionModifier.ALLOW_ONE_ODD,
						EffectSpec.ConditionModifier.ALLOW_ONE_GAP,
						EffectSpec.ConditionModifier.INCREASE_SLOT_COUNT,
					]:
						errors.append(
							"card %s has an unknown condition modifier" % card.id
						)
				EffectSpec.Operation.GRANT_INTEL_ON_CONDITION:
					if effect.amount < 1:
						errors.append(
							"card %s intel reward must be positive" % card.id
						)
					if effect.intel_condition not in [
						EffectSpec.IntelCondition.TARGET_TABLE_PASSED,
						EffectSpec.IntelCondition.ALL_DICE_ASSIGNED,
						EffectSpec.IntelCondition.ALL_TABLES_OCCUPIED,
						EffectSpec.IntelCondition.ALL_TABLES_PASSED,
					]:
						errors.append(
							"card %s has an unknown intel condition" % card.id
						)
					elif (
						effect.intel_condition
						== EffectSpec.IntelCondition.TARGET_TABLE_PASSED
					):
						if card.target_type != CardDefinition.TargetType.TABLE:
							errors.append(
								"card %s target-table intel requires a table target"
								% card.id
							)
					elif card.target_type != CardDefinition.TargetType.GLOBAL:
						errors.append(
							"card %s global intel condition requires a global target"
							% card.id
						)
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
					if card.target_type not in [
						CardDefinition.TargetType.GLOBAL,
						CardDefinition.TargetType.GAP,
					]:
						errors.append(
							"card %s reverse effect requires a global or gap target"
							% card.id
						)
				EffectSpec.Operation.LINK_NEIGHBORS:
					if card.target_type != CardDefinition.TargetType.GAP:
						errors.append("card %s link effect requires a gap target" % card.id)
					if effect.amount != 1:
						errors.append("card %s link amount must equal one" % card.id)
				EffectSpec.Operation.QUEUE_SEARCH:
					if card.target_type != CardDefinition.TargetType.GLOBAL:
						errors.append(
							"card %s queued search requires a global target" % card.id
						)
					if effect.search_identity not in BuildIdentities.IDS:
						errors.append(
							"card %s has an unknown search identity" % card.id
						)
				EffectSpec.Operation.FAULT_DIE:
					if card.target_type != CardDefinition.TargetType.DIE:
						errors.append("card %s fault effect requires a die target" % card.id)
					if effect.amount != 3:
						errors.append("card %s fault coefficient must equal three" % card.id)
				EffectSpec.Operation.ALL_IN:
					if card.target_type != CardDefinition.TargetType.GLOBAL:
						errors.append("card %s all-in effect requires a global target" % card.id)
				EffectSpec.Operation.GRANT_UNDOS:
					if card.target_type != CardDefinition.TargetType.GLOBAL:
						errors.append("card %s undo grant requires a global target" % card.id)
					if effect.amount != 1:
						errors.append("card %s undo grant must equal one" % card.id)
				EffectSpec.Operation.BURNED_REWRITE:
					if card.target_type != CardDefinition.TargetType.TABLE:
						errors.append("card %s burned rewrite requires a table target" % card.id)
					if effect.amount != 1:
						errors.append("card %s burned rewrite amount must equal one" % card.id)
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

func _validate_rule_parameters(rule: RuleDefinition) -> Array[String]:
	var errors: Array[String] = []
	if rule.template == null:
		if (
			rule.condition_type == RuleDefinition.ConditionType.EXACT_SUM
			and (
				rule.target_value < rule.slot_count
				or rule.target_value > rule.slot_count * 6
			)
		):
			errors.append("rule %s exact-sum target is unreachable" % rule.id)
		return errors

	errors.append_array(rule.template.validate())
	if (
		rule.slot_count < rule.template.minimum_slot_count
		or rule.slot_count > rule.template.maximum_slot_count
	):
		errors.append(
			"rule %s slot count is outside template range %d..%d"
			% [
				rule.id,
				rule.template.minimum_slot_count,
				rule.template.maximum_slot_count,
			]
		)
	var reachable_min := rule.slot_count
	var reachable_max := rule.slot_count * 6
	match rule.template.condition_kind:
		RuleTableTemplate.ConditionKind.EXACT_SUM, RuleTableTemplate.ConditionKind.MINIMUM_SUM, RuleTableTemplate.ConditionKind.MAXIMUM_SUM:
			if (
				rule.target_value < reachable_min
				or rule.target_value > reachable_max
			):
				errors.append("rule %s sum target is unreachable" % rule.id)
		RuleTableTemplate.ConditionKind.SUM_RANGE:
			if rule.minimum_value > rule.maximum_value:
				errors.append("rule %s sum range is inverted" % rule.id)
			if (
				rule.minimum_value < reachable_min
				or rule.maximum_value > reachable_max
			):
				errors.append("rule %s sum range is unreachable" % rule.id)
		RuleTableTemplate.ConditionKind.FIXED_DIFFERENCE:
			if rule.difference < 2 or rule.difference > 5:
				errors.append("rule %s fixed difference is outside 2..5" % rule.id)
			elif (rule.slot_count - 1) * rule.difference > 5:
				errors.append("rule %s fixed difference has no legal dice sample" % rule.id)
		RuleTableTemplate.ConditionKind.SLOT_TARGETS:
			if rule.slot_targets.size() != rule.slot_count:
				errors.append("rule %s slot targets do not match slot count" % rule.id)
			for target in rule.slot_targets:
				if target < 1 or target > 6:
					errors.append("rule %s slot target is outside 1..6" % rule.id)
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
		if dealer.opening_text.strip_edges().is_empty():
			errors.append("dealer %s has no opening text" % dealer.id)
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
			EngravingDefinition.Operation.ECHO_LOWER_ADJACENT:
				if engraving.amount != 0:
					errors.append("lower echo engraving amount must equal zero")
			EngravingDefinition.Operation.ANCHOR_LAST_TABLE:
				if engraving.amount < 1:
					errors.append("last-table anchor reward must be positive")
			EngravingDefinition.Operation.BRIDGE_BIDIRECTIONAL:
				if engraving.amount != 2:
					errors.append("bidirectional bridge divisor must equal two")
			EngravingDefinition.Operation.PRISM_SEQUENCE:
				if engraving.amount != 0:
					errors.append("sequence prism amount must equal zero")
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
		if room.build_identity_id not in BuildIdentities.new().all_ids():
			errors.append("room %s has an unknown build identity" % room.id)
		if room.round_count < 1 or room.round_count > 3:
			errors.append("room %s round count is outside 1..3" % room.id)
		match room.activity_kind:
			RoomDefinition.ActivityKind.STANDARD:
				if room.round_count != 3:
					errors.append("standard room %s must use three rounds" % room.id)
			RoomDefinition.ActivityKind.SINGLE_ROUND_CONTRACT:
				if room.round_count != 1:
					errors.append("single-round room %s must use one round" % room.id)
			RoomDefinition.ActivityKind.FIXED_HAND_PUZZLE:
				if room.fixed_hand_ids.size() != CardDeck.HAND_SIZE:
					errors.append("fixed-hand room %s must expose four cards" % room.id)
			RoomDefinition.ActivityKind.RULE_MUTATION:
				if room.round_plans.size() != room.round_count:
					errors.append(
						"mutation room %s plan count must match round count" % room.id
					)
		for plan in room.round_plans:
			if plan == null:
				errors.append("room %s contains a null round plan" % room.id)
			else:
				errors.append_array(plan.validate())
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
