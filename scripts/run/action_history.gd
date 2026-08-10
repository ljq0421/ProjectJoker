class_name ActionHistory
extends RefCounted

const SnapshotCodec = preload("res://scripts/run/run_snapshot_codec.gd")

enum Kind {
	SYSTEM,
	PLACEMENT,
	CALIBRATION,
	CARD,
}

var _entries: Array[Dictionary] = []

func _init(initial_state: RoundState) -> void:
	_entries.append({"state": initial_state.clone(), "kind": Kind.SYSTEM})

func push(state: RoundState, kind: Kind = Kind.SYSTEM) -> void:
	_entries.append({"state": state.clone(), "kind": kind})

func can_undo() -> bool:
	return _entries.size() > 1

func last_kind() -> Kind:
	if not can_undo():
		return Kind.SYSTEM
	return _entries[-1]["kind"]

func undo() -> RoundState:
	if not can_undo():
		return null
	_entries.pop_back()
	return (_entries[-1]["state"] as RoundState).clone()

func transform_all_states(transform: Callable) -> void:
	for entry in _entries:
		entry["state"] = transform.call(
			(entry["state"] as RoundState).clone()
		)

func current_state() -> RoundState:
	return (_entries[-1]["state"] as RoundState).clone()

func to_snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in _entries:
		result.append({
			"kind": entry["kind"],
			"state": SnapshotCodec.round_state_to_snapshot(entry["state"]),
		})
	return result

func restore_snapshot(entries: Array, catalog: CardCatalog) -> OperationResult:
	if entries.is_empty():
		return OperationResult.new(false, "动作历史不能为空")
	var restored: Array[Dictionary] = []
	for entry in entries:
		if not entry is Dictionary or not entry.has("state"):
			return OperationResult.new(false, "动作历史条目格式无效")
		restored.append({
			"kind": int(entry.get("kind", Kind.SYSTEM)),
			"state": SnapshotCodec.round_state_from_snapshot(entry["state"], catalog),
		})
	_entries = restored
	return OperationResult.new(true)
