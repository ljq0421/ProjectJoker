extends "res://tests/test_case.gd"

func run() -> void:
	_test_two_events_are_non_repeating_and_checkpointed()
	_test_dice_artisan_changes_lucky_face()
	_test_mystery_gamble_exposes_real_disable_reasons()

func _test_two_events_are_non_repeating_and_checkpointed() -> void:
	var area := _new_area()
	assert_true(area._prepare_random_event().accepted, "first event should draw")
	var first_id := area.current_event_id
	_resolve_safe(area)
	assert_true(area._prepare_random_event().accepted, "second event should draw")
	assert_true(area.current_event_id != first_id, "area events should not repeat")
	var checkpoint := area.checkpoint_snapshot()
	assert_equal(checkpoint["event_history"].size(), 1, "resolved choice should checkpoint")
	assert_equal(checkpoint["current_event_id"], area.current_event_id, "pending event checkpoints")

func _test_dice_artisan_changes_lucky_face() -> void:
	var area := _new_area()
	area.phase = AreaRunSession.Phase.EVENT
	area.current_event_id = AreaRunSession.EVENT_DICE_ARTISAN
	var old_face: int = area.lucky_faces[&"d1"]
	assert_true(area.resolve_event(&"reroll", &"d1").accepted, "artisan should resolve")
	assert_true(area.lucky_faces[&"d1"] != old_face, "artisan must choose a different face")

func _test_mystery_gamble_exposes_real_disable_reasons() -> void:
	var area := _new_area()
	area.phase = AreaRunSession.Phase.EVENT
	area.current_event_id = AreaRunSession.EVENT_MYSTERY_GAMBLE
	area.intel_tickets = 1
	assert_true(
		"情报不足" in area.event_choice_block_reason(&"rare_card"),
		"rare choice should explain insufficient intel"
	)
	area.intel_tickets = 9
	while area.deck_ids.size() < CardDeck.MAX_DECK_SIZE:
		for card_id in area.market_ids:
			if card_id not in area.deck_ids:
				area.deck_ids.append(card_id)
				break
	assert_true(
		"牌组已满" in area.event_choice_block_reason(&"rare_card"),
		"rare choice should explain full deck"
	)

func _resolve_safe(area: AreaRunSession) -> void:
	match area.current_event_id:
		AreaRunSession.EVENT_DICE_ARTISAN:
			area.resolve_event(&"reroll", &"d1")
		AreaRunSession.EVENT_REST_STOP:
			area.resolve_event(&"rest")
		_:
			area.resolve_event(&"intel")

func _new_area() -> AreaRunSession:
	var area := AreaRunSession.new(9327, AreaCatalog.new().gold_corridor())
	assert_true(area.start().accepted, "event fixture area should start")
	return area
