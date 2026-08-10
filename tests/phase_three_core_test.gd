extends "res://tests/test_case.gd"

const PASSIVE_PATH := "res://scripts/run/area_passive_state.gd"
const SUIT_RULES_PATH := "res://scripts/cards/card_suit_rules.gd"
const SET_RESOLVER_PATH := "res://scripts/engravings/engraving_set_resolver.gd"

func run() -> void:
	assert_true(
		ResourceLoader.exists(PASSIVE_PATH),
		"phase three should expose persisted area passive state"
	)
	assert_true(
		ResourceLoader.exists(SUIT_RULES_PATH),
		"phase three should expose suit and rank conversion rules"
	)
	assert_true(
		ResourceLoader.exists(SET_RESOLVER_PATH),
		"phase three should expose engraving family set resolution"
	)
	_assert_extreme_card_catalog_contract()

func _assert_extreme_card_catalog_contract() -> void:
	var catalog := CardCatalog.new()
	for card_id in [
		&"stage7_fault_die",
		&"stage7_all_in",
		&"stage7_insurance_draft",
		&"stage7_burned_rewrite",
	]:
		assert_true(
			catalog.find_card(card_id) != null,
			"stage three card catalog should contain %s" % card_id
		)
