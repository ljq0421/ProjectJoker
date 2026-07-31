extends "res://tests/test_case.gd"

func run() -> void:
	_test_rare_card_reward_replaces_one_card()
	_test_reward_offers_restore_without_rerolling()
	_test_engraving_path_still_completes()

func _test_rare_card_reward_replaces_one_card() -> void:
	var session := _prepared_reward_session(20260731)
	assert_equal(session.rare_card_offer_ids.size(), 1, "one rare card should be public")
	assert_equal(session.engraving_offer_ids.size(), 2, "two engravings should be public")
	var reward_id: StringName = session.rare_card_offer_ids[0]
	assert_equal(
		session.card_catalog.find_card(reward_id).rarity,
		CardDefinition.Rarity.RARE,
		"card reward should be rare"
	)
	assert_false(reward_id in session.deck_ids, "reward card should be outside the deck")
	var before := session.deck_ids.duplicate()
	var replaced_id: StringName = before[0]
	assert_true(
		session.claim_rare_card_reward(reward_id, replaced_id).accepted,
		"rare card replacement should complete"
	)
	assert_equal(session.phase, AreaRunSession.Phase.COMPLETE, "card path completes area")
	assert_equal(session.deck_ids.size(), 12, "card path keeps twelve cards")
	assert_false(replaced_id in session.deck_ids, "selected deck card is removed")
	assert_true(reward_id in session.deck_ids, "rare reward enters the deck")
	var unique: Dictionary = {}
	for card_id in session.deck_ids:
		unique[card_id] = true
	assert_equal(unique.size(), 12, "rewarded deck remains unique")
	var summary := session.completion_snapshot()
	assert_equal(summary.reward_kind, &"rare_card", "summary records card reward")
	assert_equal(summary.reward_card_id, reward_id, "summary records rare card")
	assert_equal(summary.replaced_card_id, replaced_id, "summary records replacement")

func _test_reward_offers_restore_without_rerolling() -> void:
	var original := _prepared_reward_session(20260732)
	assert_true(
		original.select_rare_card_reward(original.rare_card_offer_ids[0]).accepted,
		"rare selection should persist"
	)
	assert_true(
		original.select_reward_replacement(original.deck_ids[0]).accepted,
		"replacement selection should persist"
	)
	var snapshot := original.checkpoint_snapshot()
	var restored := AreaRunSession.new(
		20260732,
		original.area_definition
	)
	assert_true(restored.restore_checkpoint(snapshot).accepted, "reward checkpoint restores")
	assert_equal(
		restored.rare_card_offer_ids,
		original.rare_card_offer_ids,
		"rare card offer should not reroll"
	)
	assert_equal(
		restored.engraving_offer_ids,
		original.engraving_offer_ids,
		"engraving offers should not reroll"
	)
	assert_equal(
		restored.selected_reward_card_id,
		original.selected_reward_card_id,
		"rare selection should restore"
	)
	assert_equal(
		restored.replaced_reward_card_id,
		original.replaced_reward_card_id,
		"replacement selection should restore"
	)

func _test_engraving_path_still_completes() -> void:
	var session := _prepared_reward_session(20260733)
	var engraving_id: StringName = session.engraving_offer_ids[0]
	assert_true(session.select_engraving(engraving_id).accepted, "engraving can be selected")
	assert_true(
		session.install_selected_engraving(&"d1", 1).accepted,
		"engraving path should still complete"
	)
	assert_equal(session.phase, AreaRunSession.Phase.COMPLETE, "engraving path completes")
	assert_equal(
		session.completion_snapshot().reward_kind,
		&"engraving",
		"summary records engraving reward"
	)

func _prepared_reward_session(seed_value: int) -> AreaRunSession:
	var session := AreaRunSession.new(
		seed_value,
		AreaCatalog.new().gold_corridor()
	)
	assert_true(session.start().accepted, "reward fixture area should start")
	session.encounter_session = ThreeRoundEncounterSession.new(
		session.card_catalog,
		seed_value,
		session.area_definition.dealer_target
	)
	session.phase = AreaRunSession.Phase.DEALER
	assert_true(
		session._prepare_dealer_rewards().accepted,
		"dealer rewards should prepare"
	)
	return session
