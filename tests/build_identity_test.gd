extends "res://tests/test_case.gd"

const BuildIdentities = preload("res://scripts/run/build_identity_catalog.gd")

func run() -> void:
	var identities := BuildIdentities.new()
	var cards := CardCatalog.new()
	assert_equal(
		identities.all_ids(),
		[
			&"dice_control",
			&"table_chain",
			&"intel_economy",
		],
		"three build identities should be stable"
	)
	var card_counts := {
		&"dice_control": 0,
		&"table_chain": 0,
		&"intel_economy": 0,
	}
	for card in cards.all_cards():
		var identity_id := identities.identity_for_card(card)
		assert_true(
			identity_id in identities.all_ids(),
			"%s should have a primary build identity" % card.id
		)
		card_counts[identity_id] += 1
	for identity_id in identities.all_ids():
		assert_true(
			card_counts[identity_id] >= 3,
			"%s should have at least three formal cards" % identity_id
		)

	var room_counts := {
		&"dice_control": 0,
		&"table_chain": 0,
		&"intel_economy": 0,
	}
	for area in AreaCatalog.new().all_areas():
		for room in area.rooms:
			assert_true(
				room.build_identity_id in identities.all_ids(),
				"%s should expose a build identity" % room.id
			)
			room_counts[room.build_identity_id] += 1
	for identity_id in identities.all_ids():
		assert_true(
			room_counts[identity_id] >= 2,
			"%s should have at least two formal rooms" % identity_id
		)

	var deck_counts := identities.deck_counts(
		AreaCatalog.new().faceless_hub().starting_deck_ids,
		cards
	)
	var total := 0
	for identity_id in identities.all_ids():
		total += deck_counts[identity_id]
	assert_equal(total, 12, "every deck card should count toward one identity")
	assert_true(
		identities.route_identity_copy(&"dice_control", deck_counts).contains("骰值控制"),
		"route identity copy should include the identity name"
	)
