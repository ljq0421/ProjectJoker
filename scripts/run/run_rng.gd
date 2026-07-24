class_name RunRng
extends RefCounted

var _rng := RandomNumberGenerator.new()

func _init(seed_value: int) -> void:
	_rng.seed = seed_value

func roll_die() -> int:
	return _rng.randi_range(1, 6)

func shuffle(values: Array) -> Array:
	var shuffled := values.duplicate()
	for index in range(shuffled.size() - 1, 0, -1):
		var swap_index := _rng.randi_range(0, index)
		var temporary = shuffled[index]
		shuffled[index] = shuffled[swap_index]
		shuffled[swap_index] = temporary
	return shuffled
