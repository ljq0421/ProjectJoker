extends "res://tests/test_case.gd"

func run() -> void:
	_test_complete_slice_and_restart()
	_test_verification_retry_and_stale_reports()
	_test_dealer_boundary_retry()
	_test_same_seed_replays_full_random_state()

func _test_complete_slice_and_restart() -> void:
	var slice := IronAbacusSliceSession.new(20260726, 0, 0)
	assert_true(slice.start().accepted, "slice should start normal room")
	var stale_report := _commit_three_empty_rounds(slice)[0]
	assert_equal(slice.phase, IronAbacusSliceSession.Phase.NORMAL_ROOM, "normal success waits")
	assert_true(slice.open_shop().accepted, "normal success should open shop")
	assert_false(
		slice.accept_encounter_report(stale_report).accepted,
		"report from a previous phase should be rejected"
	)

	var original_replaced: StringName = slice.shop_session.deck_ids[0]
	var bought: StringName = slice.shop_session.offer_ids[0]
	assert_true(
		slice.shop_session.purchase(bought, original_replaced).accepted,
		"shop replacement should succeed"
	)
	assert_true(slice.leave_shop().accepted, "leaving shop should preserve state")
	assert_equal(slice.intel_tickets, 1, "shop purchase should leave one ticket")
	assert_true(slice.start_dealer().accepted, "dealer should start from boundary")
	assert_true(bought in slice.deck_ids, "dealer deck should inherit purchase")
	assert_equal(slice.intel_tickets, 1, "dealer should inherit remaining tickets")
	_commit_three_empty_rounds(slice)
	assert_equal(
		slice.phase,
		IronAbacusSliceSession.Phase.ENGRAVING_REWARD,
		"zero dealer target should prepare reward"
	)
	assert_equal(slice.engraving_offer_ids.size(), 3, "reward should show three of four")

	var phase_before := slice.phase
	var profiles_before := _profile_signature(slice.die_profiles)
	assert_false(slice.select_engraving(&"missing_engraving").accepted, "unknown offer rejects")
	assert_equal(slice.phase, phase_before, "invalid offer should not change phase")
	assert_equal(_profile_signature(slice.die_profiles), profiles_before, "invalid offer is atomic")

	assert_true(
		slice.select_engraving(slice.engraving_offer_ids[0]).accepted,
		"first offered engraving should select"
	)
	assert_true(
		slice.select_engraving(slice.engraving_offer_ids[1]).accepted,
		"pending engraving selection should be changeable"
	)
	var choice := _verifiable_offer(slice)
	assert_true(slice.select_engraving(choice.id).accepted, "verifiable offer should select")
	assert_false(
		slice.install_selected_engraving(&"missing_die", choice.face).accepted,
		"unknown die should reject"
	)
	assert_false(
		slice.install_selected_engraving(&"d1", 7).accepted,
		"invalid face should reject"
	)
	assert_equal(_profile_signature(slice.die_profiles), profiles_before, "failed install is atomic")

	assert_true(
		slice.install_selected_engraving(&"d1", choice.face).accepted,
		"valid engraving installation should start verification"
	)
	assert_equal(slice.phase, IronAbacusSliceSession.Phase.VERIFICATION, "verification should open")
	var forced := slice.verification_session.controller.state.find_die(&"d1")
	assert_equal(forced.rolled_value, choice.face, "installed die should show forced face")
	assert_equal(forced.value, choice.face, "forced face should be the initial effective value")
	assert_true(slice.verification_session.activate_die(&"d1"), "forced die should select")
	assert_true(
		slice.verification_session.activate_table(&"right"),
		"forced prism/anchor die should enter the even table"
	)
	var verification_report := slice.verification_session.commit()
	assert_true(
		verification_report.events.any(
			func(event: ResolutionEvent) -> bool: return (
				event.source_id == choice.id and event.effect_applied
			)
		),
		"verification should contain an applied selected engraving event"
	)
	assert_true(
		slice.accept_verification_report(verification_report).accepted,
		"applied verification report should be accepted"
	)
	assert_equal(slice.phase, IronAbacusSliceSession.Phase.COMPLETE, "slice should complete")

	assert_true(slice.restart_slice().accepted, "complete slice should restart")
	assert_equal(slice.phase, IronAbacusSliceSession.Phase.NORMAL_ROOM, "restart returns to normal")
	assert_equal(slice.intel_tickets, 0, "restart should clear tickets")
	assert_equal(slice.deck_ids, CardCatalog.new().starter_ids(), "restart should clear purchase")
	assert_equal(slice.selected_engraving_id, &"", "restart should clear selection")
	assert_equal(slice.installed_die_id, &"", "restart should clear installed die")
	assert_equal(slice.installed_face, 0, "restart should clear installed face")
	assert_true(
		slice.die_profiles.all(
			func(profile: DieState) -> bool: return (
				profile.engraving_id == &"" and profile.engraved_face == 0
			)
		),
		"restart should clear every die engraving"
	)

func _test_verification_retry_and_stale_reports() -> void:
	var slice := _drive_to_verification(20260726)
	var first_hand := _hand_ids(slice.verification_session)
	var first_dice := _rolled_values(slice.verification_session)
	var report := slice.verification_session.commit()
	assert_true(
		slice.accept_verification_report(report).accepted,
		"non-applied committed verification should still be accepted once"
	)
	assert_equal(
		slice.phase,
		IronAbacusSliceSession.Phase.VERIFICATION,
		"non-applied verification should remain in verification"
	)
	assert_false(
		slice.accept_verification_report(report).accepted,
		"same verification report should not be accepted twice"
	)
	assert_true(slice.retry_verification().accepted, "failed verification should retry")
	assert_equal(_hand_ids(slice.verification_session), first_hand, "retry should replay hand")
	assert_equal(_rolled_values(slice.verification_session), first_dice, "retry should replay dice")

func _test_dealer_boundary_retry() -> void:
	var slice := IronAbacusSliceSession.new(20260726, 0, 9999)
	assert_true(slice.start().accepted, "failure fixture should start")
	_commit_three_empty_rounds(slice)
	assert_true(slice.open_shop().accepted, "failure fixture should open shop")
	var bought: StringName = slice.shop_session.offer_ids[0]
	assert_true(
		slice.shop_session.purchase(bought, slice.shop_session.deck_ids[0]).accepted,
		"failure fixture should buy one card"
	)
	assert_true(slice.leave_shop().accepted, "failure fixture should leave shop")
	var boundary_deck := slice.deck_ids.duplicate()
	var boundary_tickets := slice.intel_tickets
	assert_true(slice.start_dealer().accepted, "failure fixture dealer should start")
	var first := _capture_and_commit_three_rounds(slice)
	assert_equal(slice.phase, IronAbacusSliceSession.Phase.FAILED, "high target should fail")
	assert_equal(
		slice.failure_origin,
		IronAbacusSliceSession.Phase.DEALER,
		"failure should remember dealer origin"
	)
	assert_true(slice.retry_dealer().accepted, "dealer failure should retry from boundary")
	var replay := _capture_and_commit_three_rounds(slice)
	assert_equal(replay.hands, first.hands, "dealer retry should replay hands")
	assert_equal(replay.dice, first.dice, "dealer retry should replay eighteen dice")
	assert_equal(slice.deck_ids, boundary_deck, "dealer retry should preserve purchased deck")
	assert_equal(slice.intel_tickets, boundary_tickets, "dealer retry should preserve tickets")

func _test_same_seed_replays_full_random_state() -> void:
	var first := _drive_to_verification(20260801)
	var second := _drive_to_verification(20260801)
	assert_equal(
		first.engraving_offer_ids,
		second.engraving_offer_ids,
		"same seed should replay engraving offer order"
	)
	assert_equal(
		_hand_ids(first.verification_session),
		_hand_ids(second.verification_session),
		"same seed should replay verification hand"
	)
	assert_equal(
		_rolled_values(first.verification_session),
		_rolled_values(second.verification_session),
		"same seed should replay forced and non-forced verification dice"
	)

func _drive_to_verification(seed_value: int) -> IronAbacusSliceSession:
	var slice := IronAbacusSliceSession.new(seed_value, 0, 0)
	assert_true(slice.start().accepted, "verification fixture should start")
	_commit_three_empty_rounds(slice)
	assert_true(slice.open_shop().accepted, "verification fixture should open shop")
	assert_true(slice.leave_shop().accepted, "verification fixture should leave shop")
	assert_true(slice.start_dealer().accepted, "verification fixture should start dealer")
	_commit_three_empty_rounds(slice)
	var choice := _verifiable_offer(slice)
	assert_true(slice.select_engraving(choice.id).accepted, "fixture offer should select")
	assert_true(
		slice.install_selected_engraving(&"d1", choice.face).accepted,
		"fixture engraving should install"
	)
	return slice

func _commit_three_empty_rounds(slice: IronAbacusSliceSession) -> Array[ResolutionReport]:
	var reports: Array[ResolutionReport] = []
	for round_index in range(ThreeRoundEncounterSession.ROUND_COUNT):
		var report := slice.encounter_session.current_session.commit()
		reports.append(report)
		assert_true(
			slice.accept_encounter_report(report).accepted,
			"current committed report should be accepted"
		)
		if round_index < ThreeRoundEncounterSession.ROUND_COUNT - 1:
			assert_true(
				slice.advance_encounter_round().accepted,
				"summary should advance to the next round"
			)
	return reports

func _capture_and_commit_three_rounds(slice: IronAbacusSliceSession) -> Dictionary:
	var hands: Array = []
	var dice: Array = []
	for round_index in range(ThreeRoundEncounterSession.ROUND_COUNT):
		hands.append(slice.encounter_session.current_hand_ids.duplicate())
		dice.append(_rolled_values(slice.encounter_session.current_session))
		var report := slice.encounter_session.current_session.commit()
		assert_true(slice.accept_encounter_report(report).accepted, "dealer report should accept")
		if round_index < ThreeRoundEncounterSession.ROUND_COUNT - 1:
			assert_true(slice.advance_encounter_round().accepted, "dealer round should advance")
	return {"hands": hands, "dice": dice}

func _verifiable_offer(slice: IronAbacusSliceSession) -> Dictionary:
	if &"engraving_prism" in slice.engraving_offer_ids:
		return {"id": &"engraving_prism", "face": 1}
	assert_true(
		&"engraving_anchor" in slice.engraving_offer_ids,
		"every three-of-four offer set must contain prism or anchor"
	)
	return {"id": &"engraving_anchor", "face": 2}

func _profile_signature(profiles: Array[DieState]) -> Array:
	var signature: Array = []
	for profile in profiles:
		signature.append([profile.id, profile.engraving_id, profile.engraved_face])
	return signature

func _hand_ids(session: SingleEncounterSession) -> Array[StringName]:
	var ids: Array[StringName] = []
	for card in session.hand:
		ids.append(card.id)
	return ids

func _rolled_values(session: SingleEncounterSession) -> Array[int]:
	var values: Array[int] = []
	for die in session.controller.state.dice:
		values.append(die.rolled_value)
	return values
