class_name RunSnapshotCodec
extends RefCounted

static func round_state_to_snapshot(state: RoundState) -> Dictionary:
	var dice: Array[Dictionary] = []
	for die in state.dice:
		dice.append({
			"id": die.id,
			"rolled_value": die.rolled_value,
			"value": die.value,
			"engraving_id": die.engraving_id,
			"engraved_face": die.engraved_face,
		})
	var cards: Array[Dictionary] = []
	for card in state.played_cards:
		cards.append(played_card_to_snapshot(card))
	return {
		"dice": dice,
		"assignments": state.assignments.duplicate(true),
		"played_cards": cards,
		"calibration_points": state.calibration_points,
	}

static func round_state_from_snapshot(
	snapshot: Dictionary,
	catalog: CardCatalog
) -> RoundState:
	var state := RoundState.new()
	state.calibration_points = int(snapshot.get("calibration_points", 2))
	for entry in snapshot.get("dice", []):
		state.dice.append(DieState.new(
			entry.get("id", &""),
			int(entry.get("value", 1)),
			entry.get("engraving_id", &""),
			int(entry.get("engraved_face", 0)),
			int(entry.get("rolled_value", entry.get("value", 1)))
		))
	state.assignments = snapshot.get("assignments", {}).duplicate(true)
	for entry in snapshot.get("played_cards", []):
		var card := played_card_from_snapshot(entry, catalog)
		if card != null:
			state.played_cards.append(card)
	return state

static func played_card_to_snapshot(card: PlayedCard) -> Dictionary:
	var effects: Array[Dictionary] = []
	for effect in card.runtime_effects:
		effects.append(effect_to_snapshot(effect))
	return {
		"card_id": card.definition.id if card.definition != null else &"",
		"primary_target": card.primary_target,
		"secondary_target": card.secondary_target,
		"play_id": card.play_id,
		"is_mirror_copy": card.is_mirror_copy,
		"source_card_id": card.source_card_id,
		"source_play_id": card.source_play_id,
		"source_slot_id": card.source_slot_id,
		"runtime_effects": effects,
	}

static func played_card_from_snapshot(
	snapshot: Dictionary,
	catalog: CardCatalog
) -> PlayedCard:
	var definition := catalog.find_card(snapshot.get("card_id", &""))
	if definition == null:
		return null
	var card := PlayedCard.new(
		definition,
		snapshot.get("primary_target", &""),
		snapshot.get("secondary_target", &"")
	)
	card.play_id = snapshot.get("play_id", &"")
	card.is_mirror_copy = bool(snapshot.get("is_mirror_copy", false))
	card.source_card_id = snapshot.get("source_card_id", &"")
	card.source_play_id = snapshot.get("source_play_id", &"")
	card.source_slot_id = snapshot.get("source_slot_id", &"")
	for entry in snapshot.get("runtime_effects", []):
		card.runtime_effects.append(effect_from_snapshot(entry))
	return card

static func effect_to_snapshot(effect: EffectSpec) -> Dictionary:
	return {
		"operation": effect.operation,
		"amount": effect.amount,
		"condition_modifier": effect.condition_modifier,
		"intel_condition": effect.intel_condition,
		"search_identity": effect.search_identity,
	}

static func effect_from_snapshot(snapshot: Dictionary) -> EffectSpec:
	var effect := EffectSpec.new()
	effect.operation = snapshot.get("operation", EffectSpec.Operation.ADJUST_DIE)
	effect.amount = int(snapshot.get("amount", 0))
	effect.condition_modifier = snapshot.get(
		"condition_modifier", EffectSpec.ConditionModifier.EXACT_TOLERANCE
	)
	effect.intel_condition = snapshot.get(
		"intel_condition", EffectSpec.IntelCondition.TARGET_TABLE_PASSED
	)
	effect.search_identity = snapshot.get("search_identity", &"")
	return effect

static func report_to_snapshot(report: ResolutionReport) -> Dictionary:
	var events: Array[Dictionary] = []
	for event in report.events:
		events.append({
			"source_id": event.source_id,
			"label": event.label,
			"delta": event.delta,
			"running_total": event.running_total,
			"effect_applied": event.effect_applied,
			"is_mirror_copy": event.is_mirror_copy,
			"source_card_id": event.source_card_id,
			"source_slot_id": event.source_slot_id,
			"mirror_slot_id": event.mirror_slot_id,
			"score_source": event.score_source,
			"source_table_id": event.source_table_id,
			"target_table_id": event.target_table_id,
			"combo_kind": event.combo_kind,
			"source_die_id": event.source_die_id,
		})
	return {
		"valid": report.valid,
		"reason": report.reason,
		"restriction_satisfied": report.restriction_satisfied,
		"restriction_reason": report.restriction_reason,
		"total": report.total,
		"intel_delta": report.intel_delta,
		"events": events,
		"assigned_dice": report.assigned_dice,
		"unassigned_dice": report.unassigned_dice,
		"dealer_reward": report.dealer_reward,
		"dealer_reward_lost": report.dealer_reward_lost,
		"rule_failures": report.rule_failures.duplicate(true),
		"missed_effects": report.missed_effects.duplicate(),
		"effective_die_values": report.effective_die_values.duplicate(true),
		"effective_table_coefficients": report.effective_table_coefficients.duplicate(true),
		"table_resolution_counts": report.table_resolution_counts.duplicate(true),
		"resolution_direction": report.resolution_direction,
		"ordered_rule_ids": report.ordered_rule_ids.duplicate(),
		"passed_rule_count": report.passed_rule_count,
		"consolation_awarded": report.consolation_awarded,
		"resonance_awarded": report.resonance_awarded,
		"full_clear_calibration_awarded": report.full_clear_calibration_awarded,
		"successful_bridge_count": report.successful_bridge_count,
		"storm_awarded": report.storm_awarded,
		"score_breakdown": report.score_breakdown.duplicate(true),
	}

static func report_from_snapshot(snapshot: Dictionary) -> ResolutionReport:
	var report := ResolutionReport.new()
	for property in [
		"valid", "reason", "restriction_satisfied", "restriction_reason",
		"total", "intel_delta", "assigned_dice", "unassigned_dice",
		"dealer_reward", "dealer_reward_lost", "resolution_direction",
		"passed_rule_count", "consolation_awarded", "resonance_awarded",
		"full_clear_calibration_awarded", "successful_bridge_count",
		"storm_awarded",
	]:
		report.set(property, snapshot.get(property, report.get(property)))
	report.rule_failures.assign(snapshot.get("rule_failures", []).duplicate(true))
	report.missed_effects.assign(snapshot.get("missed_effects", []))
	report.effective_die_values = snapshot.get("effective_die_values", {}).duplicate(true)
	report.effective_table_coefficients = snapshot.get(
		"effective_table_coefficients", {}
	).duplicate(true)
	report.table_resolution_counts = snapshot.get("table_resolution_counts", {}).duplicate(true)
	report.ordered_rule_ids.assign(snapshot.get("ordered_rule_ids", []))
	report.score_breakdown = snapshot.get("score_breakdown", {}).duplicate(true)
	for entry in snapshot.get("events", []):
		report.events.append(ResolutionEvent.new(
			entry.get("source_id", &""),
			entry.get("label", ""),
			int(entry.get("delta", 0)),
			int(entry.get("running_total", 0)),
			bool(entry.get("effect_applied", true)),
			bool(entry.get("is_mirror_copy", false)),
			entry.get("source_card_id", &""),
			entry.get("source_slot_id", &""),
			entry.get("mirror_slot_id", &""),
			entry.get("score_source", ResolutionEvent.ScoreSource.BASE),
			entry.get("source_table_id", &""),
			entry.get("target_table_id", &""),
			entry.get("combo_kind", &""),
			entry.get("source_die_id", &"")
		))
	return report
