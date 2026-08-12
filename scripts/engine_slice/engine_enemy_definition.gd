class_name EngineEnemyDefinition
extends Resource

@export var id: StringName
@export var display_name := ""
@export_multiline var subtitle := ""
@export var max_health := 32
@export var enrage_turn := 5
@export var portrait_path := ""
@export var attack_rule: Dictionary = {}
@export var guard_rule: Dictionary = {}
@export var engine_rule: Dictionary = {}
@export var phase_two_threshold := 0.5
@export var intent_ids: Array[StringName] = []
@export var phase_two_intent_ids: Array[StringName] = []

