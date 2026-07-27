class_name AreaCompletePanel
extends Control

signal restart_requested
signal return_requested

const REQUIRED_KEYS := [
	"rooms",
	"dealer",
	"purchases",
	"deck_ids",
	"intel_tickets",
	"engraving_id",
	"die_id",
	"face",
]

func _ready() -> void:
	%RestartAreaButton.pressed.connect(func() -> void: restart_requested.emit())
	%ReturnEntryButton.pressed.connect(func() -> void: return_requested.emit())
	close()

func bind_summary(
	summary: Dictionary,
	room_catalog: GoldCorridorCatalog,
	card_catalog: CardCatalog,
	engraving_catalog: EngravingCatalog
) -> bool:
	if room_catalog == null or card_catalog == null or engraving_catalog == null:
		return _fail_closed("区域摘要目录不可用")
	for key in REQUIRED_KEYS:
		if not summary.has(key):
			return _fail_closed("区域摘要缺少字段：%s" % key)
	var error := _summary_error(summary, room_catalog, card_catalog, engraving_catalog)
	if not error.is_empty():
		return _fail_closed(error)

	var room_lines: Array[String] = []
	var score_lines: Array[String] = []
	var rooms: Array = summary["rooms"]
	for index in range(rooms.size()):
		var entry: Dictionary = rooms[index]
		var room := room_catalog.find_room(entry["room_id"])
		room_lines.append("路线 %d｜%s" % [index + 1, room.display_name])
		score_lines.append("%s　%d / %d" % [
			room.display_name,
			entry["cumulative_total"],
			entry["target_total"],
		])
	var dealer: Dictionary = summary["dealer"]
	score_lines.append("铁算盘　%d / %d" % [
		dealer["cumulative_total"],
		dealer["target_total"],
	])
	%RouteHistoryLabel.text = "\n".join(room_lines)
	%ScoreHistoryLabel.text = "\n".join(score_lines)
	%PurchaseHistoryLabel.text = _purchase_text(summary["purchases"], card_catalog)
	%FinalDeckLabel.text = _deck_text(summary["deck_ids"], card_catalog)
	%FinalResourceLabel.text = "剩余情报券｜%d" % summary["intel_tickets"]
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

func show_error(message: String) -> void:
	%CompleteErrorLabel.text = message
	SfxAccess.play(self, &"error")

func close() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _summary_error(
	summary: Dictionary,
	room_catalog: GoldCorridorCatalog,
	card_catalog: CardCatalog,
	engraving_catalog: EngravingCatalog
) -> String:
	if not summary["rooms"] is Array or summary["rooms"].size() != 2:
		return "区域摘要必须包含两个普通房"
	for entry in summary["rooms"]:
		if not entry is Dictionary:
			return "普通房摘要格式无效"
		for key in ["room_id", "target_total", "cumulative_total"]:
			if not entry.has(key):
				return "普通房摘要缺少字段：%s" % key
		if room_catalog.find_room(entry["room_id"]) == null:
			return "区域摘要包含未知房间：%s" % entry["room_id"]
		if not entry["target_total"] is int or not entry["cumulative_total"] is int:
			return "普通房摘要分数无效"
	if not summary["dealer"] is Dictionary:
		return "庄家摘要格式无效"
	var dealer: Dictionary = summary["dealer"]
	for key in ["id", "target_total", "cumulative_total"]:
		if not dealer.has(key):
			return "庄家摘要缺少字段：%s" % key
	if dealer["id"] != &"dealer_iron_abacus":
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
	if engraving_catalog.find_engraving(summary["engraving_id"]) == null:
		return "区域摘要包含未知刻印"
	if summary["die_id"] not in [&"d1", &"d2", &"d3", &"d4", &"d5", &"d6"]:
		return "区域摘要包含未知刻印骰子"
	if not summary["face"] is int or summary["face"] < 1 or summary["face"] > 6:
		return "区域摘要包含非法刻印面"
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
