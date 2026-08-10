extends "res://tests/test_case.gd"

const FLOW_PATH := "res://scripts/run/area_flow_definition.gd"
const SPECIAL_CATALOG_PATH := "res://scripts/run/special_room_catalog.gd"

func run() -> void:
	assert_true(ResourceLoader.exists(FLOW_PATH), "phase 3B should expose data-driven area flow")
	assert_true(ResourceLoader.exists(SPECIAL_CATALOG_PATH), "phase 3B should expose special room content")
	if not ResourceLoader.exists(FLOW_PATH):
		return
	var flow_script = load(FLOW_PATH)
	var gold = flow_script.new(&"gold_corridor")
	var mirror = flow_script.new(&"mirror_hall")
	var faceless = flow_script.new(&"faceless_hub")
	assert_equal(gold.steps.size(), 9, "gold flow should contain nine persisted steps")
	assert_equal(mirror.steps[6]["type"], flow_script.StepType.ELITE_ROOM, "mirror second branch uses elite")
	assert_equal(faceless.steps[2]["type"], flow_script.StepType.CHOICE_ROOM, "faceless first branch uses choice")
	assert_equal(faceless.steps[6]["type"], flow_script.StepType.ENGRAVING_ROOM, "faceless second branch uses engraving")
