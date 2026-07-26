class_name ResolutionContext
extends RefCounted

var dealer: DealerDefinition
var engraving_catalog: EngravingCatalog

func _init(
	p_dealer: DealerDefinition = null,
	p_engraving_catalog: EngravingCatalog = null
) -> void:
	dealer = p_dealer
	engraving_catalog = p_engraving_catalog

static func empty() -> ResolutionContext:
	return ResolutionContext.new()
