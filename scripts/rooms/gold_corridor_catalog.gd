class_name GoldCorridorCatalog
extends RefCounted

var _area: AreaDefinition

func _init() -> void:
	_area = AreaCatalog.new().gold_corridor()

func first_route_ids() -> Array[StringName]:
	return _area.first_route_ids if _area != null else []

func second_route_ids() -> Array[StringName]:
	return _area.second_route_ids if _area != null else []

func find_room(room_id: StringName) -> RoomDefinition:
	return _area.find_room(room_id) if _area != null else null

func all_rooms() -> Array[RoomDefinition]:
	return _area.rooms.duplicate() if _area != null else []

func validate() -> Array[String]:
	if _area == null:
		return ["Gold Corridor area definition failed to load"]
	var errors := ContentValidator.new().validate_rooms(all_rooms())
	if all_rooms().size() != 4:
		errors.append("Gold Corridor catalog must contain exactly four rooms")
	for room_id in first_route_ids():
		if find_room(room_id) == null:
			errors.append("first route room is missing: %s" % room_id)
	for room_id in second_route_ids():
		if find_room(room_id) == null:
			errors.append("second route room is missing: %s" % room_id)
	return errors
