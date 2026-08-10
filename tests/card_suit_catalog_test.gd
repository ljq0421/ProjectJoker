extends "res://tests/test_case.gd"

const EXPECTED_SUIT_COUNTS := {
	CardDefinition.Suit.CLUBS: 12,
	CardDefinition.Suit.HEARTS: 5,
	CardDefinition.Suit.DIAMONDS: 10,
	CardDefinition.Suit.SPADES: 19,
}

func run() -> void:
	var catalog := CardCatalog.new()
	var suit_counts := {
		CardDefinition.Suit.CLUBS: 0,
		CardDefinition.Suit.HEARTS: 0,
		CardDefinition.Suit.DIAMONDS: 0,
		CardDefinition.Suit.SPADES: 0,
	}
	for card in catalog.all_cards():
		assert_true(
			suit_counts.has(card.suit),
			"%s should use a known suit" % card.id
		)
		if suit_counts.has(card.suit):
			suit_counts[card.suit] += 1
		assert_false(
			card.rank_label.strip_edges().is_empty(),
			"%s should expose a rank label" % card.id
		)
		assert_true(
			card.rarity in [
				CardDefinition.Rarity.COMMON,
				CardDefinition.Rarity.UNCOMMON,
				CardDefinition.Rarity.RARE,
			],
			"%s should use a known rarity" % card.id
		)
		_assert_card_copy(card)

	for suit in EXPECTED_SUIT_COUNTS:
		assert_equal(
			suit_counts[suit],
			EXPECTED_SUIT_COUNTS[suit],
			"suit %s should contain the audited card count"
			% CardDefinition.suit_copy_for(suit)
		)
		assert_equal(
			catalog.cards_for_suit(suit).size(),
			EXPECTED_SUIT_COUNTS[suit],
			"catalog suit query should match metadata audit"
		)

func _assert_card_copy(card: CardDefinition) -> void:
	var token := CardToken.new()
	token.bind_card(0, card, false, false)
	assert_true(
		card.suit_copy() in token.text,
		"%s token should show its suit" % card.id
	)
	assert_true(
		card.rank_label in token.text,
		"%s token should show its rank" % card.id
	)
	var target_copy := token.target_copy_for(card)
	assert_true(
		target_copy in token.text,
		"%s token should show its target type" % card.id
	)
	assert_true(
		card.suit_copy() in token.tooltip_text,
		"%s tooltip should expose its suit without relying on color" % card.id
	)
	token.free()
