class_name GoldCorridorCatalog
extends RefCounted

const FIRST_ROUTE_IDS: Array[StringName] = [
	&"gold_room_precise_steps",
	&"gold_room_even_split",
]
const SECOND_ROUTE_IDS: Array[StringName] = [
	&"gold_room_narrow_ledger",
	&"gold_room_parallel_proof",
]

const ROOM_PATHS := [
	"res://resources/rooms/gold_corridor/precise_steps.tres",
	"res://resources/rooms/gold_corridor/even_split.tres",
	"res://resources/rooms/gold_corridor/narrow_ledger.tres",
	"res://resources/rooms/gold_corridor/parallel_proof.tres",
]

var _rooms_by_id: Dictionary = {}
var _load_errors: Array[String] = []

func _init() -> void:
	for path in ROOM_PATHS:
		var resource := load(path)
		if not resource is RoomDefinition:
			_load_errors.append("failed to load room resource: %s" % path)
			continue
		var room := resource as RoomDefinition
		if _rooms_by_id.has(room.id):
			_load_errors.append("duplicate room ID: %s" % room.id)
		else:
			_rooms_by_id[room.id] = room

func first_route_ids() -> Array[StringName]:
	return FIRST_ROUTE_IDS.duplicate()

func second_route_ids() -> Array[StringName]:
	return SECOND_ROUTE_IDS.duplicate()

func find_room(room_id: StringName) -> RoomDefinition:
	return _rooms_by_id.get(room_id) as RoomDefinition

func all_rooms() -> Array[RoomDefinition]:
	var result: Array[RoomDefinition] = []
	var ordered_ids: Array[StringName] = []
	ordered_ids.append_array(FIRST_ROUTE_IDS)
	ordered_ids.append_array(SECOND_ROUTE_IDS)
	for room_id in ordered_ids:
		var room := find_room(room_id)
		if room != null:
			result.append(room)
	return result

func validate() -> Array[String]:
	var errors: Array[String] = _load_errors.duplicate()
	var rooms := all_rooms()
	errors.append_array(ContentValidator.new().validate_rooms(rooms))
	if rooms.size() != 4:
		errors.append("Gold Corridor catalog must contain exactly four rooms")
	for room_id in FIRST_ROUTE_IDS:
		if find_room(room_id) == null:
			errors.append("first route room is missing: %s" % room_id)
	for room_id in SECOND_ROUTE_IDS:
		if find_room(room_id) == null:
			errors.append("second route room is missing: %s" % room_id)
	return errors
