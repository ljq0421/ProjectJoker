extends "res://tests/test_case.gd"

const RESOLVER_PATH := "res://scripts/dice_first/dice_first_resolver.gd"
const STATE_PATH := "res://scripts/dice_first/dice_first_state.gd"
const CONTROLLER_PATH := "res://scripts/dice_first/dice_first_controller.gd"

func run() -> void:
	var resolver_script = load(RESOLVER_PATH)
	var state_script = load(STATE_PATH)
	assert_true(resolver_script != null and state_script != null, "dice-first domain should load")
	if resolver_script == null or state_script == null: return
	_test_resonance_priority(resolver_script, state_script)
	_test_structures_can_chain(resolver_script, state_script)
	_test_concrete_initial_candidates(resolver_script, state_script)
	_test_preserved_pair_upgrades_without_lock(resolver_script, state_script)
	_test_rerolled_combo_cannot_claim_upgrade(resolver_script, state_script)
	_test_breakthrough_keeps_combination(resolver_script, state_script)
	_test_instruction_uses_effect_spec(resolver_script, state_script)
	_test_cross_table_echo_changes_spatial_choice(resolver_script, state_script)
	_test_instruction_can_create_cross_table_echo(resolver_script, state_script)
	_test_polar_circuit_uses_different_cross_table_relation(resolver_script, state_script)
	_test_charge_table_trades_score_for_energy(resolver_script, state_script)
	_test_table_assignment_contract()
	_test_random_boundary_direct_reroll_and_cached_commit()

func _test_resonance_priority(resolver_script, state_script) -> void:
	var report = resolver_script.new().resolve(_build_state(state_script, [2, 2, 2, 4, 5, 6]))
	assert_equal(report.base_total, 21, "all six dice should count once")
	assert_true(report.has_resonance(&"triplet"), "three equal dice should form triplet")
	assert_false(report.has_resonance(&"pair"), "triplet should replace redundant same-value pair")

func _test_structures_can_chain(resolver_script, state_script) -> void:
	var report = resolver_script.new().resolve(_build_state(state_script, [1, 2, 3, 4, 5, 6]))
	assert_equal(report.resonance_ids(), [&"straight", &"polar_loop"], "combination order should be deterministic")

func _test_concrete_initial_candidates(resolver_script, state_script) -> void:
	var report = resolver_script.new().resolve(_build_state(state_script, [3, 3, 5, 5, 1, 2]))
	assert_true(not report.find_combo_candidate(&"same_3").is_empty(), "pair of threes should be a concrete initial combination")
	assert_true(not report.find_combo_candidate(&"same_5").is_empty(), "pair of fives should be a separate initial combination")
	assert_equal(report.find_combo_candidate(&"same_3")["die_ids"], [&"d1", &"d2"], "combination should name exact dice")

func _test_preserved_pair_upgrades_without_lock(resolver_script, state_script) -> void:
	var state = _build_state(state_script, [3, 3, 3, 1, 5, 6])
	state.initial_combo_candidates.append({"id": &"same_3", "kind": &"same", "value": 3, "initial_size": 2, "die_ids": [&"d1", &"d2"], "label": "一对 3"})
	state.rerolled_die_ids.assign([&"d3"])
	var report = resolver_script.new().resolve(state)
	assert_true(report.upgraded, "an untouched initial pair should upgrade when a third matching die appears")
	assert_equal(report.upgrade_energy, 1, "upgrade should grant one public energy")
	assert_equal(report.energy, 2, "triplet plus upgrade minus one reroll should reach break threshold")
	assert_equal(report.upgraded_candidate.get("id"), &"same_3", "report should identify which initial combination grew")

func _test_rerolled_combo_cannot_claim_upgrade(resolver_script, state_script) -> void:
	var state = _build_state(state_script, [3, 3, 3, 1, 5, 6])
	state.initial_combo_candidates.append({"id": &"same_3", "kind": &"same", "value": 3, "initial_size": 2, "die_ids": [&"d1", &"d2"], "label": "一对 3"})
	state.rerolled_die_ids.assign([&"d1"])
	var report = resolver_script.new().resolve(state)
	assert_false(report.upgraded, "rerolling a member should break the initial pair even if the final values match")
	assert_equal(report.broken_candidates.size(), 1, "report should expose the broken initial combination")

func _test_breakthrough_keeps_combination(resolver_script, state_script) -> void:
	var state = _build_state(state_script, [4, 4, 4, 1, 2, 6])
	var preview = resolver_script.new().resolve(state)
	state.breakthrough_requested = true
	var broken = resolver_script.new().resolve(state)
	assert_equal(broken.breakthrough_die_id, &"d1", "highest combination die should use stable id tie-break")
	assert_equal(broken.total, preview.total + 4, "break should expose exact delta")
	assert_true(broken.has_resonance(&"triplet"), "break die should stay in combination")

func _test_instruction_uses_effect_spec(resolver_script, state_script) -> void:
	var state = _build_state(state_script, [2, 3, 4, 5, 6, 1])
	var effect := EffectSpec.new()
	effect.operation = EffectSpec.Operation.FLIP_DIE
	var definition := CardDefinition.new()
	definition.id = &"rewrite_flip"
	definition.display_name = "翻到另一面"
	definition.effects = [effect]
	state.played_cards.append(PlayedCard.new(definition, &"d1"))
	var report = resolver_script.new().resolve(state)
	assert_equal(report.effective_die_values.get(&"d1"), 5, "instruction should flow through EffectSpec")

func _test_cross_table_echo_changes_spatial_choice(resolver_script, state_script) -> void:
	var split_pair = _build_state(state_script, [5, 5, 1, 2, 3, 4])
	split_pair.table_rule_id = &"echo"
	split_pair.left_table_die_ids.assign([&"d1", &"d3", &"d4"])
	split_pair.right_table_die_ids.assign([&"d2", &"d5", &"d6"])
	var split_report = resolver_script.new().resolve(split_pair)
	assert_true(split_report.table_allocation_complete, "three dice on each table should complete allocation")
	assert_equal(split_report.table_score, 5, "a value split across both tables should repeat once")
	assert_equal(split_report.table_energy, 1, "a cross-table echo should charge one energy")
	assert_equal(split_report.table_matches.size(), 1, "echo matches should be public and deterministic")

	var same_side_pair = _build_state(state_script, [5, 5, 1, 2, 3, 4])
	same_side_pair.table_rule_id = &"echo"
	same_side_pair.left_table_die_ids.assign([&"d1", &"d2", &"d3"])
	same_side_pair.right_table_die_ids.assign([&"d4", &"d5", &"d6"])
	var same_side_report = resolver_script.new().resolve(same_side_pair)
	assert_equal(same_side_report.table_score, 0, "the same pair kept on one table should not echo")
	assert_equal(same_side_report.table_energy, 0, "spatial placement should change the energy result")

func _test_instruction_can_create_cross_table_echo(resolver_script, state_script) -> void:
	var state = _build_state(state_script, [4, 5, 1, 2, 3, 6])
	state.table_rule_id = &"echo"
	state.left_table_die_ids.assign([&"d1", &"d3", &"d4"])
	state.right_table_die_ids.assign([&"d2", &"d5", &"d6"])
	var effect := EffectSpec.new()
	effect.operation = EffectSpec.Operation.ADJUST_DIE
	effect.amount = -1
	var definition := CardDefinition.new()
	definition.id = &"rewrite_down"
	definition.display_name = "点数 -1"
	definition.effects = [effect]
	state.played_cards.append(PlayedCard.new(definition, &"d2"))
	var report = resolver_script.new().resolve(state)
	assert_equal(report.table_matches.size(), 1, "an instruction should be able to create a cross-table echo")
	assert_true(report.events.any(func(event): return event.source_id == &"cross_table_echo_4"), "echo should enter the formal event list")

func _test_polar_circuit_uses_different_cross_table_relation(resolver_script, state_script) -> void:
	var state = _build_state(state_script, [1, 2, 3, 6, 5, 4])
	state.table_rule_id = &"polar"
	state.left_table_die_ids.assign([&"d1", &"d2", &"d3"])
	state.right_table_die_ids.assign([&"d4", &"d5", &"d6"])
	var report = resolver_script.new().resolve(state)
	assert_equal(report.table_matches.size(), 3, "polar circuit should match all three sum-seven pairs")
	assert_equal(report.table_score, 15, "polar circuit should replay the higher die in each pair")
	assert_equal(report.table_energy, 3, "each polar link should charge one energy")
	assert_true(report.events.any(func(event): return event.source_id == &"polar_link_1_6"), "polar links should enter formal events")

func _test_charge_table_trades_score_for_energy(resolver_script, state_script) -> void:
	var state = _build_state(state_script, [6, 5, 4, 1, 2, 3])
	state.table_rule_id = &"charge"
	state.left_table_die_ids.assign([&"d1", &"d2", &"d3"])
	state.right_table_die_ids.assign([&"d4", &"d5", &"d6"])
	var report = resolver_script.new().resolve(state)
	assert_equal(report.base_total, 21, "base dice should remain auditable before table behavior")
	assert_equal(report.table_score, 0, "storing 1+2+3 then replaying the left six should net zero table score")
	assert_equal(report.table_energy, 3, "three distinct stored faces should charge three energy")
	assert_true(report.events.any(func(event): return event.source_id == &"charge_store" and event.delta == -6), "stored dice should visibly leave base score")
	assert_true(report.events.any(func(event): return event.source_id == &"charge_release" and event.delta == 6), "a full distinct charge should replay the left high die")

func _test_table_assignment_contract() -> void:
	var controller = load(CONTROLLER_PATH).new(8042026)
	assert_true(controller.roll_initial(), "fixture should roll")
	assert_true(controller.state.table_rule_id in [&"echo", &"polar", &"charge"], "one public table rule should be selected before decisions")
	assert_true(controller.keep_all(), "fixture should enter build")
	assert_true(controller.assign_die_to_table(&"d1", &"left"), "a build die should enter left table")
	assert_true(controller.assign_die_to_table(&"d2", &"left"), "a second die should enter left table")
	assert_true(controller.assign_die_to_table(&"d3", &"left"), "left table should accept three dice")
	assert_false(controller.assign_die_to_table(&"d4", &"left"), "a table should reject a fourth die")
	assert_true(controller.assign_die_to_table(&"d4", &"right"), "right table should accept dice")
	assert_true(controller.assign_die_to_table(&"d5", &"right"), "right table should accept a second die")
	assert_true(controller.assign_die_to_table(&"d6", &"right"), "right table should accept a third die")
	assert_true(controller.preview().table_allocation_complete, "three plus three should be ready to settle")
	assert_false(controller.assign_die_to_table(&"d1", &"right"), "a full destination should reject reassignment")
	assert_true(controller.preview().table_allocation_complete, "rejected reassignment should preserve the valid layout")
	assert_true(controller.clear_die_table(&"d1"), "a placed die should be removable")
	assert_false(controller.preview().table_allocation_complete, "removing a die should reopen the layout")

func _build_state(state_script, values: Array):
	var state = state_script.new()
	for index in range(values.size()): state.dice.append(DieState.new(StringName("d%d" % (index + 1)), values[index]))
	return state

func _test_random_boundary_direct_reroll_and_cached_commit() -> void:
	var controller = load(CONTROLLER_PATH).new(8042026)
	assert_true(controller.roll_initial(), "initial roll should be first random boundary")
	assert_true(controller.toggle_reroll_die(&"d1"), "any die should be directly selectable without a lock step")
	var replay = load(CONTROLLER_PATH).new(8042026)
	assert_true(replay.roll_initial(), "same-seed replay should roll")
	assert_equal(replay.state.table_rule_id, controller.state.table_rule_id, "same seed should reproduce the public table rule")
	assert_equal(replay.state.dice.map(func(die): return die.value), controller.state.dice.map(func(die): return die.value), "same seed should reproduce all initial dice")
	var decision = controller.preview()
	assert_equal(decision.preserved_candidates.map(func(entry): return entry.get("id")), [&"same_3"], "unselected pair should remain intact")
	assert_equal(decision.broken_candidates.map(func(entry): return entry.get("id")), [&"same_5"], "selected pair member should be shown as broken")
	assert_true(controller.confirm_reroll(), "selected reroll should execute once")
	assert_false(controller.confirm_reroll(), "reroll must stop after build begins")
	for index in range(3): assert_true(controller.assign_die_to_table(StringName("d%d" % (index + 1)), &"left"), "left table allocation should succeed")
	for index in range(3, 6): assert_true(controller.assign_die_to_table(StringName("d%d" % (index + 1)), &"right"), "right table allocation should succeed")
	var preview_signature: Array[String] = controller.preview().event_signature()
	var committed = controller.commit()
	assert_true(committed != null, "deterministic build should commit")
	assert_equal(committed.event_signature(), preview_signature, "commit should reuse exact resolver path")
	assert_true(controller.commit() == committed, "repeated commit should return cached report")
