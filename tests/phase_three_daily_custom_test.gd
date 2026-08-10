extends "res://tests/test_case.gd"

const StartConfig = preload("res://scripts/run/expedition_start_config.gd")
const Daily = preload("res://scripts/run/daily_challenge_service.gd")
const Leaderboard = preload("res://scripts/run/daily_leaderboard_store.gd")

var _leaderboard_path := ""

func run() -> void:
	_leaderboard_path = OS.get_environment("TEMP").path_join(
		"project-joker-daily-board-%d.cfg" % Time.get_ticks_usec()
	)
	_test_daily_date_determinism_and_cross_day_rule()
	_test_daily_ranking_and_run_id_idempotency()
	_test_custom_validation_and_combined_target_rounding()
	_cleanup()

func _test_daily_date_determinism_and_cross_day_rule() -> void:
	var service := Daily.new()
	var first = service.config_for("2026-08-10")
	var replay = service.config_for("2026-08-10")
	var next_day = service.config_for("2026-08-11")
	assert_true(first != null, "daily config is valid")
	assert_equal(first.to_snapshot(), replay.to_snapshot(), "same date replays exactly")
	assert_equal(first.challenge_ids.size(), 2, "daily fixes exactly two challenges")
	assert_true(
		first.starting_deck_id != next_day.starting_deck_id,
		"starting deck rotates on the next local date"
	)
	assert_true(service.leaderboard_eligible(first, "2026-08-10"), "same day is eligible")
	assert_false(service.leaderboard_eligible(first, "2026-08-11"), "old daily cannot rank")

func _test_daily_ranking_and_run_id_idempotency() -> void:
	var store := Leaderboard.new(_leaderboard_path)
	var date := "2026-08-10"
	for entry in [
		_entry(date, &"a", 200, 3, 90),
		_entry(date, &"b", 220, 4, 80),
		_entry(date, &"c", 220, 2, 100),
		_entry(date, &"d", 220, 2, 70),
	]:
		assert_true(store.record(entry, date).accepted, "daily entry records")
	assert_true(store.record(_entry(date, &"d", 999, 0, 1), date).accepted, "duplicate is idempotent")
	var board := store.entries(date)
	assert_equal(board.size(), 4, "duplicate run id does not create another row")
	assert_equal(board[0].run_id, &"d", "score, emergency, then time determine rank")
	assert_equal(board[1].run_id, &"c", "same score/spend uses faster completion")
	assert_equal(board[2].run_id, &"b", "higher emergency spend ranks later")
	assert_false(
		store.record(_entry(date, &"old", 500, 0, 1), "2026-08-11").accepted,
		"cross-day completion is rejected from today's board"
	)

func _test_custom_validation_and_combined_target_rounding() -> void:
	var config := StartConfig.new()
	var challenges := ExpeditionConfigCatalog.new().challenge_ids()
	var configured := config.restore_snapshot({
		"mode": StartConfig.CUSTOM,
		"seed_value": 8112026,
		"starting_deck_id": &"table_chain",
		"challenge_ids": challenges,
		"area_sequence": [&"gold_corridor"],
		"area_modifier_ids": {
			&"gold_corridor": [&"gold_straight_gift", &"gold_same_radiance"],
		},
		"target_multiplier": 1.25,
		"daily_date_key": "",
	})
	assert_true(configured.accepted, "custom accepts six challenges and two distinct modifiers")
	var expedition := ExpeditionSession.new()
	assert_true(expedition.start_with_config(config).accepted, "custom expedition starts")
	assert_equal(expedition.current_area_id(), &"gold_corridor", "one-area custom uses prefix")
	var entry := expedition.current_entry_state()
	assert_equal(entry.configured_area_modifier_ids.size(), 2, "both modifiers enter area")
	var area := AreaRunSession.new(8112026, AreaCatalog.new().gold_corridor())
	assert_true(area.configure_entry_state(entry).accepted, "area accepts custom options")
	assert_true(area.start().accepted, "custom area starts")
	assert_equal(area.area_modifier_ids.size(), 2, "both area modifiers are active")
	var room_id: StringName = area.current_route_ids()[0]
	var room := area.area_definition.find_room(room_id)
	assert_true(area.select_route(room_id).accepted, "custom route starts")
	assert_equal(
		area.encounter_session.target_total,
		ceili(float(room.target_total) * 1.15 * 1.25),
		"high pressure and custom multiplier combine before one ceiling"
	)
	var invalid := config.to_snapshot()
	invalid.area_modifier_ids[&"gold_corridor"] = [
		&"gold_straight_gift", &"gold_straight_gift",
	]
	assert_false(StartConfig.new().restore_snapshot(invalid).accepted, "duplicate modifiers reject")
	invalid = config.to_snapshot()
	invalid.area_sequence = [&"mirror_hall"]
	invalid.area_modifier_ids = {}
	assert_false(StartConfig.new().restore_snapshot(invalid).accepted, "custom areas must be a prefix")

func _entry(
	date_key: String,
	run_id: StringName,
	score: int,
	emergency_spend: int,
	completion_time: int
) -> Dictionary:
	return {
		"date_key": date_key,
		"run_id": run_id,
		"score": score,
		"emergency_spend": emergency_spend,
		"completion_time": completion_time,
		"completed": true,
	}

func _cleanup() -> void:
	Leaderboard.new(_leaderboard_path).clear()
