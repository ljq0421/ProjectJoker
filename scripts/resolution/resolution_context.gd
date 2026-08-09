class_name ResolutionContext
extends RefCounted

var dealer: DealerDefinition
var engraving_catalog: EngravingCatalog
var area_modifier_id: StringName = &""
var lucky_faces: Dictionary = {}

func _init(
	p_dealer: DealerDefinition = null,
	p_engraving_catalog: EngravingCatalog = null,
	p_area_modifier_id: StringName = &"",
	p_lucky_faces: Dictionary = {}
) -> void:
	dealer = p_dealer
	engraving_catalog = p_engraving_catalog
	area_modifier_id = p_area_modifier_id
	lucky_faces = p_lucky_faces.duplicate(true)

static func empty() -> ResolutionContext:
	return ResolutionContext.new()
