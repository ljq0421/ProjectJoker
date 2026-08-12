class_name EngineBattleReport
extends RefCounted

var valid := true
var reason := ""
var attack_passed := false
var guard_passed := false
var engine_passed := false
var damage := 0
var attack_damage := 0
var engine_damage := 0
var counter_damage := 0
var total_damage := 0
var block := 0
var block_absorbed := 0
var engine_dice := 0
var engine_charge_before := 0
var engine_charge_gained := 0
var engine_charge_after := 0
var burst_count := 0
var retained_block_after := 0
var incoming_before_block := 0
var incoming_damage := 0
var enemy_health_after := 0
var player_health_after := 0
var enemy_defeated := false
var player_defeated := false
var intent_cancelled := false
var intent_id: StringName
var intent_copy := ""
var events: Array[String] = []

func summary() -> String:
	if intent_cancelled:
		return "行动前伤害 %d（破绽 %d / 爆破 %d）· 意图取消 · 对手已击破" % [damage, attack_damage, engine_damage]
	return "行动前 %d · 格挡 %d/吸收%d · 承受 %d · 行动后反击 %d · 充能 %d→%d" % [damage, block, block_absorbed, incoming_damage, counter_damage, engine_charge_before, engine_charge_after]
