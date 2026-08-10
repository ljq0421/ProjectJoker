class_name SpecialRoomCatalog
extends RefCounted

const MIRROR_ELITE_ID := &"mirror_reflection_elite"
const MIRROR_ELITE_TARGET := 150
const MIRROR_ELITE_ROUNDS := 2
const MIRROR_ELITE_REWARD := 3

func mirror_elite_encounter() -> EncounterDefinition:
	var encounter := EncounterDefinition.new()
	encounter.id = MIRROR_ELITE_ID
	var ids: Array[StringName] = [&"left", &"middle", &"right"]
	var names := ["双生牌面", "反照席位", "回折机关"]
	for index in range(3):
		var rule := RuleDefinition.new()
		rule.id = ids[index]
		rule.display_name = names[index]
		rule.condition_type = RuleDefinition.ConditionType.EXACT_SUM
		rule.target_value = 7
		rule.slot_count = 2
		rule.coefficient = 4
		encounter.rules.append(rule)
	return encounter

func choice_options() -> Array[Dictionary]:
	return [
		{
			"id": &"raise_target",
			"title": "加压契据",
			"cost": "下一场目标 +10%",
			"reward": "立即获得 3 情报",
		},
		{
			"id": &"buy_calibration",
			"title": "预付校准",
			"cost": "支付 2 情报",
			"reward": "下一场首轮校准 +2",
		},
		{
			"id": &"remove_card",
			"title": "注销牌页",
			"cost": "牌组必须大于 12 张",
			"reward": "免费移除 1 张牌",
		},
	]
