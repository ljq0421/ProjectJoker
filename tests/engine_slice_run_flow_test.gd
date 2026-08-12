extends "res://tests/test_case.gd"

const Session = preload("res://scripts/engine_slice/engine_slice_run_session.gd")
const Catalog = preload("res://scripts/engine_slice/engine_slice_catalog.gd")

func run() -> void:
	for first_id in [&"gold_precise_steps", &"gold_even_split"]:
		for second_id in [&"gold_narrow_ledger", &"gold_parallel_proof"]:
			_test_route_combination(first_id, second_id)
	_test_shop_is_atomic()

func _test_route_combination(first_id: StringName, second_id: StringName) -> void:
	var run_session = Session.new()
	assert_true(run_session.start_new(20260811, Catalog.DICE_CONTROL).accepted, "route fixture should start")
	assert_true(run_session.choose_route(first_id).accepted, "first route should be selectable")
	run_session.battle.state.player_health = 27
	_force_victory(run_session)
	assert_equal(run_session.phase, Session.Phase.REWARD, "first victory should lead to a reward")
	assert_equal(run_session.player_health, 27, "health should persist between rooms")
	assert_true(_take_tactic_reward(run_session), "first reward should include a tactic category")
	assert_equal(run_session.phase, Session.Phase.SHOP, "first reward should lead to shop/rest")
	assert_true(run_session.leave_shop().accepted, "shop should lead to second route")
	assert_true(run_session.choose_route(second_id).accepted, "second route should be selectable")
	assert_equal(run_session.battle.state.player_health, 27, "next battle should inherit player health")
	_force_victory(run_session)
	assert_equal(run_session.phase, Session.Phase.REWARD, "elite victory should lead to another reward")
	assert_true(_take_tactic_reward(run_session), "elite reward should include a tactic category")
	assert_equal(run_session.current_enemy_id, &"dealer_iron_abacus_engine", "second reward should start Iron Abacus")
	assert_equal(run_session.phase, Session.Phase.BATTLE, "dealer should be a real health battle")
	_force_victory(run_session)
	assert_equal(run_session.phase, Session.Phase.RESULT, "dealer victory should finish the slice")
	assert_true(run_session.result_copy.contains("总账"), "victory result should explain the dealer defeat")

func _force_victory(run_session) -> void:
	run_session.battle.state.flat_damage = 999
	var report = run_session.commit_turn()
	assert_true(report.valid and report.enemy_defeated, "fixture should defeat enemy before its intent")

func _take_tactic_reward(run_session) -> bool:
	for index in run_session.reward_options.size():
		if StringName(run_session.reward_options[index]["kind"]) == &"tactic":
			return run_session.choose_reward(index).accepted
	return false

func _test_shop_is_atomic() -> void:
	var run_session = Session.new()
	run_session.start_new(20260812, Catalog.TABLE_CHAIN)
	run_session.choose_route(&"gold_precise_steps")
	_force_victory(run_session)
	_take_tactic_reward(run_session)
	var before: int = run_session.intel
	assert_false(run_session.buy_heal().accepted, "full-health heal should reject")
	assert_equal(run_session.intel, before, "rejected shop service should not spend currency")
	assert_true(run_session.buy_upgrade(run_session.technique_ids[0], &"a").accepted, "valid upgrade should buy atomically")
	assert_equal(run_session.intel, before - 3, "accepted upgrade should spend exact cost once")
	assert_false(run_session.buy_upgrade(run_session.technique_ids[0], &"b").accepted, "A/B branches should be mutually exclusive")
	assert_equal(run_session.intel, before - 3, "rejected second branch should not spend again")
