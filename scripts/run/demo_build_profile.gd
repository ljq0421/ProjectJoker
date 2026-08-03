class_name DemoBuildProfile
extends RefCounted

const SCOPE_AUTO := -1
const SCOPE_FULL := 0
const SCOPE_DEMO := 1

func is_demo_build(
	 scope_override: int = SCOPE_AUTO,
	 features: PackedStringArray = PackedStringArray()
) -> bool:
	if scope_override >= SCOPE_FULL:
		return scope_override == SCOPE_DEMO
	if not features.is_empty():
		return "demo" in features
	return OS.has_feature("demo")

func main_menu_access(
	 scope_override: int = SCOPE_AUTO,
	 features: PackedStringArray = PackedStringArray()
) -> Dictionary:
	var demo_build := is_demo_build(scope_override, features)
	return {
		"complete_expedition": true,
		"tutorial": true,
		"region_practice": not demo_build,
		"developer_practice": not demo_build,
	}
