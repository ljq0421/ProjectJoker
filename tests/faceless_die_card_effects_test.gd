extends "res://tests/test_case.gd"

func run() -> void:
	_test_pair_targets_must_be_distinct_existing_dice()
	_test_enhanced_swap_rewards_unique_final_tables()
	_test_enhanced_swap_rejects_equal_effective_values()
	_test_swap_then_copy_resolves_in_real_play_order()
	_test_flip_maps_each_face_to_its_opposite()
	_test_lock_blocks_modification_until_undone()
	_test_lock_bonus_only_scores_on_a_passing_table()
	_test_lock_bonus_triggers_for_each_successful_resolution()
	_test_echo_resolution_retriggers_lock_bonus()
	_test_unassigned_lock_does_not_score()
	_test_lock_bonus_is_not_transferred_by_bridge()
	_test_calibration_refund_requires_spent_capacity()

func _test_pair_targets_must_be_distinct_existing_dice() -> void:
	var controller := RoundController.new(_state([1, 2]), _encounter([1, 2]))
	var swap := _card(
		&"swap",
		CardDefinition.TargetType.DICE_PAIR,
		EffectSpec.Operation.SWAP_DICE
	)
	assert_false(
		controller.play_card(PlayedCard.new(swap, &"d1", &"d1")).accepted,
		"swap should reject the same die twice"
	)
	assert_false(
		controller.play_card(PlayedCard.new(swap, &"d1", &"missing")).accepted,
		"swap should reject an unknown second die"
	)
	assert_true(
		controller.play_card(PlayedCard.new(swap, &"d1", &"d2")).accepted,
		"swap should accept two distinct existing dice"
	)

func _test_enhanced_swap_rewards_unique_final_tables() -> void:
	var swap := CardCatalog.new().find_card(&"faceless_swap_values")
	assert_equal(swap.effects[0].amount, 1, "enhanced swap grants one coefficient")

	var split_state := _state([1, 6])
	split_state.assignments = {&"left": [&"d1"], &"right": [&"d2"]}
	var split := RoundController.new(split_state, _encounter([6, 0, 1]))
	assert_true(
		split.play_card(PlayedCard.new(swap, &"d1", &"d2")).accepted,
		"different values on different tables should accept enhanced swap"
	)
	var split_report := split.preview()
	assert_equal(split_report.effective_die_values[&"d1"], 6, "first value swaps")
	assert_equal(split_report.effective_die_values[&"d2"], 1, "second value swaps")
	assert_equal(
		split_report.effective_table_coefficients[&"left"],
		2,
		"first final table gains one coefficient"
	)
	assert_equal(
		split_report.effective_table_coefficients[&"right"],
		2,
		"second final table gains one coefficient"
	)

	var same_state := _state([1, 6])
	same_state.assignments = {&"left": [&"d1", &"d2"]}
	var same_encounter := _encounter([7])
	same_encounter.rules[0].slot_count = 2
	var same := RoundController.new(same_state, same_encounter)
	assert_true(
		same.play_card(PlayedCard.new(swap, &"d1", &"d2")).accepted,
		"different values on one table should accept enhanced swap"
	)
	assert_equal(
		same.preview().effective_table_coefficients[&"left"],
		2,
		"two targets on the same table grant the bonus only once"
	)

	var partial_state := _state([1, 6])
	partial_state.assignments = {&"left": [&"d1"]}
	var partial := RoundController.new(partial_state, _encounter([6]))
	assert_true(
		partial.play_card(PlayedCard.new(swap, &"d1", &"d2")).accepted,
		"an unassigned target should still participate in the value swap"
	)
	assert_equal(
		partial.preview().effective_table_coefficients[&"left"],
		2,
		"only the assigned target table gains a coefficient"
	)

	var moved_state := _state([1, 6])
	moved_state.assignments = {&"left": [&"d1"], &"right": [&"d2"]}
	var moved := RoundController.new(moved_state, _encounter([6, 1, 0]))
	assert_true(
		moved.play_card(PlayedCard.new(swap, &"d1", &"d2")).accepted,
		"enhanced swap should play before final placement changes"
	)
	assert_true(
		moved.assign_die_to_slot(&"d2", &"middle", 0, 1).accepted,
		"target die should remain movable after the card is played"
	)
	var moved_report := moved.preview()
	assert_equal(
		moved_report.effective_table_coefficients[&"middle"],
		2,
		"bonus follows the target die to its final table"
	)
	assert_equal(
		moved_report.effective_table_coefficients[&"right"],
		1,
		"the target's former table loses the preview bonus"
	)

func _test_enhanced_swap_rejects_equal_effective_values() -> void:
	var state := _state([3, 3])
	state.assignments = {&"left": [&"d1"], &"right": [&"d2"]}
	var controller := RoundController.new(state, _encounter([3, 0, 3]))
	var swap := CardCatalog.new().find_card(&"faceless_swap_values")
	var result := controller.play_card(PlayedCard.new(swap, &"d1", &"d2"))
	assert_false(result.accepted, "equal effective values should reject enhanced swap")
	assert_equal(
		result.reason,
		"换值联动需要选择当前有效点数不同的两颗骰子",
		"equal-value rejection should explain the actual requirement"
	)

func _test_swap_then_copy_resolves_in_real_play_order() -> void:
	var state := _state([1, 6, 3])
	state.assignments = {
		&"left": [&"d1"],
		&"middle": [&"d2"],
		&"right": [&"d3"],
	}
	var controller := RoundController.new(
		state,
		_encounter([6, 1, 6])
	)
	var swap := _card(
		&"swap_order",
		CardDefinition.TargetType.DICE_PAIR,
		EffectSpec.Operation.SWAP_DICE
	)
	var copy := _card(
		&"copy_order",
		CardDefinition.TargetType.DICE_PAIR,
		EffectSpec.Operation.COPY_DIE
	)
	assert_true(
		controller.play_card(PlayedCard.new(swap, &"d1", &"d2")).accepted,
		"swap should play first"
	)
	assert_true(
		controller.play_card(PlayedCard.new(copy, &"d1", &"d3")).accepted,
		"copy should see the swapped source value"
	)
	var report := controller.preview()
	assert_true(report.valid, "ordered die effects should resolve")
	assert_equal(report.total, 13, "swap then copy should produce 6, 1, 6")
	assert_equal(report.events[0].source_id, &"swap_order", "swap event stays first")
	assert_equal(report.events[1].source_id, &"copy_order", "copy event stays second")

func _test_flip_maps_each_face_to_its_opposite() -> void:
	for value in range(1, 7):
		var state := _state([value])
		state.assignments = {&"left": [&"d1"]}
		var encounter := _encounter([7 - value])
		var controller := RoundController.new(state, encounter)
		var flip := _card(
			StringName("flip_%d" % value),
			CardDefinition.TargetType.DIE,
			EffectSpec.Operation.FLIP_DIE
		)
		assert_true(
			controller.play_card(PlayedCard.new(flip, &"d1")).accepted,
			"flip %d should be legal" % value
		)
		assert_equal(
			controller.preview().total,
			7 - value,
			"flip should map %d to %d" % [value, 7 - value]
		)

func _test_lock_blocks_modification_until_undone() -> void:
	var controller := RoundController.new(_state([2, 5]), _encounter([2, 5]))
	var lock := _card(
		&"lock",
		CardDefinition.TargetType.DIE,
		EffectSpec.Operation.LOCK_DIE_WITH_BONUS,
		4
	)
	assert_true(
		controller.play_card(PlayedCard.new(lock, &"d1")).accepted,
		"lock card should play"
	)
	assert_true(&"d1" in controller.state.locked_die_ids(), "state exposes locked die")
	assert_false(controller.adjust_die(&"d1", 1).accepted, "lock blocks calibration")

	var adjust := _card(
		&"adjust_locked",
		CardDefinition.TargetType.DIE,
		EffectSpec.Operation.ADJUST_DIE,
		1
	)
	assert_false(
		controller.play_card(PlayedCard.new(adjust, &"d1")).accepted,
		"lock blocks adjust-die cards"
	)
	var copy := _card(
		&"copy_locked",
		CardDefinition.TargetType.DICE_PAIR,
		EffectSpec.Operation.COPY_DIE
	)
	assert_false(
		controller.play_card(PlayedCard.new(copy, &"d2", &"d1")).accepted,
		"lock blocks copy when the locked die is the target"
	)

	assert_true(controller.undo(), "lock card should be undoable")
	assert_false(&"d1" in controller.state.locked_die_ids(), "undo removes the lock")
	assert_true(controller.adjust_die(&"d1", 1).accepted, "undo restores calibration")

func _test_lock_bonus_only_scores_on_a_passing_table() -> void:
	var lock := _card(
		&"lock_bonus",
		CardDefinition.TargetType.DIE,
		EffectSpec.Operation.LOCK_DIE_WITH_BONUS,
		4
	)
	var passing_state := _state([3])
	passing_state.assignments = {&"left": [&"d1"]}
	var passing := RoundController.new(passing_state, _encounter([3]))
	assert_true(passing.play_card(PlayedCard.new(lock, &"d1")).accepted, "lock passes")
	var passing_report := passing.preview()
	assert_equal(passing_report.total, 7, "passing table adds the fixed lock bonus")
	assert_true(
		_has_event(passing_report, &"lock_bonus", 4),
		"lock reward should be a visible event"
	)

	var failing_state := _state([3])
	failing_state.assignments = {&"left": [&"d1"]}
	var failing := RoundController.new(failing_state, _encounter([4]))
	assert_true(failing.play_card(PlayedCard.new(lock, &"d1")).accepted, "lock still plays")
	var repeat := _card(
		&"repeat_failed_lock_table",
		CardDefinition.TargetType.TABLE,
		EffectSpec.Operation.REPEAT_TABLE,
		3
	)
	assert_true(
		failing.play_card(PlayedCard.new(repeat, &"left")).accepted,
		"repeat should still target the failed locked table"
	)
	var failing_report := failing.preview()
	assert_equal(failing_report.total, 0, "failed table grants no lock bonus")
	assert_false(
		_has_event(failing_report, &"lock_bonus", 4),
		"failed table should not emit a successful lock reward"
	)
	var missed_lock_events := _score_events_for_source(failing_report, &"lock_bonus")
	assert_equal(missed_lock_events.size(), 1, "failed repeats should report one missed lock effect")
	assert_false(missed_lock_events[0].effect_applied, "failed lock reward stays unapplied")

func _test_lock_bonus_triggers_for_each_successful_resolution() -> void:
	for extra_resolutions in range(4):
		var state := _state([3])
		state.assignments = {&"left": [&"d1"]}
		var controller := RoundController.new(state, _encounter([3]))
		var lock := _card(
			&"lock_chain",
			CardDefinition.TargetType.DIE,
			EffectSpec.Operation.LOCK_DIE_WITH_BONUS,
			4
		)
		assert_true(
			controller.play_card(PlayedCard.new(lock, &"d1")).accepted,
			"chain lock should play"
		)
		if extra_resolutions > 0:
			var repeat := _card(
				&"repeat_lock_table",
				CardDefinition.TargetType.TABLE,
				EffectSpec.Operation.REPEAT_TABLE,
				extra_resolutions
			)
			assert_true(
				controller.play_card(PlayedCard.new(repeat, &"left")).accepted,
				"repeat should target the locked die's table"
			)

		var report := controller.preview()
		var expected_triggers := 1 + extra_resolutions
		assert_equal(
			report.total,
			7 * expected_triggers,
			"each successful table resolution should add base three and lock four"
		)
		var lock_events := _score_events_for_source(report, &"lock_chain")
		assert_equal(
			lock_events.size(),
			expected_triggers,
			"lock should trigger once per successful table resolution"
		)
		for event in lock_events:
			assert_equal(event.delta, 4, "each lock trigger should grant four")
			assert_equal(
				event.score_source,
				ResolutionEvent.ScoreSource.CARD,
				"lock rewards should remain card score"
			)
			var event_index := report.events.find(event)
			assert_true(event_index > 0, "lock reward should follow a table event")
			assert_equal(
				report.events[event_index - 1].source_id,
				&"left",
				"each lock reward should immediately follow its table resolution"
			)

func _test_echo_resolution_retriggers_lock_bonus() -> void:
	var state := _state([3])
	state.assignments = {&"left": [&"d1"]}
	var encounter := _encounter([3])
	var echo_template := RuleTableTemplate.new()
	echo_template.id = &"lock_echo"
	echo_template.display_name = "定格回声测试"
	echo_template.condition_kind = RuleTableTemplate.ConditionKind.ANY_FILLED
	echo_template.post_pass_effect = RuleTableTemplate.PostPassEffect.ECHO_SELF
	encounter.rules[0].template = echo_template
	var controller := RoundController.new(state, encounter)
	var lock := _card(
		&"lock_echo_bonus",
		CardDefinition.TargetType.DIE,
		EffectSpec.Operation.LOCK_DIE_WITH_BONUS,
		4
	)
	assert_true(
		controller.play_card(PlayedCard.new(lock, &"d1")).accepted,
		"echo lock should play"
	)

	var report := controller.preview()
	assert_equal(report.total, 14, "base and echo resolutions should each grant lock four")
	var lock_events := _score_events_for_source(report, &"lock_echo_bonus")
	assert_equal(lock_events.size(), 2, "echo should retrigger the lock reward")
	assert_equal(
		report.events[report.events.find(lock_events[0]) - 1].source_id,
		&"left",
		"first lock reward should follow the base table score"
	)
	assert_equal(
		report.events[report.events.find(lock_events[1]) - 1].source_id,
		&"lock_echo",
		"second lock reward should follow the echo score"
	)

func _test_unassigned_lock_does_not_score() -> void:
	var controller := RoundController.new(_state([3]), _encounter([0]))
	var lock := _card(
		&"lock_unassigned",
		CardDefinition.TargetType.DIE,
		EffectSpec.Operation.LOCK_DIE_WITH_BONUS,
		4
	)
	assert_true(
		controller.play_card(PlayedCard.new(lock, &"d1")).accepted,
		"unassigned die can still be locked"
	)
	var report := controller.preview()
	assert_equal(report.total, 0, "unassigned lock should not score")
	assert_equal(
		_score_events_for_source(report, &"lock_unassigned").size(),
		0,
		"unassigned lock should not emit a reward event"
	)

func _test_lock_bonus_is_not_transferred_by_bridge() -> void:
	var state := _state([3, 3])
	state.assignments = {&"left": [&"d1"], &"middle": [&"d2"]}
	var controller := RoundController.new(state, _encounter([3, 3]))
	var lock := _card(
		&"lock_before_bridge",
		CardDefinition.TargetType.DIE,
		EffectSpec.Operation.LOCK_DIE_WITH_BONUS,
		4
	)
	var bridge := _card(
		&"bridge_after_lock",
		CardDefinition.TargetType.GAP,
		EffectSpec.Operation.LINK_NEIGHBORS,
		1
	)
	assert_true(
		controller.play_card(PlayedCard.new(lock, &"d1")).accepted,
		"bridge fixture lock should play"
	)
	assert_true(
		controller.play_card(PlayedCard.new(bridge, &"left", &"middle")).accepted,
		"bridge should connect the locked table to its neighbor"
	)

	var report := controller.preview()
	assert_equal(report.total, 13, "bridge should copy three, not the lock-enhanced seven")
	assert_true(
		_has_event(report, &"bridge_after_lock", 3),
		"bridge event should expose the unmodified source-table total"
	)

func _test_calibration_refund_requires_spent_capacity() -> void:
	var refund := _card(
		&"refund",
		CardDefinition.TargetType.GLOBAL,
		EffectSpec.Operation.REFUND_CALIBRATION,
		1
	)
	var full_state := _state([3])
	full_state.calibration_points = 2
	assert_false(
		CardRules.play_card(full_state, PlayedCard.new(refund)).accepted,
		"refund should reject when no calibration was spent"
	)

	var spent_state := _state([3])
	spent_state.calibration_points = 1
	var refunded := CardRules.play_card(spent_state, PlayedCard.new(refund))
	assert_true(refunded.accepted, "refund should restore spent calibration")
	assert_equal(refunded.next_state.calibration_points, 2, "refund caps at two")

func _state(values: Array[int]) -> RoundState:
	var state := RoundState.new()
	for index in values.size():
		state.dice.append(DieState.new(
			StringName("d%d" % (index + 1)),
			values[index]
		))
	return state

func _encounter(targets: Array[int]) -> EncounterDefinition:
	var encounter := EncounterDefinition.new()
	encounter.id = &"faceless_die_effect_fixture"
	var ids: Array[StringName] = [&"left", &"middle", &"right"]
	for index in targets.size():
		var rule := RuleDefinition.new()
		rule.id = ids[index]
		rule.display_name = String(ids[index])
		rule.slot_count = 1
		rule.target_value = targets[index]
		rule.coefficient = 1
		encounter.rules.append(rule)
	return encounter

func _card(
	card_id: StringName,
	target_type: CardDefinition.TargetType,
	operation: EffectSpec.Operation,
	amount: int = 0
) -> CardDefinition:
	var effect := EffectSpec.new()
	effect.operation = operation
	effect.amount = amount
	var card := CardDefinition.new()
	card.id = card_id
	card.display_name = String(card_id)
	card.rule_text = "测试结构化骰值效果。"
	card.tags = PackedStringArray(["骰值"])
	card.target_type = target_type
	card.suit = CardDefinition.Suit.CLUBS
	card.rank_label = "测试"
	card.rarity = CardDefinition.Rarity.COMMON
	card.effects = [effect]
	return card

func _has_event(
	report: ResolutionReport,
	source_id: StringName,
	delta: int
) -> bool:
	for event in report.events:
		if event.source_id == source_id and event.delta == delta:
			return true
	return false

func _score_events_for_source(
	report: ResolutionReport,
	source_id: StringName
) -> Array:
	var matches: Array = []
	for event in report.events:
		if (
			event.source_id == source_id
			and event.score_source == ResolutionEvent.ScoreSource.CARD
		):
			matches.append(event)
	return matches
