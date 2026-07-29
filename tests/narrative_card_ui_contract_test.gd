extends "res://tests/test_case.gd"

func run() -> void:
	var packed := load("res://scenes/components/narrative_card.tscn")
	assert_true(packed != null, "shared narrative card scene should load")
	if packed == null:
		return
	var card: Control = packed.instantiate()
	assert_true(card.has_signal("confirmed"), "narrative card should confirm")
	assert_true(card.has_signal("exit_requested"), "transition card should safely exit")
	for method_name in [
		"show_area_transition",
		"show_dealer_opening",
		"close",
		"is_open",
	]:
		assert_true(
			card.has_method(method_name),
			"narrative card should expose %s" % method_name
		)
	for node_name in [
		"NarrativeCard",
		"NarrativeKindLabel",
		"NarrativeTitle",
		"NarrativeSpeaker",
		"NarrativeBody",
		"NarrativeContextLabel",
		"NarrativeRuleLabel",
		"NarrativeContinueButton",
		"NarrativeExitButton",
	]:
		assert_true(
			card.get_node_or_null("%" + node_name) != null,
			"narrative card should own %s" % node_name
		)
	card.free()
