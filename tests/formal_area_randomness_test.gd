extends "res://tests/test_case.gd"

const SEED := 20260805
const ModifierCatalog = preload("res://scripts/run/area_run_modifier_catalog.gd")
const DieStateScript = preload("res://scripts/run/die_state.gd")
const RoundStateScript = preload("res://scripts/run/round_state.gd")
const RuleDefinitionScript = preload("res://scripts/rules/rule_definition.gd")
const EncounterDefinitionScript = preload("res://scripts/resolution/encounter_definition.gd")
const RoundResolverScript = preload("res://scripts/resolution/round_resolver.gd")
const ResolutionContextScript = preload("res://scripts/resolution/resolution_context.gd")
const RestrictionScript = preload("res://scripts/run/final_restriction_definition.gd")
const RestrictionEvaluatorScript = preload("res://scripts/run/round_restriction_evaluator.gd")
const CardDefinitionScript = preload("res://scripts/cards/card_definition.gd")
const EffectSpecScript = preload("res://scripts/cards/effect_spec.gd")
const PlayedCardScript = preload("res://scripts/cards/played_card.gd")
const MirrorCopyResolverScript = preload("res://scripts/cards/mirror_copy_resolver.gd")
const CardRulesScript = preload("res://scripts/cards/card_rules.gd")

func run() -> void:
	_test_area_modifier_pools_are_regional()
	_test_same_seed_replays_lucky_faces_and_modifier()
	_test_checkpoint_restores_random_contract()
	_test_legacy_checkpoint_migrates_random_contract()
	_test_formal_context_reaches_normal_room()
	_test_lucky_faces_carry_between_areas()
	_test_lucky_critical_changes_formal_score()
	_test_full_table_critical_doubles_table_total()
	_test_gold_mutation_changes_formal_score()
	_test_gold_pair_and_extreme_mutations_score()
	_test_mirror_twin_echo_uses_full_effect()
	_test_mirror_direction_mutation_changes_order()
	_test_mirror_overflow_transfers_score()
	_test_faceless_rule_veil_relaxes_coverage()
	_test_faceless_open_hand_relaxes_card_limit()
	_test_shared_screen_exposes_random_contract()
	_test_area_modifier_reveal_contract()

func _test_area_modifier_pools_are_regional() -> void:
	var catalog := ModifierCatalog.new()
	var gold := catalog.ids_for_area(&"gold_corridor")
	var mirror := catalog.ids_for_area(&"mirror_hall")
	var faceless := catalog.ids_for_area(&"faceless_hub")
	assert_equal(gold.size(), 3, "Gold Corridor should own three score mutations")
	assert_equal(mirror.size(), 3, "Mirror Hall should own three mirror mutations")
	assert_equal(faceless.size(), 2, "Faceless Hub should own two rule mutations")
	for modifier_id in gold:
		assert_false(modifier_id in mirror, "Gold mutations must not leak into Mirror Hall")
		assert_false(modifier_id in faceless, "Gold mutations must not leak into Faceless Hub")

func _test_same_seed_replays_lucky_faces_and_modifier() -> void:
	var first := AreaRunSession.new(SEED, AreaCatalog.new().gold_corridor())
	var second := AreaRunSession.new(SEED, AreaCatalog.new().gold_corridor())
	assert_true(first.start().accepted, "first formal area should start")
	assert_true(second.start().accepted, "second formal area should start")
	assert_equal(first.lucky_faces, second.lucky_faces, "lucky faces should replay by seed")
	assert_equal(first.area_modifier_id, second.area_modifier_id, "area mutation should replay")
	assert_equal(first.lucky_faces.size(), 6, "all six formal dice should own a lucky face")
	for die_index in range(1, 7):
		var face: int = first.lucky_faces.get(StringName("d%d" % die_index), 0)
		assert_true(face >= 1 and face <= 6, "each lucky face should be a valid d6 face")

func _test_checkpoint_restores_random_contract() -> void:
	var original := AreaRunSession.new(SEED, AreaCatalog.new().mirror_hall())
	assert_true(original.start().accepted, "mirror fixture should start")
	var restored := AreaRunSession.new(SEED, AreaCatalog.new().mirror_hall())
	assert_true(
		restored.restore_checkpoint(original.checkpoint_snapshot()).accepted,
		"formal checkpoint should restore"
	)
	assert_equal(restored.lucky_faces, original.lucky_faces, "checkpoint keeps lucky faces")
	assert_equal(restored.area_modifier_id, original.area_modifier_id, "checkpoint keeps mutation")
	assert_equal(
		restored.run_rng.snapshot_state(),
		original.run_rng.snapshot_state(),
		"restoring the contract must not consume extra RNG"
	)

func _test_legacy_checkpoint_migrates_random_contract() -> void:
	var original := AreaRunSession.new(SEED, AreaCatalog.new().gold_corridor())
	assert_true(original.start().accepted, "legacy fixture should start")
	var legacy := original.checkpoint_snapshot()
	legacy.erase("lucky_faces")
	legacy.erase("area_modifier_id")
	var restored := AreaRunSession.new(SEED, AreaCatalog.new().gold_corridor())
	assert_true(restored.restore_checkpoint(legacy).accepted, "legacy checkpoint should migrate")
	assert_equal(restored.lucky_faces.size(), 6, "migration should generate six lucky faces")
	assert_true(
		restored.area_modifier_id in ModifierCatalog.new().ids_for_area(&"gold_corridor"),
		"migration should generate a valid Gold mutation"
	)

func _test_formal_context_reaches_normal_room() -> void:
	var area := AreaRunSession.new(SEED, AreaCatalog.new().faceless_hub())
	assert_true(area.start().accepted, "faceless fixture should start")
	assert_true(area.select_route(area.current_route_ids()[0]).accepted, "route should select")
	var context := area.encounter_session.setup.resolution_context
	assert_equal(context.area_modifier_id, area.area_modifier_id, "room receives area mutation")
	assert_equal(context.lucky_faces, area.lucky_faces, "room receives formal lucky faces")

func _test_lucky_faces_carry_between_areas() -> void:
	var gold := AreaRunSession.new(SEED, AreaCatalog.new().gold_corridor())
	assert_true(gold.start().accepted, "gold fixture should start")
	var mirror := AreaRunSession.new(SEED, AreaCatalog.new().mirror_hall())
	assert_true(mirror.configure_entry_state({
		"deck_ids": AreaCatalog.new().mirror_hall().starting_deck_ids,
		"intel_tickets": 5,
		"die_profiles": gold._profile_snapshots(),
		"rng_state": gold.run_rng.snapshot_state(),
		"lucky_faces": gold.lucky_faces.duplicate(true),
	}).accepted, "cross-area state should accept lucky faces")
	assert_true(mirror.start().accepted, "mirror should start from inherited state")
	assert_equal(mirror.lucky_faces, gold.lucky_faces, "lucky faces persist across regions")
	assert_true(
		mirror.area_modifier_id in ModifierCatalog.new().ids_for_area(&"mirror_hall"),
		"Mirror Hall still rolls its own regional mutation"
	)

func _test_lucky_critical_changes_formal_score() -> void:
	var state := _state([1, 6])
	var encounter := _encounter(2, 7)
	var context := ResolutionContextScript.new(null, null, &"", {
		&"d1": 1,
		&"d2": 6,
	})
	var report := RoundResolverScript.new().resolve(state, encounter, context)
	assert_equal(report.total, 21, "two lucky dice should add 50 percent contribution")
	assert_true(
		report.events.any(func(event) -> bool: return event.source_id == &"lucky_critical"),
		"critical scoring should create a visible resolution event"
	)

func _test_full_table_critical_doubles_table_total() -> void:
	var state := _state([1, 2, 3])
	var encounter := _encounter(2, 6)
	var context := ResolutionContextScript.new(null, null, &"", {
		&"d1": 1,
		&"d2": 2,
		&"d3": 3,
	})
	var report := RoundResolverScript.new().resolve(state, encounter, context)
	assert_equal(report.total, 36, "three critical dice should double base plus critical score")
	assert_true(
		report.events.any(func(event) -> bool: return event.source_id == &"full_table_critical"),
		"full-table critical should create a visible resolution event"
	)

func _test_gold_mutation_changes_formal_score() -> void:
	var state := _state([1, 2, 3])
	var encounter := _encounter(1, 6)
	var context := ResolutionContextScript.new(
		null,
		null,
		ModifierCatalog.GOLD_STRAIGHT_GIFT
	)
	var report := RoundResolverScript.new().resolve(state, encounter, context)
	assert_equal(report.total, 18, "Gold straight gift should add twelve formal points")
	assert_true(
		report.events.any(
			func(event) -> bool: return event.source_id == ModifierCatalog.GOLD_STRAIGHT_GIFT
		),
		"Gold mutation should be visible in resolution playback"
	)

func _test_gold_pair_and_extreme_mutations_score() -> void:
	var pair_report := RoundResolverScript.new().resolve(
		_state([2, 2]),
		_encounter(1, 4),
		ResolutionContextScript.new(
			null,
			null,
			ModifierCatalog.GOLD_SAME_RADIANCE
		)
	)
	assert_equal(pair_report.total, 8, "Gold pair mutation should add four points per pair")
	var extreme_report := RoundResolverScript.new().resolve(
		_state([5]),
		_encounter(1, 5, 1),
		ResolutionContextScript.new(
			null,
			null,
			ModifierCatalog.GOLD_EXTREME_GIFT
		)
	)
	assert_equal(extreme_report.total, 15, "Gold extreme mutation should triple max die score")

func _test_mirror_twin_echo_uses_full_effect() -> void:
	var original_effect := EffectSpecScript.new()
	original_effect.operation = EffectSpecScript.Operation.MODIFY_COEFFICIENT
	original_effect.amount = 2
	var mirror_effect := EffectSpecScript.new()
	mirror_effect.operation = EffectSpecScript.Operation.MODIFY_COEFFICIENT
	mirror_effect.amount = 1
	var card := CardDefinitionScript.new()
	card.id = &"full_echo_fixture"
	card.display_name = "完整回响"
	card.target_type = CardDefinitionScript.TargetType.GAP
	card.effects = [original_effect]
	card.mirror_effects = [mirror_effect]
	var played := PlayedCardScript.new(card, &"left", &"middle")
	var encounter := EncounterDefinitionScript.new()
	var profile := EncounterRuleProfile.new()
	profile.mirror_first_table_card = true
	profile.mirror_limit_per_round = 1
	encounter.rule_profile = profile
	var context := ResolutionContextScript.new(
		null,
		null,
		ModifierCatalog.MIRROR_TWIN_ECHO
	)
	var result := MirrorCopyResolverScript.new().resolve(
		played,
		RoundStateScript.new(),
		encounter,
		context
	)
	assert_true(result.generated, "Mirror mutation fixture should generate a copy")
	assert_equal(
		result.copy.runtime_effects[0].amount,
		2,
		"twin echo should use the original full-strength amount"
	)

func _test_mirror_direction_mutation_changes_order() -> void:
	var state := _state([1, 2, 3])
	var encounter := _encounter(1, 6)
	var context := ResolutionContextScript.new(
		null,
		null,
		ModifierCatalog.MIRROR_REVERSED_FLOW
	)
	var report := RoundResolverScript.new().resolve(state, encounter, context)
	assert_equal(
		report.resolution_direction,
		EncounterRuleProfile.ResolutionDirection.RIGHT_TO_LEFT,
		"Mirror mutation should flip the initial formal direction"
	)

func _test_mirror_overflow_transfers_score() -> void:
	var state := RoundStateScript.new()
	for value in range(1, 4):
		var die_id := StringName("d%d" % value)
		state.dice.append(DieStateScript.new(die_id, value))
		state.assignments[StringName("table_%d" % value)] = [die_id]
	var encounter := EncounterDefinitionScript.new()
	for value in range(1, 4):
		encounter.rules.append(_rule(
			StringName("table_%d" % value),
			value,
			1
		))
	var report := RoundResolverScript.new().resolve(
		state,
		encounter,
		ResolutionContextScript.new(
			null,
			null,
			ModifierCatalog.MIRROR_OVERFLOW_TRANSFER
		)
	)
	assert_equal(report.total, 7, "Mirror overflow should repeat the lowest passed table")

func _test_faceless_rule_veil_relaxes_coverage() -> void:
	var state := RoundStateScript.new()
	state.assignments = {&"left": [&"d1"], &"middle": [&"d2"]}
	var encounter := EncounterDefinitionScript.new()
	encounter.rules = [
		_rule(&"left", 1, 1),
		_rule(&"middle", 1, 1),
		_rule(&"right", 1, 1),
	]
	var restriction := RestrictionScript.new()
	restriction.id = &"all_tables"
	restriction.display_name = "全台留痕"
	restriction.rule_text = "三张规则台均须有骰子"
	restriction.category = RestrictionScript.Category.DISTRIBUTION
	restriction.operation = RestrictionScript.Operation.REQUIRE_ALL_TABLES_OCCUPIED
	restriction.amount = 3
	var context := ResolutionContextScript.new(
		null,
		null,
		ModifierCatalog.FACELESS_RULE_VEIL
	)
	assert_true(
		RestrictionEvaluatorScript.new().evaluate_commit(
			state,
			encounter,
			restriction,
			context
		).accepted,
		"Faceless rule veil should allow exactly one empty table"
	)

func _test_faceless_open_hand_relaxes_card_limit() -> void:
	var state := RoundStateScript.new()
	for index in range(2):
		var card := CardDefinitionScript.new()
		card.id = StringName("card_%d" % index)
		state.played_cards.append(PlayedCardScript.new(card))
	var restriction := RestrictionScript.new()
	restriction.id = &"card_limit"
	restriction.display_name = "单手裁定"
	restriction.rule_text = "最多两张真实牌"
	restriction.category = RestrictionScript.Category.OPERATION
	restriction.operation = RestrictionScript.Operation.MAX_REAL_CARDS
	restriction.amount = 2
	var context := ResolutionContextScript.new(
		null,
		null,
		ModifierCatalog.FACELESS_OPEN_HAND
	)
	var restriction_result := RestrictionEvaluatorScript.new().validate_card_play(
		state,
		restriction,
		context
	)
	assert_true(restriction_result.accepted, "Faceless restriction should permit a third card")
	assert_true(
		CardRulesScript.validate_card_start(state, context).accepted,
		"the shared formal card cap should also permit the third card"
	)

func _test_shared_screen_exposes_random_contract() -> void:
	var packed := load("res://scenes/run/area_run_screen.tscn") as PackedScene
	var screen := packed.instantiate()
	assert_true(
		screen.get_node_or_null("NavigationBar/ChromeRow/RandomContractLabel") != null,
		"all three formal area screens should inherit the visible random contract"
	)
	screen.free()

func _test_area_modifier_reveal_contract() -> void:
	var packed := load("res://scenes/components/narrative_card.tscn") as PackedScene
	var reveal := packed.instantiate()
	assert_true(
		reveal.has_method("show_area_modifier_reveal"),
		"shared narrative overlay should reveal the random regional mutation"
	)
	reveal.free()

func _state(values: Array[int]) -> RoundState:
	var state := RoundStateScript.new()
	var assigned: Array[StringName] = []
	for index in range(values.size()):
		var die_id := StringName("d%d" % (index + 1))
		state.dice.append(DieStateScript.new(die_id, values[index]))
		assigned.append(die_id)
	state.assignments = {&"left": assigned}
	return state

func _encounter(
	coefficient: int,
	target: int,
	slot_count: int = -1
) -> EncounterDefinition:
	var encounter := EncounterDefinitionScript.new()
	encounter.id = &"randomness_contract"
	encounter.rules = [
		_rule(&"left", target, coefficient, slot_count),
	]
	return encounter

func _rule(
	id: StringName,
	target: int,
	coefficient: int,
	slot_count: int = -1
) -> RuleDefinition:
	var rule := RuleDefinitionScript.new()
	rule.id = id
	rule.display_name = String(id)
	rule.condition_type = RuleDefinitionScript.ConditionType.EXACT_SUM
	rule.slot_count = (
		slot_count
		if slot_count > 0
		else 1 if target in [1, 2, 3] else 3 if target == 6 else 2
	)
	rule.coefficient = coefficient
	rule.target_value = target
	return rule
