class_name EncounterRunSetup
extends RefCounted

var run_rng: RunRng
var deck_ids: Array[StringName] = []
var encounter: EncounterDefinition
var round_schedule: DealerRoundSchedule
var round_plans: Array[EncounterRoundPlan] = []
var round_count := 3
var fixed_hand_ids: Array[StringName] = []
var fixed_restriction: FinalRestrictionDefinition
var resolution_context: ResolutionContext
var success_intel_reward: int = 2
var prepare_shop_offers: bool = true
var die_profiles: Array[DieState] = []
var forced_rolls: Dictionary = {}
