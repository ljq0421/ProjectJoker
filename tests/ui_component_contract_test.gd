extends "res://tests/test_case.gd"

func run() -> void:
	var die = load("res://scenes/components/die_token.tscn").instantiate()
	var card = load("res://scenes/components/card_token.tscn").instantiate()
	var lane = load("res://scenes/components/rule_lane.tscn").instantiate()
	var panel = load("res://scenes/components/resolution_panel.tscn").instantiate()
	assert_true(die.has_signal("die_activated"), "die token should emit activation")
	assert_true(card.has_signal("card_activated"), "card token should emit activation")
	assert_true(lane.has_signal("lane_activated"), "lane should emit click activation")
	assert_true(lane.has_signal("die_drop_requested"), "lane should emit die drops")
	assert_true(die.has_method("set_legal_target"), "die token should expose target highlight")
	assert_true(lane.has_method("set_legal_target"), "lane should expose table target highlight")
	assert_true(lane.has_method("set_die_target_highlight"), "lane should highlight assigned dice")
	assert_true(panel.has_method("bind_report"), "resolution panel should bind reports")
	die.free()
	card.free()
	lane.free()
	panel.free()
