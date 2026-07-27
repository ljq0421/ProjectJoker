class_name EngravingCatalog
extends RefCounted

const PATHS := [
	"res://resources/engravings/stage5/engraving_echo.tres",
	"res://resources/engravings/stage5/engraving_anchor.tres",
	"res://resources/engravings/stage5/engraving_bridge.tres",
	"res://resources/engravings/stage5/engraving_prism.tres",
]
const MIRROR_HALL_PATHS := [
	"res://resources/engravings/mirror_hall/engraving_afterimage.tres",
	"res://resources/engravings/mirror_hall/engraving_silver_anchor.tres",
	"res://resources/engravings/mirror_hall/engraving_backflow_bridge.tres",
	"res://resources/engravings/mirror_hall/engraving_mirror_prism.tres",
]

var _engravings: Array[EngravingDefinition] = []
var _by_id: Dictionary = {}
var _load_errors: Array[String] = []

func _init() -> void:
	for path in PATHS + MIRROR_HALL_PATHS:
		var resource := load(path)
		if not resource is EngravingDefinition:
			_load_errors.append("failed to load engraving resource: %s" % path)
			continue
		var engraving := resource as EngravingDefinition
		_engravings.append(engraving)
		if _by_id.has(engraving.id):
			_load_errors.append("duplicate engraving ID: %s" % engraving.id)
		else:
			_by_id[engraving.id] = engraving

func all_engravings() -> Array[EngravingDefinition]:
	return _engravings.duplicate()

func all_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for engraving in _engravings:
		ids.append(engraving.id)
	return ids

func legacy_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for path in PATHS:
		var engraving := load(path) as EngravingDefinition
		if engraving != null:
			ids.append(engraving.id)
	return ids

func mirror_hall_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for path in MIRROR_HALL_PATHS:
		var engraving := load(path) as EngravingDefinition
		if engraving != null:
			ids.append(engraving.id)
	return ids

func find_engraving(engraving_id: StringName) -> EngravingDefinition:
	return _by_id.get(engraving_id) as EngravingDefinition

func validate() -> Array[String]:
	var errors: Array[String] = _load_errors.duplicate()
	errors.append_array(ContentValidator.new().validate_engravings(all_engravings()))
	if _engravings.size() != 8:
		errors.append("engraving catalog must contain exactly eight engravings")
	return errors
