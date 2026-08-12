extends "res://tests/test_case.gd"

const Catalog = preload("res://scripts/engine_slice/engine_slice_catalog.gd")
const Controller = preload("res://scripts/engine_slice/engine_battle_controller.gd")

func run() -> void:
	_test_unique_ownership_and_undo()
	_test_technique_return_and_consumption()
	_test_independent_upgrade_branches_change_operation()
	_test_preview_is_deterministic_and_kill_cancels_intent()
	_test_tactic_and_engine_extra_dice_stack()
	_test_guard_counter_happens_after_intent()
	_test_engine_burst_cancels_intent_and_keeps_remainder()
	_test_multiple_engine_bursts()
	_test_retained_block_lasts_one_turn()
	_test_player_death_prevents_counter()
	_test_marks_survive_snapshot_and_undo()

func _controller(enemy_id: StringName = &"gold_precise_steps"):
	var catalog = Catalog.new()
	return Controller.new(
		catalog.enemy(enemy_id),
		40,
		catalog.build_definition(Catalog.DICE_CONTROL)["techniques"],
		{},
		catalog
	)

func _test_unique_ownership_and_undo() -> void:
	var controller = _controller()
	assert_true(controller.begin_turn([3, 4, 2, 5, 1, 6], []).accepted, "turn should begin")
	assert_true(controller.assign_die(&"d1", &"attack").accepted, "die should enter attack lane")
	assert_equal(controller.state.assigned_lane(&"d1"), &"attack", "die should have one owner")
	assert_true(controller.assign_die(&"d1", &"guard").accepted, "reassignment should move the die")
	assert_equal(controller.state.assigned_lane(&"d1"), &"guard", "reassignment should not duplicate the die")
	assert_false(&"d1" in controller.state.assignments[&"attack"], "old lane should release reassigned die")
	assert_true(controller.undo().accepted, "pre-commit action should undo")
	assert_equal(controller.state.assigned_lane(&"d1"), &"attack", "undo should restore exact prior ownership")

func _test_technique_return_and_consumption() -> void:
	var controller = _controller()
	controller.begin_turn([2, 4, 1, 5, 3, 6], [])
	assert_true(controller.activate_technique(&"nudge_up", &"d1").accepted, "returning technique should activate")
	assert_equal(controller.state.find_die(&"d1").value, 3, "returning technique should alter die value")
	assert_true(controller.state.is_available(&"d1"), "returning technique should return die to tray")
	controller.state.technique_ids.append(&"map_attack")
	assert_true(controller.activate_technique(&"map_attack", &"d2").accepted, "high-yield technique should activate")
	assert_true(&"d2" in controller.state.consumed_die_ids, "high-yield technique should consume its die")
	assert_false(controller.assign_die(&"d2", &"attack").accepted, "consumed die cannot also occupy a rule lane")

func _test_independent_upgrade_branches_change_operation() -> void:
	var catalog = Catalog.new()
	var linked = Controller.new(catalog.enemy(&"gold_precise_steps"), 40, [&"map_attack"], {&"map_attack": &"a"}, catalog)
	linked.begin_turn([2, 1, 3, 4, 5, 6], [])
	assert_true(linked.activate_technique(&"map_attack", &"d1").accepted, "A branch should activate")
	assert_true(linked.state.is_available(&"d1"), "A branch should return a normally consumed die")
	var overloaded = Controller.new(catalog.enemy(&"gold_precise_steps"), 40, [&"nudge_up"], {&"nudge_up": &"b"}, catalog)
	overloaded.begin_turn([2, 1, 3, 4, 5, 6], [])
	assert_true(overloaded.activate_technique(&"nudge_up", &"d1").accepted, "B branch should activate")
	assert_true(overloaded.state.is_available(&"d1"), "push B keeps its own return policy")
	assert_equal(overloaded.state.intent_pressure, 2, "push B should add its declared risk")
	assert_true(&"nudge_up" in overloaded.state.die_technique_marks[&"d1"], "processed die should retain its technique mark")

func _test_preview_is_deterministic_and_kill_cancels_intent() -> void:
	var catalog = Catalog.new()
	var controller = _controller()
	controller.begin_turn([3, 4, 6, 6, 1, 2], [])
	controller.assign_die(&"d1", &"attack")
	controller.assign_die(&"d2", &"attack")
	controller.state.enemy_health = 7
	var enemy = catalog.enemy(&"gold_precise_steps")
	var intent = catalog.intent(&"probe")
	var first = controller.preview(enemy, intent)
	var second = controller.preview(enemy, intent)
	assert_equal(first.summary(), second.summary(), "preview should be pure and repeatable")
	assert_true(first.enemy_defeated, "matching attack lane should kill low-health enemy")
	assert_equal(first.incoming_damage, 0, "lethal damage should cancel the public enemy intent")
	var committed = controller.commit(enemy, intent)
	assert_equal(committed.player_health_after, 40, "canceled intent should not change player health")
	assert_false(controller.undo().accepted, "committed turns must not be undoable")

func _test_tactic_and_engine_extra_dice_stack() -> void:
	var catalog = Catalog.new()
	var controller = _controller(&"gold_precise_steps")
	controller.begin_turn([3, 4, 2, 5, 1, 6], [&"overclock"])
	assert_true(controller.activate_tactic(&"overclock").accepted, "one temporary tactic should activate")
	controller.assign_die(&"d6", &"engine")
	var report = controller.commit(catalog.enemy(&"gold_precise_steps"), catalog.intent(&"probe"))
	assert_true(report.engine_passed, "six should pass the high-point engine lane")
	assert_equal(controller.state.next_extra_dice, 2, "tactic and engine rewards should stack up to the cap")

func _test_guard_counter_happens_after_intent() -> void:
	var catalog = Catalog.new()
	var controller = Controller.new(catalog.enemy(&"gold_precise_steps"), 40, [&"map_guard"], {}, catalog)
	controller.begin_turn([1, 3, 3, 4, 5, 6], [])
	controller.activate_technique(&"map_guard", &"d1")
	controller.assign_die(&"d2", &"guard")
	controller.assign_die(&"d3", &"guard")
	controller.state.enemy_health = 3
	var report = controller.preview(catalog.enemy(&"gold_precise_steps"), catalog.intent(&"probe"))
	assert_equal(report.block_absorbed, 7, "counter should use actual absorbed damage")
	assert_equal(report.counter_damage, 3, "50 percent counter floors actual absorbed damage")
	assert_true(report.enemy_defeated, "counter may defeat the enemy")
	assert_false(report.intent_cancelled, "post-intent counter cannot cancel an executed intent")

func _test_engine_burst_cancels_intent_and_keeps_remainder() -> void:
	var catalog = Catalog.new()
	var controller = Controller.new(catalog.enemy(&"gold_precise_steps"), 40, [&"engine_charge"], {&"engine_charge": &"b"}, catalog)
	controller.begin_turn([2, 1, 3, 4, 5, 6], [])
	controller.state.engine_charge = 2
	controller.activate_technique(&"engine_charge", &"d1")
	controller.assign_die(&"d6", &"engine")
	controller.state.enemy_health = 20
	var report = controller.preview(catalog.enemy(&"gold_precise_steps"), catalog.intent(&"probe"))
	assert_equal(report.burst_count, 1, "five total charge should trigger one burst")
	assert_equal(report.engine_charge_after, 2, "burst should preserve charge remainder")
	assert_equal(report.engine_damage, 20, "overcharge should add five damage to each burst")
	assert_true(report.intent_cancelled, "engine burst lethal happens before intent")

func _test_retained_block_lasts_one_turn() -> void:
	var catalog = Catalog.new()
	var controller = Controller.new(catalog.enemy(&"gold_even_split"), 40, [&"even_drop"], {}, catalog)
	controller.begin_turn([4, 2, 2, 4, 5, 6], [])
	controller.activate_technique(&"even_drop", &"d1")
	controller.assign_die(&"d1", &"guard")
	controller.assign_die(&"d2", &"guard")
	var first = controller.commit(catalog.enemy(&"gold_even_split"), catalog.intent(&"probe"))
	assert_equal(first.retained_block_after, 3, "marked guard pass should retain three block")
	controller.begin_turn([1, 2, 3, 4, 5, 6], [])
	assert_equal(controller.state.carried_block, 3, "retained block should enter exactly the next turn")
	controller.commit(catalog.enemy(&"gold_even_split"), catalog.intent(&"probe"))
	controller.begin_turn([1, 2, 3, 4, 5, 6], [])
	assert_equal(controller.state.carried_block, 0, "unused retained block should expire after one intent")

func _test_multiple_engine_bursts() -> void:
	var catalog = Catalog.new()
	var controller = Controller.new(catalog.enemy(&"gold_precise_steps"), 40, [&"engine_charge", &"gold_stamp"], {&"engine_charge": &"b", &"gold_stamp": &"b"}, catalog)
	controller.begin_turn([2, 1, 3, 4, 5, 3, 6], [])
	controller.state.engine_charge = 2
	controller.activate_technique(&"engine_charge", &"d1")
	controller.activate_technique(&"gold_stamp", &"d2")
	controller.assign_die(&"d3", &"attack")
	controller.assign_die(&"d4", &"attack")
	controller.assign_die(&"d5", &"guard")
	controller.assign_die(&"d6", &"guard")
	controller.assign_die(&"d7", &"engine")
	var report = controller.preview(catalog.enemy(&"gold_precise_steps"), catalog.intent(&"probe"))
	assert_equal(report.engine_charge_gained, 5, "engine and three-table stamp should combine charge")
	assert_equal(report.burst_count, 2, "seven charge should trigger two bursts")
	assert_equal(report.engine_charge_after, 1, "two bursts should retain one charge")
	assert_equal(report.engine_damage, 40, "burst bonus should apply to every burst")

func _test_player_death_prevents_counter() -> void:
	var catalog = Catalog.new()
	var controller = Controller.new(catalog.enemy(&"gold_precise_steps"), 1, [&"map_guard"], {}, catalog)
	controller.begin_turn([1, 3, 3, 4, 5, 6], [])
	controller.activate_technique(&"map_guard", &"d1")
	controller.assign_die(&"d2", &"guard")
	controller.assign_die(&"d3", &"guard")
	var report = controller.preview(catalog.enemy(&"gold_precise_steps"), catalog.intent(&"audit"))
	assert_true(report.player_defeated, "insufficient block should defeat the player")
	assert_equal(report.counter_damage, 0, "defeated player must not counter")

func _test_marks_survive_snapshot_and_undo() -> void:
	var controller = _controller()
	controller.begin_turn([2, 4, 1, 5, 3, 6], [])
	controller.activate_technique(&"nudge_up", &"d1")
	assert_true(&"nudge_up" in controller.state.die_technique_marks[&"d1"], "activation should mark its die")
	var restored = _controller()
	restored.restore(controller.state.to_snapshot())
	assert_true(&"nudge_up" in restored.state.die_technique_marks[&"d1"], "save restoration should preserve die marks")
	controller.assign_die(&"d1", &"attack")
	controller.undo()
	assert_equal(controller.state.assigned_lane(&"d1"), &"", "undo should restore ownership")
	assert_true(&"nudge_up" in controller.state.die_technique_marks[&"d1"], "undo should preserve the prior mark snapshot")
