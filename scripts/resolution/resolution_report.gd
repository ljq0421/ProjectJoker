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
var dealer_reward: int = 0
var dealer_reward_lost: int = 0
var resolution_direction: EncounterRuleProfile.ResolutionDirection = (
	EncounterRuleProfile.ResolutionDirection.LEFT_TO_RIGHT
)
var ordered_rule_ids: Array[StringName] = []

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
