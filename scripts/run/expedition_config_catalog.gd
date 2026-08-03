class_name ExpeditionConfigCatalog
extends RefCounted

const BuildIdentities = preload("res://scripts/run/build_identity_catalog.gd")

const DICE_CONTROL := &"dice_control"
const TABLE_CHAIN := &"table_chain"
const INTEL_ECONOMY := &"intel_economy"

const HIGH_PRESSURE := &"high_pressure"
const SHORT_HAND := &"short_hand"
const INTEL_SQUEEZE := &"intel_squeeze"
const MARKET_SURGE := &"market_surge"
const NO_UNDO := &"no_undo"
const FULL_TABLE_RULE := &"full_table_rule"

const MAX_CHALLENGES := 2

var _decks: Array[Dictionary] = [
	{
		"id": DICE_CONTROL,
		"identity_id": DICE_CONTROL,
		"display_name": "骰值控制",
		"description": "直接调整、交换、复制与锁定骰值，先把点数变成可控变量。",
		"card_ids": [
			&"starter_nudge_down_1",
			&"starter_nudge_up_1",
			&"starter_nudge_down_2",
			&"starter_nudge_up_2",
			&"faceless_swap_values",
			&"faceless_copy_value",
			&"faceless_flip_value",
			&"faceless_lock_bonus",
			&"starter_map_1",
			&"starter_map_2",
			&"starter_repeat_1",
			&"starter_link",
		],
	},
	{
		"id": TABLE_CHAIN,
		"identity_id": TABLE_CHAIN,
		"display_name": "规则台连锁",
		"description": "围绕映射、重复、桥接与反向结算制造连续解析。",
		"card_ids": [
			&"starter_map_1",
			&"starter_map_2",
			&"starter_repeat_1",
			&"starter_repeat_2",
			&"starter_stable_repeat",
			&"starter_amplified_repeat",
			&"starter_reverse",
			&"starter_link",
			&"mirror_folded_map",
			&"mirror_soft_echo",
			&"mirror_hinged_bridge",
			&"faceless_compressed_repeat",
		],
	},
	{
		"id": INTEL_ECONOMY,
		"identity_id": INTEL_ECONOMY,
		"display_name": "情报经济",
		"description": "用条件结算换取情报券，并以容错牌维持稳定收益。",
		"card_ids": [
			&"faceless_refund_calibration",
			&"faceless_table_receipt",
			&"faceless_full_allocation",
			&"faceless_three_seats",
			&"faceless_complete_dossier",
			&"faceless_exact_tolerance",
			&"faceless_even_tolerance",
			&"faceless_sequence_tolerance",
			&"starter_nudge_down_1",
			&"starter_nudge_up_1",
			&"starter_map_1",
			&"starter_repeat_1",
		],
	},
]

var _challenges: Array[Dictionary] = [
	{
		"id": HIGH_PRESSURE,
		"display_name": "高压合约",
		"description": "普通房与庄家累计目标提高 15%，向上取整。",
	},
	{
		"id": SHORT_HAND,
		"display_name": "精简手牌",
		"description": "非固定手牌活动每轮只抽三张；固定谜题不受影响。",
	},
	{
		"id": INTEL_SQUEEZE,
		"display_name": "情报紧缩",
		"description": "普通房基础成功情报奖励减少 1，最低为 0。",
	},
	{
		"id": MARKET_SURGE,
		"display_name": "黑市涨价",
		"description": "换牌、刷新和购买情报各增加 1 情报券。",
	},
	{
		"id": NO_UNDO,
		"display_name": "落子无悔",
		"description": "遭遇中禁止撤销，所有落子都必须当场承担。",
	},
	{
		"id": FULL_TABLE_RULE,
		"display_name": "全台公开",
		"description": "每轮提交时三张可见规则台都必须至少分配一颗骰子。",
	},
]

func all_decks() -> Array[Dictionary]:
	return _decks.duplicate(true)

func all_challenges() -> Array[Dictionary]:
	return _challenges.duplicate(true)

func deck_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for definition in _decks:
		ids.append(definition["id"])
	return ids

func recommended_deck_id() -> StringName:
	return DICE_CONTROL

func challenge_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for definition in _challenges:
		ids.append(definition["id"])
	return ids

func find_deck(deck_id: StringName) -> Dictionary:
	for definition in _decks:
		if definition["id"] == deck_id:
			return definition.duplicate(true)
	return {}

func find_challenge(challenge_id: StringName) -> Dictionary:
	for definition in _challenges:
		if definition["id"] == challenge_id:
			return definition.duplicate(true)
	return {}

func selection_error(
	deck_id: StringName,
	selected_challenge_ids: Array,
	challenges_unlocked: bool
) -> String:
	if find_deck(deck_id).is_empty():
		return "未知起始牌组：%s" % deck_id
	if selected_challenge_ids.size() > MAX_CHALLENGES:
		return "单局最多启用两项挑战"
	if not selected_challenge_ids.is_empty() and not challenges_unlocked:
		return "完成一次完整三区远征后才会开放挑战"
	var seen: Dictionary = {}
	for challenge_id in selected_challenge_ids:
		if challenge_id not in challenge_ids():
			return "未知挑战：%s" % challenge_id
		if seen.has(challenge_id):
			return "挑战不能重复：%s" % challenge_id
		seen[challenge_id] = true
	return ""

func validate(card_catalog: CardCatalog = null) -> Array[String]:
	var errors: Array[String] = []
	var cards := card_catalog if card_catalog != null else CardCatalog.new()
	var identities := BuildIdentities.new()
	var seen_decks: Dictionary = {}
	for definition in _decks:
		var deck_id: StringName = definition.get("id", &"")
		if deck_id == &"" or seen_decks.has(deck_id):
			errors.append("starting deck ID is empty or duplicated: %s" % deck_id)
			continue
		seen_decks[deck_id] = true
		var card_ids: Array = definition.get("card_ids", [])
		if card_ids.size() != 12:
			errors.append("starting deck %s must contain twelve cards" % deck_id)
		var seen_cards: Dictionary = {}
		var identity_count := 0
		for card_id in card_ids:
			var card := cards.find_card(card_id)
			if card == null:
				errors.append("starting deck %s contains unknown card %s" % [deck_id, card_id])
				continue
			if seen_cards.has(card_id):
				errors.append("starting deck %s repeats card %s" % [deck_id, card_id])
			seen_cards[card_id] = true
			if identities.identity_for_card(card) == definition.get("identity_id", &""):
				identity_count += 1
		if identity_count < 5:
			errors.append("starting deck %s does not express its identity" % deck_id)
	var seen_challenges: Dictionary = {}
	for definition in _challenges:
		var challenge_id: StringName = definition.get("id", &"")
		if challenge_id == &"" or seen_challenges.has(challenge_id):
			errors.append("challenge ID is empty or duplicated: %s" % challenge_id)
		seen_challenges[challenge_id] = true
		if String(definition.get("display_name", "")).strip_edges().is_empty():
			errors.append("challenge %s has no display name" % challenge_id)
		if String(definition.get("description", "")).strip_edges().is_empty():
			errors.append("challenge %s has no description" % challenge_id)
	return errors
