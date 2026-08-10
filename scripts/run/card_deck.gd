class_name CardDeck
extends RefCounted

const HAND_SIZE := 4
const MIN_DECK_SIZE := 12
const MAX_DECK_SIZE := 15

var _draw_pile: Array[StringName] = []

func start_encounter(card_ids: Array[StringName], run_rng: RunRng) -> void:
	assert(
		card_ids.size() >= MIN_DECK_SIZE and card_ids.size() <= MAX_DECK_SIZE,
		"an encounter deck must contain twelve to fifteen cards"
	)
	_draw_pile.assign(run_rng.shuffle(card_ids))

func draw_round(count: int = HAND_SIZE) -> Array[StringName]:
	var hand: Array[StringName] = []
	for draw_index in range(mini(count, _draw_pile.size())):
		hand.append(_draw_pile.pop_front())
	return hand

func take_card(card_id: StringName) -> bool:
	var index := _draw_pile.find(card_id)
	if index < 0:
		return false
	_draw_pile.remove_at(index)
	return true

func snapshot_draw_pile() -> Array[StringName]:
	return _draw_pile.duplicate()

func restore_draw_pile(snapshot: Array[StringName]) -> void:
	_draw_pile.assign(snapshot)
