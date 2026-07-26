extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var run_screen: ThreeRoundRunScreen = load(
		"res://scenes/run/three_round_run_screen.tscn"
	).instantiate()
	run_screen.run_target = 0
	root.add_child(run_screen)
	await process_frame
	await process_frame
	await process_frame

	var encounter: Control = run_screen.get_node("%EncounterScreen")
	var summary: RoundSummaryPanel = run_screen.get_node("%RoundSummaryPanel")
	var shop: ShopScreen = run_screen.get_node("%ShopScreen")
	_assert_inside(run_screen.get_rect(), encounter.get_global_rect(), "encounter screen")

	var report := run_screen.run_session.current_session.commit()
	run_screen.run_session.accept_committed_report(report)
	summary.show_run_state(run_screen.run_session)
	await process_frame
	_assert_inside(run_screen.get_rect(), summary.get_global_rect(), "round summary")
	_assert_inside(
		run_screen.get_rect(),
		summary.get_node("%SummaryTitle").get_global_rect(),
		"summary title"
	)

	summary.close()
	for round_number in range(2, 4):
		run_screen.run_session.advance_round()
		report = run_screen.run_session.current_session.commit()
		run_screen.run_session.accept_committed_report(report)
	run_screen.open_shop()
	await process_frame
	await process_frame
	_assert_inside(run_screen.get_rect(), shop.get_global_rect(), "shop screen")
	_assert_inside(
		run_screen.get_rect(),
		shop.get_node("%DeckGrid").get_global_rect(),
		"shop deck grid"
	)
	_assert_inside(
		run_screen.get_rect(),
		shop.get_node("%OfferColumn").get_global_rect(),
		"shop offer column"
	)
	_assert_true(
		shop.get_node("%DeckGrid").get_child_count() == 12,
		"shop should display twelve deck cards"
	)
	_assert_true(
		shop.get_node("%OfferColumn").get_child_count() == 3,
		"shop should display three offers"
	)

	run_screen.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS three_round_layout_self_check")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _assert_inside(parent_rect: Rect2, child_rect: Rect2, label: String) -> void:
	_assert_true(parent_rect.encloses(child_rect), "%s must remain inside root" % label)

func _assert_true(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
