class_name ShopSession
extends RefCounted

class RestoreResult extends RefCounted:
	var accepted: bool
	var reason: String
	var session: ShopSession

	func _init(
		p_accepted: bool,
		p_reason: String = "",
		p_session: ShopSession = null
	) -> void:
		accepted = p_accepted
		reason = p_reason
		session = p_session

const CARD_PRICE := 1
const REFRESH_PRICE := 1
const INTEL_PRICE := 1
const REMOVE_CARD_PRICE := 1
const TRANSFER_ENGRAVING_PRICE := 2

var catalog: CardCatalog
var deck_ids: Array[StringName] = []
var offer_ids: Array[StringName] = []
var market_priority_ids: Array[StringName] = []
var shown_offer_ids: Array[StringName] = []
var sold_offer_ids: Array[StringName] = []
var purchase_records: Array[ShopPurchaseRecord] = []
var service_records: Array[ShopServiceRecord] = []
var intel_tickets: int
var intel_snapshot: ShopIntelSnapshot
var shop_index := 0
var services_enabled := false
var append_purchases := false
var price_modifier := 0
var refresh_used := false
var intel_unlocked := false
var remove_card_used := false
var transfer_engraving_used := false
var area_refresh_count := 0
var free_refresh_tokens := 0
var rare_guarantee_unavailable_reason := ""
var initialization_error := ""
var last_error: String = ""

func _init(
	p_catalog: CardCatalog,
	p_deck_ids: Array[StringName],
	p_market_priority_ids: Array[StringName],
	p_intel_tickets: int,
	p_intel_snapshot: ShopIntelSnapshot = null,
	p_shop_index: int = 0,
	p_services_enabled: bool = false,
	p_price_modifier: int = 0,
	p_append_purchases: bool = false,
	p_area_refresh_count: int = 0,
	p_free_refresh_tokens: int = 0
) -> void:
	catalog = p_catalog
	deck_ids = p_deck_ids.duplicate()
	market_priority_ids = p_market_priority_ids.duplicate()
	intel_tickets = p_intel_tickets
	intel_snapshot = p_intel_snapshot
	shop_index = p_shop_index
	services_enabled = p_services_enabled
	price_modifier = p_price_modifier
	append_purchases = p_append_purchases
	area_refresh_count = p_area_refresh_count
	free_refresh_tokens = clampi(p_free_refresh_tokens, 0, 2)
	initialization_error = _initialization_error()
	if initialization_error.is_empty():
		offer_ids = _next_offer_batch(deck_ids, [])
		if offer_ids.size() != 3:
			initialization_error = "当前商店无法提供三张候选牌"
			offer_ids.clear()
		else:
			shown_offer_ids.assign(offer_ids)
	last_error = initialization_error

func purchase(offer_id: StringName, replaced_id: StringName = &"") -> OperationResult:
	if not initialization_error.is_empty():
		return _fail(initialization_error)
	if offer_id not in offer_ids:
		return _fail("候选牌不在当前商店中")
	if offer_id in sold_offer_ids:
		return _fail("这张候选牌已经售出")
	if catalog.find_card(offer_id) == null:
		return _fail("候选牌定义不存在")
	if append_purchases and deck_ids.size() >= CardDeck.MAX_DECK_SIZE:
		return _fail("牌组已达到十五张上限")
	if intel_tickets < card_price(offer_id):
		return _fail("情报券不足")
	if offer_id in deck_ids:
		return _fail("牌组中已经存在这张候选牌")

	if not append_purchases and replaced_id not in deck_ids:
		return _fail("待替换牌不在当前牌组中")
	var next_deck: Array[StringName] = deck_ids.duplicate()
	if append_purchases:
		next_deck.append(offer_id)
	else:
		next_deck[next_deck.find(replaced_id)] = offer_id
	if next_deck.size() > CardDeck.MAX_DECK_SIZE:
		return _fail("购买后的牌组不能超过十五张")
	var unique_ids: Dictionary = {}
	for card_id in next_deck:
		if catalog.find_card(card_id) == null:
			return _fail("替换后的牌组包含未知卡牌")
		if unique_ids.has(card_id):
			return _fail("替换后的牌组包含重复卡牌")
		unique_ids[card_id] = true

	deck_ids = next_deck
	intel_tickets -= card_price(offer_id)
	sold_offer_ids.append(offer_id)
	purchase_records.append(ShopPurchaseRecord.new(
		offer_id,
		&"" if append_purchases else replaced_id,
		card_price(offer_id)
	))
	last_error = ""
	return OperationResult.new(true)

func refresh_offers() -> OperationResult:
	if not initialization_error.is_empty():
		return _fail(initialization_error)
	if not services_enabled:
		return _fail("当前商店不提供刷新服务")
	if refresh_used:
		return _fail("本店已经刷新过候选")
	var price := refresh_price()
	if intel_tickets < price:
		return _fail("情报券不足，无法刷新")
	var next_offers := _next_offer_batch(
		deck_ids,
		shown_offer_ids,
		area_refresh_count + 1 == 2
	)
	if next_offers.size() != 3:
		return _fail("没有三张未展示的新候选可供刷新")

	offer_ids.assign(next_offers)
	shown_offer_ids.append_array(next_offers)
	sold_offer_ids.clear()
	intel_tickets -= price
	if price == 0 and free_refresh_tokens > 0:
		free_refresh_tokens -= 1
	refresh_used = true
	area_refresh_count += 1
	service_records.append(ShopServiceRecord.new(
		shop_index,
		ShopServiceRecord.ServiceType.REFRESH,
		price
	))
	last_error = ""
	return OperationResult.new(true)

func remove_card(card_id: StringName) -> OperationResult:
	if not services_enabled:
		return _fail("当前商店不提供删牌服务")
	if remove_card_used:
		return _fail("本店已经使用过删牌服务")
	if deck_ids.size() <= CardDeck.MIN_DECK_SIZE:
		return _fail("牌组必须保留至少十二张牌")
	if card_id not in deck_ids:
		return _fail("待移除牌不在当前牌组中")
	if intel_tickets < remove_card_price():
		return _fail("情报券不足，无法移除卡牌")
	deck_ids.erase(card_id)
	intel_tickets -= remove_card_price()
	remove_card_used = true
	service_records.append(ShopServiceRecord.new(
		shop_index,
		ShopServiceRecord.ServiceType.REMOVE_CARD,
		remove_card_price(),
		-1,
		card_id
	))
	last_error = ""
	return OperationResult.new(true)

func charge_engraving_transfer(
	source_die_id: StringName,
	target_die_id: StringName,
	target_face: int
) -> OperationResult:
	if not services_enabled:
		return _fail("当前商店不提供刻印转移服务")
	if transfer_engraving_used:
		return _fail("本店已经使用过刻印转移服务")
	if intel_tickets < transfer_engraving_price():
		return _fail("情报券不足，无法转移刻印")
	intel_tickets -= transfer_engraving_price()
	transfer_engraving_used = true
	service_records.append(ShopServiceRecord.new(
		shop_index,
		ShopServiceRecord.ServiceType.TRANSFER_ENGRAVING,
		transfer_engraving_price(),
		-1,
		&"",
		source_die_id,
		target_die_id,
		target_face
	))
	last_error = ""
	return OperationResult.new(true)

func purchase_intel() -> OperationResult:
	if not initialization_error.is_empty():
		return _fail(initialization_error)
	if not services_enabled:
		return _fail("当前商店不提供情报服务")
	if intel_snapshot == null:
		return _fail("当前商店没有可购买的未来情报")
	var snapshot_error := intel_snapshot.structural_error()
	if not snapshot_error.is_empty():
		return _fail(snapshot_error)
	if intel_unlocked:
		return _fail("本店情报已经购买")
	if intel_tickets < intel_price():
		return _fail("情报券不足，无法购买情报")

	intel_tickets -= intel_price()
	intel_unlocked = true
	service_records.append(ShopServiceRecord.new(
		shop_index,
		ShopServiceRecord.ServiceType.INTEL,
		intel_price(),
		intel_snapshot.kind
	))
	last_error = ""
	return OperationResult.new(true)

func to_snapshot() -> Dictionary:
	var purchases: Array[Dictionary] = []
	for record in purchase_records:
		purchases.append({
			"offer_id": record.offer_id,
			"replaced_id": record.replaced_id,
			"price": record.price,
		})
	var services: Array[Dictionary] = []
	for record in service_records:
		services.append({
			"shop_index": record.shop_index,
			"service_type": record.service_type,
			"price": record.price,
			"intel_kind": record.intel_kind,
			"target_card_id": record.target_card_id,
			"source_die_id": record.source_die_id,
			"target_die_id": record.target_die_id,
			"target_face": record.target_face,
		})
	return {
		"deck_ids": deck_ids.duplicate(),
		"offer_ids": offer_ids.duplicate(),
		"market_priority_ids": market_priority_ids.duplicate(),
		"shown_offer_ids": shown_offer_ids.duplicate(),
		"sold_offer_ids": sold_offer_ids.duplicate(),
		"purchase_records": purchases,
		"service_records": services,
		"intel_tickets": intel_tickets,
		"intel_snapshot": _intel_to_snapshot(intel_snapshot),
		"shop_index": shop_index,
		"services_enabled": services_enabled,
		"append_purchases": append_purchases,
		"price_modifier": price_modifier,
		"refresh_used": refresh_used,
		"intel_unlocked": intel_unlocked,
		"remove_card_used": remove_card_used,
		"transfer_engraving_used": transfer_engraving_used,
		"area_refresh_count": area_refresh_count,
		"free_refresh_tokens": free_refresh_tokens,
		"rare_guarantee_unavailable_reason": rare_guarantee_unavailable_reason,
	}

static func from_snapshot(
	p_catalog: CardCatalog,
	snapshot: Dictionary
) -> RestoreResult:
	for key in [
		"deck_ids",
		"offer_ids",
		"market_priority_ids",
		"shown_offer_ids",
		"sold_offer_ids",
		"purchase_records",
		"service_records",
		"intel_tickets",
		"intel_snapshot",
		"shop_index",
		"services_enabled",
		"price_modifier",
		"refresh_used",
		"intel_unlocked",
	]:
		if not snapshot.has(key):
			return RestoreResult.new(false, "商店检查点缺少字段：%s" % key)
	if p_catalog == null:
		return RestoreResult.new(false, "商店卡牌目录不存在")
	for key in [
		"deck_ids",
		"offer_ids",
		"market_priority_ids",
		"shown_offer_ids",
		"sold_offer_ids",
		"purchase_records",
		"service_records",
	]:
		if not snapshot[key] is Array:
			return RestoreResult.new(false, "商店检查点字段格式无效：%s" % key)
	if not snapshot["intel_tickets"] is int or snapshot["intel_tickets"] < 0:
		return RestoreResult.new(false, "商店检查点情报券无效")
	if not snapshot["shop_index"] is int or snapshot["shop_index"] not in [0, 1]:
		return RestoreResult.new(false, "商店检查点序号无效")
	if (
		not snapshot["services_enabled"] is bool
		or not snapshot["refresh_used"] is bool
		or not snapshot["intel_unlocked"] is bool
	):
		return RestoreResult.new(false, "商店检查点服务状态无效")
	if not snapshot["price_modifier"] is int or snapshot["price_modifier"] < 0:
		return RestoreResult.new(false, "商店检查点价格修正无效")
	var intel_result := _intel_from_snapshot(snapshot["intel_snapshot"])
	if not intel_result.accepted:
		return RestoreResult.new(false, intel_result.reason)
	var deck: Array[StringName] = []
	deck.assign(snapshot["deck_ids"])
	var priority: Array[StringName] = []
	priority.assign(snapshot["market_priority_ids"])
	var restored := ShopSession.new(
		p_catalog,
		deck,
		priority,
		snapshot["intel_tickets"],
		intel_result.snapshot,
		snapshot["shop_index"],
		snapshot["services_enabled"],
		snapshot["price_modifier"],
		bool(snapshot.get("append_purchases", false)),
		int(snapshot.get("area_refresh_count", 0)),
		int(snapshot.get("free_refresh_tokens", 0))
	)
	if not restored.initialization_error.is_empty():
		return RestoreResult.new(false, restored.initialization_error)
	restored.offer_ids.assign(snapshot["offer_ids"])
	restored.shown_offer_ids.assign(snapshot["shown_offer_ids"])
	restored.sold_offer_ids.assign(snapshot["sold_offer_ids"])
	restored.purchase_records.clear()
	for entry in snapshot["purchase_records"]:
		if not entry is Dictionary:
			return RestoreResult.new(false, "商店购买记录格式无效")
		restored.purchase_records.append(ShopPurchaseRecord.new(
			entry.get("offer_id", &""),
			entry.get("replaced_id", &""),
			entry.get("price", -1)
		))
	restored.service_records.clear()
	for entry in snapshot["service_records"]:
		if not entry is Dictionary:
			return RestoreResult.new(false, "商店服务记录格式无效")
		restored.service_records.append(ShopServiceRecord.new(
			entry.get("shop_index", -1),
			entry.get("service_type", -1),
			entry.get("price", -1),
			entry.get("intel_kind", -1),
			entry.get("target_card_id", &""),
			entry.get("source_die_id", &""),
			entry.get("target_die_id", &""),
			entry.get("target_face", 0)
		))
	restored.refresh_used = snapshot["refresh_used"]
	restored.intel_unlocked = snapshot["intel_unlocked"]
	restored.remove_card_used = bool(snapshot.get("remove_card_used", false))
	restored.transfer_engraving_used = bool(
		snapshot.get("transfer_engraving_used", false)
	)
	restored.rare_guarantee_unavailable_reason = String(
		snapshot.get("rare_guarantee_unavailable_reason", "")
	)
	restored.last_error = ""
	return RestoreResult.new(true, "", restored)

func card_price(card_id: StringName = &"") -> int:
	var base_price := CARD_PRICE
	var card := catalog.find_card(card_id) if catalog != null and card_id != &"" else null
	if append_purchases and card != null and card.rarity == CardDefinition.Rarity.RARE:
		base_price = 2
	return base_price + price_modifier

func refresh_price() -> int:
	if free_refresh_tokens > 0:
		return 0
	return REFRESH_PRICE + price_modifier

func intel_price() -> int:
	return INTEL_PRICE + price_modifier

func remove_card_price() -> int:
	return REMOVE_CARD_PRICE + price_modifier

func transfer_engraving_price() -> int:
	return TRANSFER_ENGRAVING_PRICE + price_modifier

class IntelRestoreResult extends RefCounted:
	var accepted: bool
	var reason: String
	var snapshot: ShopIntelSnapshot

	func _init(
		p_accepted: bool,
		p_reason: String = "",
		p_snapshot: ShopIntelSnapshot = null
	) -> void:
		accepted = p_accepted
		reason = p_reason
		snapshot = p_snapshot

static func _intel_to_snapshot(intel: ShopIntelSnapshot) -> Dictionary:
	if intel == null:
		return {}
	return {
		"kind": intel.kind,
		"route_ids": intel.route_ids.duplicate(),
		"dealer_id": intel.dealer_id,
		"dealer_target": intel.dealer_target,
	}

static func _intel_from_snapshot(value: Variant) -> IntelRestoreResult:
	if not value is Dictionary:
		return IntelRestoreResult.new(false, "商店情报检查点格式无效")
	if value.is_empty():
		return IntelRestoreResult.new(true, "", null)
	for key in ["kind", "route_ids", "dealer_id", "dealer_target"]:
		if not value.has(key):
			return IntelRestoreResult.new(false, "商店情报检查点缺少字段：%s" % key)
	var intel := ShopIntelSnapshot.new()
	intel.kind = value["kind"]
	intel.route_ids.assign(value["route_ids"])
	intel.dealer_id = value["dealer_id"]
	intel.dealer_target = value["dealer_target"]
	var error := intel.structural_error()
	if not error.is_empty():
		return IntelRestoreResult.new(false, error)
	return IntelRestoreResult.new(true, "", intel)

func _initialization_error() -> String:
	if catalog == null:
		return "商店卡牌目录不存在"
	if (
		deck_ids.size() < CardDeck.MIN_DECK_SIZE
		or deck_ids.size() > CardDeck.MAX_DECK_SIZE
	):
		return "商店牌组必须包含十二至十五张牌"
	var deck_seen: Dictionary = {}
	for card_id in deck_ids:
		if catalog.find_card(card_id) == null:
			return "商店牌组包含未知卡牌：%s" % card_id
		if deck_seen.has(card_id):
			return "商店牌组包含重复卡牌：%s" % card_id
		deck_seen[card_id] = true
	if market_priority_ids.size() < 3:
		return "商店候选优先序不足三张"
	var market_seen: Dictionary = {}
	for card_id in market_priority_ids:
		if catalog.find_card(card_id) == null:
			return "商店候选优先序包含未知卡牌：%s" % card_id
		if market_seen.has(card_id):
			return "商店候选优先序包含重复卡牌：%s" % card_id
		market_seen[card_id] = true
	if services_enabled:
		if shop_index < 0 or shop_index > 1:
			return "正式商店序号必须为 0 或 1"
		if intel_snapshot == null:
			return "正式商店缺少未来情报"
		var snapshot_error := intel_snapshot.structural_error()
		if not snapshot_error.is_empty():
			return snapshot_error
	return ""

func _next_offer_batch(
	current_deck_ids: Array[StringName],
	already_shown_ids: Array[StringName],
	guarantee_rare: bool = false
) -> Array[StringName]:
	var next_offers: Array[StringName] = []
	for card_id in market_priority_ids:
		if card_id in current_deck_ids or card_id in already_shown_ids:
			continue
		next_offers.append(card_id)
		if next_offers.size() == 3:
			break
	if guarantee_rare:
		var rare_id: StringName = &""
		for card_id in market_priority_ids:
			var card := catalog.find_card(card_id)
			if (
				card_id not in current_deck_ids
				and card != null
				and card.rarity == CardDefinition.Rarity.RARE
			):
				rare_id = card_id
				break
		if rare_id == &"":
			rare_guarantee_unavailable_reason = (
				"稀有牌池已全部收集，第二次刷新无法保底"
			)
		elif rare_id not in next_offers and not next_offers.is_empty():
			next_offers[-1] = rare_id
			rare_guarantee_unavailable_reason = ""
	return next_offers

func _fail(reason: String) -> OperationResult:
	last_error = reason
	return OperationResult.new(false, reason)
