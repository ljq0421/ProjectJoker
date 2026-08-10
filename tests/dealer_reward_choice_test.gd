extends "res://tests/test_case.gd"

func run() -> void:
	_test_rare_card_reward_replaces_one_card()
	_test_engraving_remains_available_when_rare_pool_is_owned()
	_test_reward_offers_restore_without_rerolling()
	_test_engraving_path_still_completes()
	_test_reward_checkpoint_restores_exact_dealer_summary()
	_test_legacy_engraving_checkpoint_preserves_progress()
	_test_legacy_card_checkpoint_preserves_progress()
	_test_legacy_checkpoint_uses_challenge_target()
	_test_legacy_expedition_snapshot_restores()
	_test_complete_checkpoint_recovers_embedded_summary()
	_test_malformed_dealer_summary_rejects_atomically()

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
	assert_equal(session.deck_ids.size(), 13, "card path appends while below the cap")
	assert_true(replaced_id in session.deck_ids, "replacement is ignored below the cap")
	assert_true(reward_id in session.deck_ids, "rare reward enters the deck")
	var unique: Dictionary = {}
	for card_id in session.deck_ids:
		unique[card_id] = true
	assert_equal(unique.size(), 13, "rewarded deck remains unique")
	var summary := session.completion_snapshot()
	assert_equal(summary.reward_kind, &"rare_card", "summary records card reward")
	assert_equal(summary.reward_card_id, reward_id, "summary records rare card")
	assert_equal(summary.replaced_card_id, &"", "summary records no replacement below cap")

func _test_engraving_remains_available_when_rare_pool_is_owned() -> void:
	var session := AreaRunSession.new(202607311, AreaCatalog.new().gold_corridor())
	assert_true(session.start().accepted, "owned-rare fixture should start")
	for card_id in session.area_definition.rare_reward_card_ids:
		if card_id not in session.deck_ids:
			session.deck_ids.append(card_id)
	session.encounter_session = ThreeRoundEncounterSession.new(
		session.card_catalog,
		202607311,
		session.area_definition.dealer_target
	)
	session.encounter_session.cumulative_total = session.area_definition.dealer_target
	session.phase = AreaRunSession.Phase.DEALER
	assert_true(
		session._prepare_dealer_rewards().accepted,
		"owned rare pool must not block the engraving path"
	)
	assert_equal(session.rare_card_offer_ids.size(), 0, "owned rare pool offers no card")
	assert_equal(session.engraving_offer_ids.size(), 2, "engraving choice remains available")

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

func _test_reward_checkpoint_restores_exact_dealer_summary() -> void:
	var original := _prepared_reward_session(20260734)
	var restored := AreaRunSession.new(
		20260734,
		original.area_definition
	)
	assert_true(
		restored.restore_checkpoint(original.checkpoint_snapshot()).accepted,
		"new reward checkpoint should restore"
	)
	assert_equal(
		restored.dealer_summary,
		original.dealer_summary,
		"new reward checkpoint should retain the exact dealer result"
	)
	assert_true(
		restored.dealer_summary["cumulative_total"]
			> restored.dealer_summary["target_total"],
		"exact restored dealer result should retain the achieved score"
	)

func _test_legacy_engraving_checkpoint_preserves_progress() -> void:
	var original := _prepared_reward_session(20260735)
	var engraving_id: StringName = original.engraving_offer_ids[0]
	assert_true(original.select_engraving(engraving_id).accepted, "select legacy engraving")
	var legacy := original.checkpoint_snapshot()
	legacy.erase("dealer_summary")
	var restored := AreaRunSession.new(20260735, original.area_definition)
	assert_true(restored.restore_checkpoint(legacy).accepted, "legacy engraving checkpoint restores")
	assert_true(restored.encounter_session == null, "reward restore should not recreate encounter")
	assert_equal(
		restored.selected_engraving_id,
		engraving_id,
		"legacy restore should preserve selected engraving"
	)
	assert_true(
		restored.install_selected_engraving(&"d1", 2).accepted,
		"legacy restored engraving should install"
	)
	var completion := restored.completion_snapshot()
	assert_equal(completion["dealer"]["cumulative_total"], null, "legacy score is unknown")
	assert_equal(
		completion["dealer"]["target_total"],
		original.area_definition.dealer_target,
		"legacy completion should retain the real dealer target"
	)

func _test_legacy_card_checkpoint_preserves_progress() -> void:
	var original := _prepared_reward_session(20260736)
	var reward_id: StringName = original.rare_card_offer_ids[0]
	var replaced_id: StringName = original.deck_ids[0]
	assert_true(original.select_rare_card_reward(reward_id).accepted, "select legacy card")
	assert_true(original.select_reward_replacement(replaced_id).accepted, "select legacy replacement")
	var legacy := original.checkpoint_snapshot()
	legacy.erase("dealer_summary")
	var restored := AreaRunSession.new(20260736, original.area_definition)
	assert_true(restored.restore_checkpoint(legacy).accepted, "legacy card checkpoint restores")
	assert_true(
		restored.claim_rare_card_reward(reward_id, replaced_id).accepted,
		"legacy restored rare card should complete"
	)
	assert_equal(
		restored.completion_snapshot()["dealer"]["cumulative_total"],
		null,
		"legacy card completion should mark the dealer score unknown"
	)

func _test_legacy_checkpoint_uses_challenge_target() -> void:
	var original := _prepared_reward_session(20260737, [&"high_pressure"])
	var legacy := original.checkpoint_snapshot()
	legacy.erase("dealer_summary")
	var restored := AreaRunSession.new(20260737, original.area_definition)
	assert_true(restored.restore_checkpoint(legacy).accepted, "challenged legacy checkpoint restores")
	assert_equal(
		restored.dealer_summary["target_total"],
		int(ceili(float(original.area_definition.dealer_target) * 1.15)),
		"legacy migration should reapply the high-pressure target"
	)

func _test_legacy_expedition_snapshot_restores() -> void:
	var seed := 20260740
	var area := _prepared_reward_session(seed)
	area.select_engraving(area.engraving_offer_ids[0])
	var legacy_checkpoint := area.checkpoint_snapshot()
	legacy_checkpoint.erase("dealer_summary")
	var original_expedition := ExpeditionSession.new()
	assert_true(original_expedition.start_new(seed).accepted, "legacy expedition fixture starts")
	var legacy_snapshot := original_expedition.to_snapshot()
	legacy_snapshot["area_checkpoint"] = legacy_checkpoint
	var restored_expedition := ExpeditionSession.new()
	assert_true(
		restored_expedition.restore_snapshot(legacy_snapshot).accepted,
		"outer expedition restore should accept a legacy reward checkpoint"
	)
	assert_equal(
		restored_expedition.area_checkpoint["selected_engraving_id"],
		area.selected_engraving_id,
		"outer expedition restore should preserve the legacy reward choice"
	)

func _test_complete_checkpoint_recovers_embedded_summary() -> void:
	var original := _prepared_reward_session(20260738)
	var engraving_id: StringName = original.engraving_offer_ids[0]
	original.select_engraving(engraving_id)
	original.install_selected_engraving(&"d1", 2)
	var exact_completion := original.completion_snapshot()
	var legacy := original.checkpoint_snapshot()
	legacy.erase("dealer_summary")
	legacy["completion"] = exact_completion.duplicate(true)
	var restored := AreaRunSession.new(20260738, original.area_definition)
	assert_true(restored.restore_checkpoint(legacy).accepted, "complete legacy checkpoint restores")
	assert_equal(
		restored.dealer_summary,
		exact_completion["dealer"],
		"complete checkpoint should recover its embedded exact dealer result"
	)

func _test_malformed_dealer_summary_rejects_atomically() -> void:
	var session := _prepared_reward_session(20260739)
	var before := session.checkpoint_snapshot()
	var malformed := before.duplicate(true)
	malformed["dealer_summary"]["cumulative_total"] = "unknown"
	assert_false(session.restore_checkpoint(malformed).accepted, "malformed dealer summary rejects")
	assert_equal(
		session.checkpoint_snapshot(),
		before,
		"rejected dealer summary restore should leave the session unchanged"
	)

func _prepared_reward_session(
	seed_value: int,
	challenge_ids: Array[StringName] = []
) -> AreaRunSession:
	var session := AreaRunSession.new(
		seed_value,
		AreaCatalog.new().gold_corridor()
	)
	assert_true(
		session.configure_challenges(challenge_ids).accepted,
		"reward fixture challenges should configure"
	)
	assert_true(session.start().accepted, "reward fixture area should start")
	var target_total := int(ceili(
		float(session.area_definition.dealer_target)
		* (1.15 if &"high_pressure" in challenge_ids else 1.0)
	))
	session.encounter_session = ThreeRoundEncounterSession.new(
		session.card_catalog,
		seed_value,
		target_total
	)
	session.encounter_session.cumulative_total = target_total + 17
	session.phase = AreaRunSession.Phase.DEALER
	assert_true(
		session._prepare_dealer_rewards().accepted,
		"dealer rewards should prepare"
	)
	return session
