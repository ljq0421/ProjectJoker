class_name ShopSession
extends RefCounted

const CARD_PRICE := 1

var catalog: CardCatalog
var deck_ids: Array[StringName] = []
var offer_ids: Array[StringName] = []
var sold_offer_ids: Array[StringName] = []
var purchase_records: Array[ShopPurchaseRecord] = []
var intel_tickets: int
var last_error: String = ""

func _init(
	p_catalog: CardCatalog,
	p_deck_ids: Array[StringName],
	p_offer_ids: Array[StringName],
	p_intel_tickets: int
) -> void:
	catalog = p_catalog
	deck_ids = p_deck_ids.duplicate()
	offer_ids = p_offer_ids.duplicate()
	intel_tickets = p_intel_tickets

func purchase(offer_id: StringName, replaced_id: StringName) -> OperationResult:
	if offer_id not in offer_ids:
		return _fail("候选牌不在当前商店中")
	if offer_id in sold_offer_ids:
		return _fail("这张候选牌已经售出")
	if catalog.find_card(offer_id) == null:
		return _fail("候选牌定义不存在")
	if replaced_id not in deck_ids:
		return _fail("要替换的旧牌不在当前牌组中")
	if catalog.find_card(replaced_id) == null:
		return _fail("旧牌定义不存在")
	if intel_tickets < CARD_PRICE:
		return _fail("情报券不足")
	if offer_id in deck_ids:
		return _fail("牌组中已经存在这张候选牌")

	var next_deck: Array[StringName] = deck_ids.duplicate()
	var replace_index: int = next_deck.find(replaced_id)
	next_deck[replace_index] = offer_id
	if next_deck.size() != 12:
		return _fail("替换后的牌组必须保持十二张")
	var unique_ids: Dictionary = {}
	for card_id in next_deck:
		if catalog.find_card(card_id) == null:
			return _fail("替换后的牌组包含未知卡牌")
		if unique_ids.has(card_id):
			return _fail("替换后的牌组包含重复卡牌")
		unique_ids[card_id] = true

	deck_ids = next_deck
	intel_tickets -= CARD_PRICE
	sold_offer_ids.append(offer_id)
	purchase_records.append(ShopPurchaseRecord.new(
		offer_id,
		replaced_id,
		CARD_PRICE
	))
	last_error = ""
	return OperationResult.new(true)

func _fail(reason: String) -> OperationResult:
	last_error = reason
	return OperationResult.new(false, reason)
