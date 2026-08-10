class_name ResolutionContext
extends RefCounted

var dealer: DealerDefinition
var engraving_catalog: EngravingCatalog
var area_modifier_id: StringName = &""
var area_modifier_ids: Array[StringName] = []
var lucky_faces: Dictionary = {}
var area_id: StringName = &""
var category_coefficient_bonuses: Dictionary = {}

func _init(
	p_dealer: DealerDefinition = null,
	p_engraving_catalog: EngravingCatalog = null,
	p_area_modifier_id: StringName = &"",
	p_lucky_faces: Dictionary = {},
	p_area_id: StringName = &"",
	p_category_coefficient_bonuses: Dictionary = {},
	p_area_modifier_ids: Array = []
) -> void:
	dealer = p_dealer
	engraving_catalog = p_engraving_catalog
	area_modifier_id = p_area_modifier_id
	area_modifier_ids.assign(p_area_modifier_ids)
	if area_modifier_ids.is_empty() and area_modifier_id != &"":
		area_modifier_ids.append(area_modifier_id)
	lucky_faces = p_lucky_faces.duplicate(true)
	area_id = p_area_id
	category_coefficient_bonuses = p_category_coefficient_bonuses.duplicate(true)

func has_area_modifier(modifier_id: StringName) -> bool:
	return modifier_id in area_modifier_ids

static func empty() -> ResolutionContext:
	return ResolutionContext.new()
