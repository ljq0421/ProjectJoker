class_name MirrorHallRunScreen
extends AreaRunScreen

const MIRROR_SEED := 20260727

func build_area_definition() -> AreaDefinition:
	return AreaCatalog.new().mirror_hall()

func build_seed() -> int:
	return MIRROR_SEED
