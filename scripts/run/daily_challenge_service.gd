class_name DailyChallengeService
extends RefCounted

const DAILY_RULESET_VERSION := 1
const StartConfig = preload("res://scripts/run/expedition_start_config.gd")
const ExpeditionConfigs = preload("res://scripts/run/expedition_config_catalog.gd")

func local_date_key() -> String:
	var date := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [date.year, date.month, date.day]

func seed_for(date_key: String) -> int:
	var value := 2166136261
	for byte in ("%s|%d" % [date_key, DAILY_RULESET_VERSION]).to_utf8_buffer():
		value = int((value ^ byte) * 16777619) & 0x7fffffff
	return maxi(value, 1)

func config_for(date_key: String) -> ExpeditionStartConfig:
	var config := StartConfig.new()
	var seed := seed_for(date_key)
	var deck_ids := ExpeditionConfigs.new().deck_ids()
	var day_index := int(Time.get_unix_time_from_datetime_string(
		"%sT00:00:00" % date_key
	) / 86400.0)
	var challenge_ids: Array[StringName] = []
	challenge_ids.assign(
		RunRng.new(seed).shuffle(ExpeditionConfigs.new().challenge_ids()).slice(0, 2)
	)
	var result := config.restore_snapshot({
		"mode": StartConfig.DAILY,
		"seed_value": seed,
		"starting_deck_id": deck_ids[posmod(day_index, deck_ids.size())],
		"challenge_ids": challenge_ids,
		"area_sequence": StartConfig.STANDARD_AREAS.duplicate(),
		"area_modifier_ids": {},
		"target_multiplier": 1.0,
		"daily_date_key": date_key,
	})
	return config if result.accepted else null

func leaderboard_eligible(config: ExpeditionStartConfig, current_date_key: String) -> bool:
	return (
		config != null
		and config.mode == StartConfig.DAILY
		and config.daily_date_key == current_date_key
	)

func expedition_score(completed_areas: Array) -> int:
	var score := 0
	for completion in completed_areas:
		if not completion is Dictionary:
			continue
		for room in completion.get("rooms", []):
			score += int(room.get("cumulative_total", 0))
		for special in completion.get("special_rooms", []):
			if special.get("type", &"") == &"elite":
				score += int(special.get("cumulative_total", 0))
		score += int(completion.get("dealer", {}).get("cumulative_total", 0))
	return score
