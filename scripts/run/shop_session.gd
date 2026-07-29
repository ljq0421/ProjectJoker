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
var refresh_used := false
var intel_unlocked := false
var initialization_error := ""
var last_error: String = ""

func _init(
	p_catalog: CardCatalog,
	p_deck_ids: Array[StringName],
	p_market_priority_ids: Array[StringName],
	p_intel_tickets: int,
	p_intel_snapshot: ShopIntelSnapshot = null,
	p_shop_index: int = 0,
	p_services_enabled: bool = false
) -> void:
	catalog = p_catalog
	deck_ids = p_deck_ids.duplicate()
	market_priority_ids = p_market_priority_ids.duplicate()
	intel_tickets = p_intel_tickets
	intel_snapshot = p_intel_snapshot
	shop_index = p_shop_index
	services_enabled = p_services_enabled
	initialization_error = _initialization_error()
	if initialization_error.is_empty():
		offer_ids = _next_offer_batch(deck_ids, [])
		if offer_ids.size() != 3:
			initialization_error = "当前商店无法提供三张候选牌"
			offer_ids.clear()
		else:
			shown_offer_ids.assign(offer_ids)
	last_error = initialization_error

func purchase(offer_id: StringName, replaced_id: StringName) -> OperationResult:
	if not initialization_error.is_empty():
		return _fail(initialization_error)
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

func refresh_offers() -> OperationResult:
	if not initialization_error.is_empty():
		return _fail(initialization_error)
	if not services_enabled:
		return _fail("当前商店不提供刷新服务")
	if refresh_used:
		return _fail("本店已经刷新过候选")
	if intel_tickets < REFRESH_PRICE:
		return _fail("情报券不足，无法刷新")
	var next_offers := _next_offer_batch(deck_ids, shown_offer_ids)
	if next_offers.size() != 3:
		return _fail("没有三张未展示的新候选可供刷新")

	offer_ids.assign(next_offers)
	shown_offer_ids.append_array(next_offers)
	sold_offer_ids.clear()
	intel_tickets -= REFRESH_PRICE
	refresh_used = true
	service_records.append(ShopServiceRecord.new(
		shop_index,
		ShopServiceRecord.ServiceType.REFRESH,
		REFRESH_PRICE
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
	if intel_tickets < INTEL_PRICE:
		return _fail("情报券不足，无法购买情报")

	intel_tickets -= INTEL_PRICE
	intel_unlocked = true
	service_records.append(ShopServiceRecord.new(
		shop_index,
		ShopServiceRecord.ServiceType.INTEL,
		INTEL_PRICE,
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
		"refresh_used": refresh_used,
		"intel_unlocked": intel_unlocked,
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
		snapshot["services_enabled"]
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
			entry.get("intel_kind", -1)
		))
	restored.refresh_used = snapshot["refresh_used"]
	restored.intel_unlocked = snapshot["intel_unlocked"]
	restored.last_error = ""
	return RestoreResult.new(true, "", restored)

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
	if deck_ids.size() != 12:
		return "商店牌组必须包含十二张牌"
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
	already_shown_ids: Array[StringName]
) -> Array[StringName]:
	var next_offers: Array[StringName] = []
	for card_id in market_priority_ids:
		if card_id in current_deck_ids or card_id in already_shown_ids:
			continue
		next_offers.append(card_id)
		if next_offers.size() == 3:
			break
	return next_offers

func _fail(reason: String) -> OperationResult:
	last_error = reason
	return OperationResult.new(false, reason)
