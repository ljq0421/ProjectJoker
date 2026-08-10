extends "res://tests/test_case.gd"

const START_CONFIG_PATH := "res://scripts/run/expedition_start_config.gd"
const DAILY_PATH := "res://scripts/run/daily_challenge_service.gd"
const LEADERBOARD_PATH := "res://scripts/run/daily_leaderboard_store.gd"
const ACHIEVEMENT_PATH := "res://scripts/run/achievement_catalog.gd"

func run() -> void:
	assert_true(ResourceLoader.exists(START_CONFIG_PATH), "3C needs a unified launch config")
	assert_true(ResourceLoader.exists(DAILY_PATH), "3C needs deterministic local daily rules")
	assert_true(ResourceLoader.exists(LEADERBOARD_PATH), "3C needs a local daily leaderboard")
	assert_true(ResourceLoader.exists(ACHIEVEMENT_PATH), "3C needs the twelve-achievement catalog")
