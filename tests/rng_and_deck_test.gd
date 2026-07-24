extends "res://tests/test_case.gd"

const RunRngScript = preload("res://scripts/run/run_rng.gd")
const CardDeckScript = preload("res://scripts/run/card_deck.gd")

func run() -> void:
	var first_rng := RunRngScript.new(20260724)
	var second_rng := RunRngScript.new(20260724)
	var first_rolls: Array[int] = []
	var second_rolls: Array[int] = []
	for index in range(6):
		first_rolls.append(first_rng.roll_die())
		second_rolls.append(second_rng.roll_die())
	assert_equal(first_rolls, second_rolls, "equal seeds should produce equal dice")

	var ids: Array[StringName] = []
	for index in range(12):
		ids.append(StringName("card_%02d" % index))
	var deck := CardDeckScript.new()
	deck.start_encounter(ids, RunRngScript.new(99))
	var seen: Array[StringName] = []
	for round_index in range(3):
		var hand := deck.draw_round()
		assert_equal(hand.size(), 4, "each round should draw four cards")
		seen.append_array(hand)
	assert_equal(seen.size(), 12, "three rounds should expose twelve cards")
	var unique := {}
	for card_id in seen:
		unique[card_id] = true
	assert_equal(unique.size(), 12, "encounter hands must not repeat cards")
	assert_equal(deck.draw_round().size(), 0, "deck should be empty after three hands")
