class_name ActionHistory
extends RefCounted

var _states: Array[RoundState] = []

func _init(initial_state: RoundState) -> void:
	_states.append(initial_state.clone())

func push(state: RoundState) -> void:
	_states.append(state.clone())

func can_undo() -> bool:
	return _states.size() > 1

func undo() -> RoundState:
	if not can_undo():
		return null
	_states.pop_back()
	return _states[_states.size() - 1].clone()
