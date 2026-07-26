class_name CardCatalog
extends RefCounted

const STARTER_PATHS := [
	"res://resources/cards/stage4/starter_nudge_down_1.tres",
	"res://resources/cards/stage4/starter_nudge_up_1.tres",
	"res://resources/cards/stage4/starter_nudge_down_2.tres",
	"res://resources/cards/stage4/starter_nudge_up_2.tres",
	"res://resources/cards/stage4/starter_map_1.tres",
	"res://resources/cards/stage4/starter_map_2.tres",
	"res://resources/cards/stage4/starter_repeat_1.tres",
	"res://resources/cards/stage4/starter_repeat_2.tres",
	"res://resources/cards/stage4/starter_stable_repeat.tres",
	"res://resources/cards/stage4/starter_amplified_repeat.tres",
	"res://resources/cards/stage4/starter_reverse.tres",
	"res://resources/cards/stage4/starter_link.tres",
]

const SHOP_PATHS := [
	"res://resources/cards/stage4/shop_precision_map.tres",
	"res://resources/cards/stage4/shop_triple_repeat.tres",
	"res://resources/cards/stage4/shop_long_push.tres",
]

var _starter_cards: Array[CardDefinition] = []
var _shop_cards: Array[CardDefinition] = []
var _cards_by_id: Dictionary = {}
var _load_errors: Array[String] = []

func _init() -> void:
	_starter_cards = _load_cards(STARTER_PATHS)
	_shop_cards = _load_cards(SHOP_PATHS)
	for card in all_cards():
		if _cards_by_id.has(card.id):
			_load_errors.append("duplicate card ID: %s" % card.id)
		else:
			_cards_by_id[card.id] = card

func all_cards() -> Array[CardDefinition]:
	var cards: Array[CardDefinition] = []
	cards.append_array(_starter_cards)
	cards.append_array(_shop_cards)
	return cards

func starter_deck() -> Array[CardDefinition]:
	return _starter_cards.duplicate()

func starter_ids() -> Array[StringName]:
	return _ids(_starter_cards)

func shop_pool() -> Array[CardDefinition]:
	return _shop_cards.duplicate()

func shop_ids() -> Array[StringName]:
	return _ids(_shop_cards)

func find_card(card_id: StringName) -> CardDefinition:
	return _cards_by_id.get(card_id) as CardDefinition

func validate() -> Array[String]:
	var errors: Array[String] = _load_errors.duplicate()
	errors.append_array(ContentValidator.new().validate([], all_cards()))
	if _starter_cards.size() != 12:
		errors.append("starter deck must contain exactly twelve cards")
	if _shop_cards.size() != 3:
		errors.append("shop pool must contain exactly three cards")
	for card_id in starter_ids():
		if card_id in shop_ids():
			errors.append("starter and shop IDs overlap: %s" % card_id)
	return errors

func _load_cards(paths: Array) -> Array[CardDefinition]:
	var cards: Array[CardDefinition] = []
	for path in paths:
		var resource := load(path)
		if resource is CardDefinition:
			cards.append(resource)
		else:
			_load_errors.append("failed to load card resource: %s" % path)
	return cards

func _ids(cards: Array[CardDefinition]) -> Array[StringName]:
	var ids: Array[StringName] = []
	for card in cards:
		ids.append(card.id)
	return ids
