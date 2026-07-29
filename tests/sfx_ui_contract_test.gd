extends "res://tests/test_case.gd"

var started_cues: Array[StringName] = []

func run() -> void:
	SfxService.cue_started.connect(_on_cue_started)
	_test_shop_cues()
	_test_core_encounter_cues()
	if SfxService.cue_started.is_connected(_on_cue_started):
		SfxService.cue_started.disconnect(_on_cue_started)

func _test_core_encounter_cues() -> void:
	var screen_scene := load("res://scenes/run/single_encounter_screen.tscn")
	assert_true(screen_scene != null, "single encounter screen should load for SFX")
	if screen_scene == null:
		return
	var screen: SingleEncounterScreen = screen_scene.instantiate()
	screen.tutorial_auto_start = false
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(screen)

	started_cues.clear()
	screen._on_die_activated(&"d1")
	_assert_latest(&"die_select", "selecting a die should sound")
	screen._on_lane_activated(&"left")
	_assert_latest(&"die_place", "placing a die should sound")
	screen._on_die_return_requested(&"d1")
	_assert_latest(&"die_return", "returning a die should sound")

	screen._on_card_activated(0)
	_assert_latest(&"card_select", "selecting a targeted card should sound")
	screen._on_die_activated(&"d2")
	_assert_latest(&"card_play", "applying a card should sound")

	screen._on_die_activated(&"d5")
	_assert_latest(&"die_select", "selecting a calibration die should sound")
	screen._on_calibrate_pressed(-1)
	_assert_latest(&"calibrate_down", "lower calibration should sound")
	screen._on_undo_pressed()
	_assert_latest(&"undo", "successful undo should sound")

	screen.reset_teaching_encounter()
	screen.session.activate_die(&"d1")
	screen.session.activate_table(&"left")
	screen.session.activate_die(&"d6")
	screen.session.activate_table(&"left")
	screen.refresh_from_session()
	screen._on_die_activated(&"d2")
	var cue_count_before_error := started_cues.size()
	screen._on_lane_activated(&"left")
	assert_equal(
		started_cues.size(),
		cue_count_before_error + 1,
		"rejected visible action should emit exactly one cue"
	)
	_assert_latest(&"error", "visible domain rejection should use error cue")

	screen.reset_teaching_encounter()
	for assignment in [
		[&"d1", &"left"],
		[&"d6", &"left"],
		[&"d2", &"middle"],
		[&"d3", &"middle"],
		[&"d4", &"right"],
		[&"d5", &"right"],
	]:
		screen.session.activate_die(assignment[0])
		screen.session.activate_table(assignment[1])
	screen.refresh_from_session()
	screen._on_confirm_pressed()
	_assert_latest(&"round_commit", "first successful commit should sound")

	screen.free()

func _test_shop_cues() -> void:
	var shop_scene := load("res://scenes/shop/shop_screen.tscn")
	assert_true(shop_scene != null, "shop screen should load for SFX")
	if shop_scene == null:
		return
	var shop: ShopScreen = shop_scene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(shop)
	var catalog := CardCatalog.new()
	var starter := catalog.starter_ids()
	var offers := catalog.shop_ids()
	var shop_session := ShopSession.new(catalog, starter, offers, 2)
	shop.bind_session(shop_session, catalog)

	started_cues.clear()
	shop._on_card_selected(offers[0], &"offer")
	_assert_latest(&"card_select", "selecting a shop offer should sound")
	var cue_count_before_repeat := started_cues.size()
	shop._on_card_selected(offers[0], &"offer")
	assert_equal(
		started_cues.size(),
		cue_count_before_repeat,
		"re-selecting the same shop card should stay silent"
	)
	shop._on_card_selected(starter[0], &"deck")
	_assert_latest(&"card_select", "selecting a deck replacement should sound")
	shop._on_confirm_pressed()
	_assert_latest(&"shop_purchase", "accepted shop purchase should sound")

	var area := AreaCatalog.new().gold_corridor()
	var market: Array[StringName] = area.starting_deck_ids.duplicate()
	market.append_array(area.shop_offer_ids)
	var formal_session := ShopSession.new(
		catalog,
		area.starting_deck_ids,
		market,
		4,
		ShopIntelSnapshot.routes(area.second_route_ids),
		0,
		true
	)
	shop.bind_session(formal_session, catalog)
	assert_true(
		shop.get_node("%ShopServiceStatusLabel").visible,
		"formal shop should show service status"
	)
	var tickets_before := formal_session.intel_tickets
	shop._on_refresh_pressed()
	assert_true(
		shop.get_node("%RefreshConfirmationDialog").visible,
		"refresh should require confirmation"
	)
	assert_equal(formal_session.intel_tickets, tickets_before, "opening dialog should not spend")
	started_cues.clear()
	SfxService._last_played_at.erase(&"shop_purchase")
	shop._on_refresh_confirmed()
	_assert_latest(&"shop_purchase", "accepted refresh should use shop purchase cue")
	assert_equal(
		formal_session.intel_tickets,
		tickets_before - ShopSession.REFRESH_PRICE,
		"confirmed refresh should spend one"
	)
	assert_equal(shop.selected_offer_id, &"", "refresh should clear offer selection")
	assert_equal(shop.selected_deck_id, &"", "refresh should clear deck selection")

	var emitted_snapshots: Array[ShopIntelSnapshot] = []
	shop.intel_view_requested.connect(
		func(snapshot: ShopIntelSnapshot) -> void: emitted_snapshots.append(snapshot)
	)
	var before_intel := formal_session.intel_tickets
	shop._on_intel_pressed()
	assert_equal(formal_session.intel_tickets, before_intel - 1, "intel should spend once")
	assert_equal(emitted_snapshots.size(), 1, "intel purchase should request its view")
	shop._on_intel_pressed()
	assert_equal(formal_session.intel_tickets, before_intel - 1, "reopen should be free")
	assert_equal(emitted_snapshots.size(), 2, "purchased intel should reopen")

	shop.free()

func _assert_latest(cue_id: StringName, message: String) -> void:
	assert_true(not started_cues.is_empty(), message)
	if not started_cues.is_empty():
		assert_equal(started_cues[-1], cue_id, message)

func _on_cue_started(cue_id: StringName, _bus_name: StringName) -> void:
	started_cues.append(cue_id)
