class_name ExpeditionChallengeRules
extends RefCounted

const ExpeditionConfigs = preload("res://scripts/run/expedition_config_catalog.gd")

var challenge_ids: Array[StringName] = []

func _init(p_challenge_ids: Array = []) -> void:
	challenge_ids.assign(p_challenge_ids)

func has(challenge_id: StringName) -> bool:
	return challenge_id in challenge_ids

func target_total(base_target: int) -> int:
	return target_total_with_multiplier(base_target, 1.0)

func target_total_with_multiplier(base_target: int, multiplier: float) -> int:
	var combined := multiplier
	if has(ExpeditionConfigs.HIGH_PRESSURE):
		combined *= 1.15
	return int(ceili(float(base_target) * combined))

func hand_size(fixed_hand: bool) -> int:
	if has(ExpeditionConfigs.SHORT_HAND) and not fixed_hand:
		return 3
	return CardDeck.HAND_SIZE

func intel_reward(base_reward: int) -> int:
	if has(ExpeditionConfigs.INTEL_SQUEEZE):
		return maxi(base_reward - 1, 0)
	return base_reward

func shop_price(base_price: int) -> int:
	if has(ExpeditionConfigs.MARKET_SURGE):
		return base_price + 1
	return base_price

func undo_allowed() -> bool:
	return true

func undo_mode() -> RoundController.UndoMode:
	return (
		RoundController.UndoMode.GLOBAL_ONE
		if has(ExpeditionConfigs.NO_UNDO)
		else RoundController.UndoMode.SPLIT
	)

func full_table_required() -> bool:
	return has(ExpeditionConfigs.FULL_TABLE_RULE)

func full_table_restriction() -> FinalRestrictionDefinition:
	if not full_table_required():
		return null
	var restriction := FinalRestrictionDefinition.new()
	restriction.id = &"challenge_full_table"
	restriction.display_name = "全台公开"
	restriction.rule_text = "每轮提交时三张可见规则台都必须至少分配一颗骰子。"
	restriction.category = FinalRestrictionDefinition.Category.DISTRIBUTION
	restriction.operation = FinalRestrictionDefinition.Operation.REQUIRE_ALL_TABLES_OCCUPIED
	restriction.amount = 3
	return restriction

func display_copy(catalog = null) -> String:
	if challenge_ids.is_empty():
		return "无挑战"
	var definitions = catalog if catalog != null else ExpeditionConfigs.new()
	var names: Array[String] = []
	for challenge_id in challenge_ids:
		var definition: Dictionary = definitions.find_challenge(challenge_id)
		names.append(
			String(challenge_id)
			if definition.is_empty()
			else String(definition["display_name"])
		)
	return "、".join(names)
