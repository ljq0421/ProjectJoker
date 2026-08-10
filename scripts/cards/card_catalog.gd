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
	"res://resources/cards/stage6/shop_deep_drop.tres",
	"res://resources/cards/stage6/shop_amplified_chain.tres",
	"res://resources/cards/stage6/shop_reverse_backup.tres",
	"res://resources/cards/stage6/shop_dice_index.tres",
	"res://resources/cards/stage6/shop_chain_index.tres",
]

const MIRROR_HALL_PATHS := [
	"res://resources/cards/mirror_hall/mirror_folded_map.tres",
	"res://resources/cards/mirror_hall/mirror_soft_echo.tres",
	"res://resources/cards/mirror_hall/mirror_hinged_bridge.tres",
	"res://resources/cards/mirror_hall/mirror_double_exposure.tres",
	"res://resources/cards/mirror_hall/mirror_deep_echo.tres",
	"res://resources/cards/mirror_hall/mirror_silver_bridge.tres",
]

const FACELESS_HUB_PATHS := [
	"res://resources/cards/faceless_hub/faceless_swap_values.tres",
	"res://resources/cards/faceless_hub/faceless_copy_value.tres",
	"res://resources/cards/faceless_hub/faceless_flip_value.tres",
	"res://resources/cards/faceless_hub/faceless_lock_bonus.tres",
	"res://resources/cards/faceless_hub/faceless_refund_calibration.tres",
	"res://resources/cards/faceless_hub/faceless_exact_tolerance.tres",
	"res://resources/cards/faceless_hub/faceless_even_tolerance.tres",
	"res://resources/cards/faceless_hub/faceless_sequence_tolerance.tres",
	"res://resources/cards/faceless_hub/faceless_table_receipt.tres",
	"res://resources/cards/faceless_hub/faceless_full_allocation.tres",
	"res://resources/cards/faceless_hub/faceless_three_seats.tres",
	"res://resources/cards/faceless_hub/faceless_complete_dossier.tres",
	"res://resources/cards/faceless_hub/faceless_strict_mapping.tres",
	"res://resources/cards/faceless_hub/faceless_reverse_replay.tres",
	"res://resources/cards/faceless_hub/faceless_compressed_repeat.tres",
	"res://resources/cards/faceless_hub/faceless_closed_circuit.tres",
]

var _starter_cards: Array[CardDefinition] = []
var _shop_cards: Array[CardDefinition] = []
var _mirror_hall_cards: Array[CardDefinition] = []
var _faceless_hub_cards: Array[CardDefinition] = []
var _cards_by_id: Dictionary = {}
var _load_errors: Array[String] = []

func _init() -> void:
	_starter_cards = _load_cards(STARTER_PATHS)
	_shop_cards = _load_cards(SHOP_PATHS)
	_mirror_hall_cards = _load_cards(MIRROR_HALL_PATHS)
	_faceless_hub_cards = _load_cards(FACELESS_HUB_PATHS)
	for card in all_cards():
		if _cards_by_id.has(card.id):
			_load_errors.append("duplicate card ID: %s" % card.id)
		else:
			_cards_by_id[card.id] = card

func all_cards() -> Array[CardDefinition]:
	var cards: Array[CardDefinition] = []
	cards.append_array(_starter_cards)
	cards.append_array(_shop_cards)
	cards.append_array(_mirror_hall_cards)
	cards.append_array(_faceless_hub_cards)
	return cards

func starter_deck() -> Array[CardDefinition]:
	return _starter_cards.duplicate()

func starter_ids() -> Array[StringName]:
	return _ids(_starter_cards)

func shop_pool() -> Array[CardDefinition]:
	return _shop_cards.duplicate()

func shop_ids() -> Array[StringName]:
	return _ids(_shop_cards)

func mirror_hall_card_ids() -> Array[StringName]:
	return _ids(_mirror_hall_cards)

func faceless_hub_card_ids() -> Array[StringName]:
	return _ids(_faceless_hub_cards)

func cards_for_suit(suit: CardDefinition.Suit) -> Array[CardDefinition]:
	var cards: Array[CardDefinition] = []
	for card in all_cards():
		if card.suit == suit:
			cards.append(card)
	return cards

func find_card(card_id: StringName) -> CardDefinition:
	return _cards_by_id.get(card_id) as CardDefinition

func validate() -> Array[String]:
	var errors: Array[String] = _load_errors.duplicate()
	errors.append_array(ContentValidator.new().validate([], all_cards()))
	if _starter_cards.size() != 12:
		errors.append("starter deck must contain exactly twelve cards")
	if _shop_cards.size() != 8:
		errors.append("shop pool must contain exactly eight cards")
	if _mirror_hall_cards.size() != 6:
		errors.append("mirror hall card group must contain exactly six cards")
	if _faceless_hub_cards.size() != 16:
		errors.append("faceless hub card group must contain exactly sixteen cards")
	for card_id in starter_ids():
		if card_id in shop_ids():
			errors.append("starter and shop IDs overlap: %s" % card_id)
	for card_id in mirror_hall_card_ids():
		if card_id in starter_ids() or card_id in shop_ids():
			errors.append("mirror hall and legacy card IDs overlap: %s" % card_id)
	for card_id in faceless_hub_card_ids():
		if (
			card_id in starter_ids()
			or card_id in shop_ids()
			or card_id in mirror_hall_card_ids()
		):
			errors.append("faceless hub and legacy card IDs overlap: %s" % card_id)
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
