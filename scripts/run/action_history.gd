class_name ActionHistory
extends RefCounted

var _states: Array[RoundState] = []

func _init(initial_state: RoundState) -> void:
	_states.append(initial_state.clone())

func push(state: RoundState) -> void:
	_states.append(state.clone())

func undo() -> RoundState:
	if _states.size() <= 1:
		return null
	_states.pop_back()
	return _states[_states.size() - 1].clone()
