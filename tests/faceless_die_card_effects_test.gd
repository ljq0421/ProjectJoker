extends "res://tests/test_case.gd"

func run() -> void:
	_test_pair_targets_must_be_distinct_existing_dice()
	_test_swap_then_copy_resolves_in_real_play_order()
	_test_flip_maps_each_face_to_its_opposite()
	_test_lock_blocks_modification_until_undone()
	_test_lock_bonus_only_scores_on_a_passing_table()
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
	var failing_report := failing.preview()
	assert_equal(failing_report.total, 0, "failed table grants no lock bonus")
	assert_false(
		_has_event(failing_report, &"lock_bonus", 4),
		"failed table should not emit a successful lock reward"
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
