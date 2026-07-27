class_name AreaCatalog
extends RefCounted

const GOLD_CORRIDOR_PATH := "res://resources/areas/gold_corridor.tres"
const MIRROR_HALL_PATH := "res://resources/areas/mirror_hall.tres"

var _gold_corridor: AreaDefinition
var _mirror_hall: AreaDefinition
var _load_errors: Array[String] = []

func _init() -> void:
	var resource := load(GOLD_CORRIDOR_PATH)
	if resource is AreaDefinition:
		_gold_corridor = resource
	else:
		_load_errors.append("failed to load area resource: %s" % GOLD_CORRIDOR_PATH)
	resource = load(MIRROR_HALL_PATH)
	if resource is AreaDefinition:
		_mirror_hall = resource
	else:
		_load_errors.append("failed to load area resource: %s" % MIRROR_HALL_PATH)

func gold_corridor() -> AreaDefinition:
	return _gold_corridor

func mirror_hall() -> AreaDefinition:
	return _mirror_hall

func all_areas() -> Array[AreaDefinition]:
	var areas: Array[AreaDefinition] = []
	if _gold_corridor != null:
		areas.append(_gold_corridor)
	if _mirror_hall != null:
		areas.append(_mirror_hall)
	return areas

func validate(
	card_catalog: CardCatalog,
	dealer_catalog: DealerCatalog,
	engraving_catalog: EngravingCatalog
) -> Array[String]:
	var errors := _load_errors.duplicate()
	for area in all_areas():
		errors.append_array(area.validate(card_catalog, dealer_catalog, engraving_catalog))
	return errors
