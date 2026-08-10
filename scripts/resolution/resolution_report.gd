class_name ResolutionReport
extends RefCounted

var valid: bool = true
var reason: String = ""
var restriction_satisfied: bool = true
var restriction_reason: String = ""
var total: int = 0
var intel_delta: int = 0
var events: Array[ResolutionEvent] = []
var assigned_dice: int = 0
var unassigned_dice: int = 0
var calibration_actions := 0
var dealer_reward: int = 0
var dealer_reward_lost: int = 0
var rule_failures: Array[Dictionary] = []
var missed_effects: Array[String] = []
var effective_die_values: Dictionary = {}
var effective_table_coefficients: Dictionary = {}
var table_resolution_counts: Dictionary = {}
var resolution_direction: EncounterRuleProfile.ResolutionDirection = (
	EncounterRuleProfile.ResolutionDirection.LEFT_TO_RIGHT
)
var ordered_rule_ids: Array[StringName] = []
var passed_rule_count := 0
var consolation_awarded := false
var resonance_awarded := false
var full_clear_calibration_awarded := false
var successful_bridge_count := 0
var storm_awarded := false
var all_in_awarded := false
var all_in_bonus_intel := 0
var engraving_set_activations: Array[StringName] = []
var score_breakdown: Dictionary = {
	ResolutionEvent.ScoreSource.BASE: 0,
	ResolutionEvent.ScoreSource.COEFFICIENT: 0,
	ResolutionEvent.ScoreSource.CARD: 0,
	ResolutionEvent.ScoreSource.RULE_CHAIN: 0,
	ResolutionEvent.ScoreSource.ENGRAVING: 0,
	ResolutionEvent.ScoreSource.AREA_MODIFIER: 0,
	ResolutionEvent.ScoreSource.LUCK: 0,
	ResolutionEvent.ScoreSource.DEALER: 0,
}

func add_score(source: ResolutionEvent.ScoreSource, delta: int) -> void:
	score_breakdown[source] = int(score_breakdown.get(source, 0)) + delta
	total += delta

func record_score(source: ResolutionEvent.ScoreSource, delta: int) -> void:
	score_breakdown[source] = int(score_breakdown.get(source, 0)) + delta

func event_signature() -> Array[String]:
	var signature: Array[String] = []
	for event in events:
		signature.append("%s|%s|%d|%d|%s" % [
			event.source_id,
			event.label,
			event.delta,
			event.running_total,
			str(event.effect_applied),
		])
	return signature
