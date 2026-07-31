class_name AreaCompletePanel
extends Control

signal restart_requested
signal return_requested
signal continue_requested

const REQUIRED_KEYS := [
	"area_id",
	"rng_state",
	"rooms",
	"dealer",
	"purchases",
	"services",
	"deck_ids",
	"intel_tickets",
	"engraving_id",
	"die_id",
	"face",
	"die_profiles",
]

var _expedition_mode := false
var _has_next_area := false

func _ready() -> void:
	%RestartAreaButton.pressed.connect(_on_primary_pressed)
	%ReturnEntryButton.pressed.connect(func() -> void: return_requested.emit())
	close()

func configure_expedition(enabled: bool, has_next_area: bool) -> void:
	_expedition_mode = enabled
	_has_next_area = has_next_area
	if not enabled:
		return
	%RestartAreaButton.text = (
		"进入下一区域"
		if has_next_area
		else "查看远征总结"
	)

func bind_summary(
	summary: Dictionary,
	area_definition: AreaDefinition,
	card_catalog: CardCatalog,
	dealer_catalog: DealerCatalog,
	engraving_catalog: EngravingCatalog
) -> bool:
	if (
		area_definition == null
		or card_catalog == null
		or dealer_catalog == null
		or engraving_catalog == null
	):
		return _fail_closed("区域摘要目录不可用")
	for key in REQUIRED_KEYS:
		if not summary.has(key):
			return _fail_closed("区域摘要缺少字段：%s" % key)
	var error := _summary_error(
		summary,
		area_definition,
		card_catalog,
		dealer_catalog,
		engraving_catalog
	)
	if not error.is_empty():
		return _fail_closed(error)

	var room_lines: Array[String] = []
	var score_lines: Array[String] = []
	var rooms: Array = summary["rooms"]
	for index in range(rooms.size()):
		var entry: Dictionary = rooms[index]
		var room := area_definition.find_room(entry["room_id"])
		room_lines.append("路线 %d｜%s" % [index + 1, room.display_name])
		score_lines.append("%s　%d / %d" % [
			room.display_name,
			entry["cumulative_total"],
			entry["target_total"],
		])
	var dealer: Dictionary = summary["dealer"]
	var dealer_definition := dealer_catalog.find_dealer(dealer["id"])
	%CompleteTitle.text = "%s · 账目封存" % area_definition.display_name
	%SealMark.text = "%s  /  CLOSED" % String(area_definition.id).to_upper()
	if not _expedition_mode:
		%RestartAreaButton.text = "重新开始%s" % area_definition.display_name
	score_lines.append("%s　%d / %d" % [
		dealer_definition.display_name,
		dealer["cumulative_total"],
		dealer["target_total"],
	])
	%RouteHistoryLabel.text = "\n".join(room_lines)
	%ScoreHistoryLabel.text = "\n".join(score_lines)
	%PurchaseHistoryLabel.text = "手法替换\n%s\n\n商店服务\n%s" % [
		_purchase_text(summary["purchases"], card_catalog),
		_service_text(summary["services"]),
	]
	%FinalDeckLabel.text = _deck_text(summary["deck_ids"], card_catalog)
	%FinalResourceLabel.text = "剩余情报券｜%d" % summary["intel_tickets"]
	if summary.get("reward_kind", &"engraving") == &"rare_card":
		var reward_card := card_catalog.find_card(summary["reward_card_id"])
		var replaced_card := card_catalog.find_card(summary["replaced_card_id"])
		%FinalEngravingLabel.text = "庄家稀有牌｜%s\n替换：%s" % [
			reward_card.display_name,
			replaced_card.display_name,
		]
	else:
		var engraving := engraving_catalog.find_engraving(summary["engraving_id"])
		%FinalEngravingLabel.text = "区域刻印｜%s\n%s · 第 %d 面" % [
			engraving.display_name,
			String(summary["die_id"]).to_upper(),
			summary["face"],
		]
	%CompleteErrorLabel.text = ""
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	SfxAccess.play(self, &"area_complete")
	return true

func _on_primary_pressed() -> void:
	if _expedition_mode:
		continue_requested.emit()
	else:
		restart_requested.emit()

func show_error(message: String) -> void:
	%CompleteErrorLabel.text = message
	SfxAccess.play(self, &"error")

func close() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _summary_error(
	summary: Dictionary,
	area_definition: AreaDefinition,
	card_catalog: CardCatalog,
	dealer_catalog: DealerCatalog,
	engraving_catalog: EngravingCatalog
) -> String:
	if summary["area_id"] != area_definition.id:
		return "区域摘要与地区定义不匹配"
	if not summary["rng_state"] is int:
		return "区域摘要随机状态无效"
	if not summary["rooms"] is Array or summary["rooms"].size() != 2:
		return "区域摘要必须包含两个普通房"
	for entry in summary["rooms"]:
		if not entry is Dictionary:
			return "普通房摘要格式无效"
		for key in ["room_id", "target_total", "cumulative_total"]:
			if not entry.has(key):
				return "普通房摘要缺少字段：%s" % key
		if area_definition.find_room(entry["room_id"]) == null:
			return "区域摘要包含未知房间：%s" % entry["room_id"]
		if not entry["target_total"] is int or not entry["cumulative_total"] is int:
			return "普通房摘要分数无效"
	if not summary["dealer"] is Dictionary:
		return "庄家摘要格式无效"
	var dealer: Dictionary = summary["dealer"]
	for key in ["id", "target_total", "cumulative_total"]:
		if not dealer.has(key):
			return "庄家摘要缺少字段：%s" % key
	if (
		dealer["id"] != area_definition.dealer_id
		or dealer_catalog.find_dealer(dealer["id"]) == null
	):
		return "区域摘要包含未知庄家"
	if not dealer["target_total"] is int or not dealer["cumulative_total"] is int:
		return "庄家摘要分数无效"
	if not summary["purchases"] is Array:
		return "替换记录格式无效"
	for record in summary["purchases"]:
		if not record is Dictionary:
			return "替换记录条目无效"
		for key in ["offer_id", "replaced_id", "price"]:
			if not record.has(key):
				return "替换记录缺少字段：%s" % key
		if (
			card_catalog.find_card(record["offer_id"]) == null
			or card_catalog.find_card(record["replaced_id"]) == null
		):
			return "替换记录包含未知手法牌"
		if not record["price"] is int or record["price"] < 0:
			return "替换记录价格无效"
	if not summary["services"] is Array:
		return "商店服务记录格式无效"
	for record in summary["services"]:
		if not record is Dictionary:
			return "商店服务记录条目无效"
		for key in ["shop_index", "service_type", "price", "intel_kind"]:
			if not record.has(key):
				return "商店服务记录缺少字段：%s" % key
		if (
			not record["shop_index"] is int
			or record["shop_index"] < 0
			or record["shop_index"] > 1
		):
			return "商店服务记录店次无效"
		if (
			not record["service_type"] is int
			or record["service_type"] not in [
				ShopServiceRecord.ServiceType.REFRESH,
				ShopServiceRecord.ServiceType.INTEL,
			]
		):
			return "商店服务记录类型无效"
		if not record["price"] is int or record["price"] != 1:
			return "商店服务记录价格无效"
		if not record["intel_kind"] is int:
			return "商店服务记录情报类型无效"
		if (
			record["service_type"] == ShopServiceRecord.ServiceType.REFRESH
			and record["intel_kind"] != -1
		):
			return "刷新记录不能包含情报类型"
		if (
			record["service_type"] == ShopServiceRecord.ServiceType.INTEL
			and record["intel_kind"] not in [
				ShopIntelSnapshot.Kind.ROUTE_PAIR,
				ShopIntelSnapshot.Kind.DEALER,
			]
		):
			return "情报记录类型无效"
	if not summary["deck_ids"] is Array or summary["deck_ids"].size() != 12:
		return "最终牌组必须包含十二张牌"
	var seen_cards: Dictionary = {}
	for card_id in summary["deck_ids"]:
		if card_catalog.find_card(card_id) == null:
			return "最终牌组包含未知手法牌：%s" % card_id
		if seen_cards.has(card_id):
			return "最终牌组包含重复手法牌：%s" % card_id
		seen_cards[card_id] = true
	if not summary["intel_tickets"] is int or summary["intel_tickets"] < 0:
		return "剩余情报券无效"
	var reward_kind: StringName = summary.get("reward_kind", &"engraving")
	if reward_kind == &"rare_card":
		for key in ["reward_card_id", "replaced_card_id"]:
			if not summary.has(key):
				return "稀有牌奖励摘要缺少字段：%s" % key
		var reward_card := card_catalog.find_card(summary["reward_card_id"])
		var replaced_card := card_catalog.find_card(summary["replaced_card_id"])
		if reward_card == null or reward_card.rarity != CardDefinition.Rarity.RARE:
			return "区域摘要包含无效稀有牌奖励"
		if replaced_card == null:
			return "区域摘要包含未知替换牌"
		if summary["reward_card_id"] not in summary["deck_ids"]:
			return "稀有牌奖励未进入最终牌组"
		if summary["replaced_card_id"] in summary["deck_ids"]:
			return "被替换手法牌仍在最终牌组"
	elif reward_kind == &"engraving":
		if engraving_catalog.find_engraving(summary["engraving_id"]) == null:
			return "区域摘要包含未知刻印"
		if summary["die_id"] not in [&"d1", &"d2", &"d3", &"d4", &"d5", &"d6"]:
			return "区域摘要包含未知刻印骰子"
		if not summary["face"] is int or summary["face"] < 1 or summary["face"] > 6:
			return "区域摘要包含非法刻印面"
	else:
		return "区域摘要包含未知庄家奖励类型"
	if not summary["die_profiles"] is Array or summary["die_profiles"].size() != 6:
		return "区域摘要骰子档案无效"
	return ""

func _purchase_text(purchases: Array, card_catalog: CardCatalog) -> String:
	if purchases.is_empty():
		return "本区未进行手法替换"
	var lines: Array[String] = []
	for record in purchases:
		lines.append("%s → %s（%d 情报券）" % [
			card_catalog.find_card(record["replaced_id"]).display_name,
			card_catalog.find_card(record["offer_id"]).display_name,
			record["price"],
		])
	return "\n".join(lines)

func _service_text(services: Array) -> String:
	if services.is_empty():
		return "本区未购买商店服务"
	var lines: Array[String] = []
	for record in services:
		var service_name := "整批刷新"
		if record["service_type"] == ShopServiceRecord.ServiceType.INTEL:
			service_name = (
				"路线情报"
				if record["intel_kind"] == ShopIntelSnapshot.Kind.ROUTE_PAIR
				else "庄家情报"
			)
		lines.append("商店 %d｜%s（%d 情报券）" % [
			record["shop_index"] + 1,
			service_name,
			record["price"],
		])
	return "\n".join(lines)

func _deck_text(deck_ids: Array, card_catalog: CardCatalog) -> String:
	var names: Array[String] = []
	for card_id in deck_ids:
		names.append(card_catalog.find_card(card_id).display_name)
	var rows: Array[String] = []
	for start in range(0, names.size(), 4):
		rows.append("　".join(names.slice(start, mini(start + 4, names.size()))))
	return "\n".join(rows)

func _fail_closed(message: String) -> bool:
	%CompleteErrorLabel.text = message
	close()
	return false
