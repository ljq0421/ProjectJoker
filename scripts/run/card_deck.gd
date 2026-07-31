class_name CardDeck
extends RefCounted

const HAND_SIZE := 4

var _draw_pile: Array[StringName] = []

func start_encounter(card_ids: Array[StringName], run_rng: RunRng) -> void:
	assert(card_ids.size() == 12, "an encounter deck must contain exactly twelve cards")
	_draw_pile.assign(run_rng.shuffle(card_ids))

func draw_round(count: int = HAND_SIZE) -> Array[StringName]:
	var hand: Array[StringName] = []
	for draw_index in range(mini(count, _draw_pile.size())):
		hand.append(_draw_pile.pop_front())
	return hand

func snapshot_draw_pile() -> Array[StringName]:
	return _draw_pile.duplicate()

func restore_draw_pile(snapshot: Array[StringName]) -> void:
	_draw_pile.assign(snapshot)
