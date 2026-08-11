extends Node

signal cue_started(cue_id: StringName, bus_name: StringName)

const PLAYER_POOL_SIZE := 12

const UI_TAP := preload("res://resources/audio/sfx/ui_tap.wav")
const UI_BACK_FOLD := preload("res://resources/audio/sfx/ui_back_fold.wav")
const PANEL_OPEN := preload("res://resources/audio/sfx/panel_open.wav")
const PAGE_TRANSITION := preload("res://resources/audio/sfx/page_transition.wav")
const DIE_SELECT := preload("res://resources/audio/sfx/die_select.wav")
const DIE_LAND := preload("res://resources/audio/sfx/die_land.wav")
const CARD_SELECT := preload("res://resources/audio/sfx/card_select.wav")
const CARD_PLAY := preload("res://resources/audio/sfx/card_play.wav")
const CALIBRATE := preload("res://resources/audio/sfx/calibrate.wav")
const UNDO := preload("res://resources/audio/sfx/undo.wav")
const PROGRESS_CONFIRM := preload("res://resources/audio/sfx/progress_confirm.wav")
const ENGRAVING := preload("res://resources/audio/sfx/engraving.wav")
const ROUND_COMMIT := preload("res://resources/audio/sfx/round_commit.wav")
const SUCCESS := preload("res://resources/audio/sfx/success.wav")
const FAILURE := preload("res://resources/audio/sfx/failure.wav")
const ERROR := preload("res://resources/audio/sfx/error.wav")
const FEEDBACK_GOLD := preload(
	"res://resources/audio/sfx/zz_feedback_gold_corridor.wav"
)
const FEEDBACK_MIRROR := preload(
	"res://resources/audio/sfx/zz_feedback_mirror_hall.wav"
)
const FEEDBACK_FACELESS := preload(
	"res://resources/audio/sfx/zz_feedback_faceless_hub.wav"
)

const CUES := {
	&"ui_confirm": {
		"stream": UI_TAP,
		"bus": &"UI",
		"volume_db": -1.0,
		"pitch_min": 0.985,
		"pitch_max": 1.015,
		"cooldown_ms": 35,
		"priority": 1,
	},
	&"ui_back": {
		"stream": UI_BACK_FOLD,
		"bus": &"UI",
		"volume_db": -1.0,
		"pitch_min": 0.98,
		"pitch_max": 1.01,
		"cooldown_ms": 35,
		"priority": 1,
	},
	&"panel_open": {
		"stream": PANEL_OPEN,
		"bus": &"UI",
		"volume_db": -2.0,
		"pitch_min": 0.99,
		"pitch_max": 1.01,
		"cooldown_ms": 120,
		"priority": 1,
	},
	&"panel_close": {
		"stream": UI_BACK_FOLD,
		"bus": &"UI",
		"volume_db": -2.0,
		"pitch_min": 0.92,
		"pitch_max": 0.95,
		"cooldown_ms": 35,
		"priority": 1,
	},
	&"page_transition": {
		"stream": PAGE_TRANSITION,
		"bus": &"UI",
		"volume_db": 0.0,
		"pitch_min": 0.99,
		"pitch_max": 1.01,
		"cooldown_ms": 100,
		"priority": 2,
	},
	&"die_select": {
		"stream": DIE_SELECT,
		"bus": &"Gameplay",
		"volume_db": -2.0,
		"pitch_min": 0.97,
		"pitch_max": 1.03,
		"cooldown_ms": 0,
		"priority": 2,
	},
	&"die_place": {
		"stream": DIE_LAND,
		"bus": &"Gameplay",
		"volume_db": -1.0,
		"pitch_min": 0.97,
		"pitch_max": 1.03,
		"cooldown_ms": 0,
		"priority": 2,
	},
	&"die_return": {
		"stream": DIE_LAND,
		"bus": &"Gameplay",
		"volume_db": -2.0,
		"pitch_min": 1.10,
		"pitch_max": 1.14,
		"cooldown_ms": 0,
		"priority": 2,
	},
	&"card_select": {
		"stream": CARD_SELECT,
		"bus": &"Gameplay",
		"volume_db": -1.0,
		"pitch_min": 0.98,
		"pitch_max": 1.02,
		"cooldown_ms": 0,
		"priority": 2,
	},
	&"card_play": {
		"stream": CARD_PLAY,
		"bus": &"Gameplay",
		"volume_db": 0.0,
		"pitch_min": 0.98,
		"pitch_max": 1.02,
		"cooldown_ms": 0,
		"priority": 2,
	},
	&"calibrate_up": {
		"stream": CALIBRATE,
		"bus": &"Gameplay",
		"volume_db": -2.0,
		"pitch_min": 1.10,
		"pitch_max": 1.13,
		"cooldown_ms": 0,
		"priority": 2,
	},
	&"calibrate_down": {
		"stream": CALIBRATE,
		"bus": &"Gameplay",
		"volume_db": -2.0,
		"pitch_min": 0.88,
		"pitch_max": 0.91,
		"cooldown_ms": 0,
		"priority": 2,
	},
	&"undo": {
		"stream": UNDO,
		"bus": &"Gameplay",
		"volume_db": -1.0,
		"pitch_min": 0.98,
		"pitch_max": 1.02,
		"cooldown_ms": 0,
		"priority": 2,
	},
	&"route_select": {
		"stream": PROGRESS_CONFIRM,
		"bus": &"Gameplay",
		"volume_db": 0.0,
		"pitch_min": 0.96,
		"pitch_max": 0.99,
		"cooldown_ms": 80,
		"priority": 3,
	},
	&"shop_purchase": {
		"stream": PROGRESS_CONFIRM,
		"bus": &"Gameplay",
		"volume_db": 0.5,
		"pitch_min": 1.04,
		"pitch_max": 1.07,
		"cooldown_ms": 80,
		"priority": 3,
	},
	&"engraving_select": {
		"stream": ENGRAVING,
		"bus": &"Gameplay",
		"volume_db": -3.0,
		"pitch_min": 1.08,
		"pitch_max": 1.12,
		"cooldown_ms": 0,
		"priority": 2,
	},
	&"engraving_install": {
		"stream": ENGRAVING,
		"bus": &"Gameplay",
		"volume_db": 0.0,
		"pitch_min": 0.94,
		"pitch_max": 0.98,
		"cooldown_ms": 100,
		"priority": 3,
	},
	&"round_commit": {
		"stream": ROUND_COMMIT,
		"bus": &"Gameplay",
		"volume_db": 0.0,
		"pitch_min": 0.99,
		"pitch_max": 1.01,
		"cooldown_ms": 180,
		"priority": 4,
	},
	&"resolution_tick": {
		"stream": PROGRESS_CONFIRM,
		"bus": &"Gameplay",
		"volume_db": -4.0,
		"pitch_min": 1.05,
		"pitch_max": 1.09,
		"cooldown_ms": 0,
		"priority": 2,
	},
	&"rule_satisfied": {
		"stream": PROGRESS_CONFIRM,
		"bus": &"Gameplay",
		"volume_db": -4.0,
		"pitch_min": 1.12,
		"pitch_max": 1.16,
		"cooldown_ms": 80,
		"priority": 3,
	},
	&"resolution_impact": {
		"stream": ENGRAVING,
		"bus": &"Gameplay",
		"volume_db": -1.0,
		"pitch_min": 0.96,
		"pitch_max": 1.0,
		"cooldown_ms": 0,
		"priority": 3,
	},
	&"resolution_climax": {
		"stream": ROUND_COMMIT,
		"bus": &"Gameplay",
		"volume_db": 1.5,
		"pitch_min": 1.08,
		"pitch_max": 1.1,
		"cooldown_ms": 120,
		"priority": 4,
	},
	&"feedback_gold_highlight": {
		"stream": FEEDBACK_GOLD,
		"bus": &"Gameplay",
		"volume_db": 0.5,
		"pitch_min": 1.0,
		"pitch_max": 1.0,
		"cooldown_ms": 300,
		"priority": 5,
	},
	&"feedback_mirror_highlight": {
		"stream": FEEDBACK_MIRROR,
		"bus": &"Gameplay",
		"volume_db": 0.5,
		"pitch_min": 1.0,
		"pitch_max": 1.0,
		"cooldown_ms": 300,
		"priority": 5,
	},
	&"feedback_faceless_highlight": {
		"stream": FEEDBACK_FACELESS,
		"bus": &"Gameplay",
		"volume_db": 0.5,
		"pitch_min": 1.0,
		"pitch_max": 1.0,
		"cooldown_ms": 300,
		"priority": 5,
	},
	&"round_success": {
		"stream": SUCCESS,
		"bus": &"Gameplay",
		"volume_db": 0.0,
		"pitch_min": 0.99,
		"pitch_max": 1.01,
		"cooldown_ms": 300,
		"priority": 5,
	},
	&"round_failure": {
		"stream": FAILURE,
		"bus": &"Gameplay",
		"volume_db": 0.0,
		"pitch_min": 0.99,
		"pitch_max": 1.01,
		"cooldown_ms": 300,
		"priority": 5,
	},
	&"area_complete": {
		"stream": SUCCESS,
		"bus": &"Gameplay",
		"volume_db": 2.0,
		"pitch_min": 0.90,
		"pitch_max": 0.92,
		"cooldown_ms": 300,
		"priority": 6,
	},
	&"error": {
		"stream": ERROR,
		"bus": &"Gameplay",
		"volume_db": -2.0,
		"pitch_min": 0.99,
		"pitch_max": 1.01,
		"cooldown_ms": 120,
		"priority": 4,
	},
}

var _players: Array[AudioStreamPlayer] = []
var _last_played_at: Dictionary = {}
var _pitch_rng := RandomNumberGenerator.new()

func _ready() -> void:
	_pitch_rng.seed = Time.get_ticks_usec() ^ get_instance_id()
	for index in range(PLAYER_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.name = "SfxPlayer%02d" % index
		add_child(player)
		_players.append(player)

func play(cue_id: StringName) -> bool:
	if not CUES.has(cue_id):
		push_warning("Unknown SFX cue: %s" % cue_id)
		return false
	var cue: Dictionary = CUES[cue_id]
	var stream := cue.get("stream") as AudioStream
	if stream == null:
		push_warning("SFX cue has no stream: %s" % cue_id)
		return false
	var now := Time.get_ticks_msec()
	var cooldown_ms := int(cue.get("cooldown_ms", 0))
	var last_played := int(_last_played_at.get(cue_id, -cooldown_ms - 1))
	if cooldown_ms > 0 and now - last_played < cooldown_ms:
		return false
	var priority := int(cue.get("priority", 1))
	var player := _find_player(priority)
	if player == null:
		return false
	var requested_bus := StringName(cue.get("bus", &"Master"))
	var resolved_bus := requested_bus
	if AudioServer.get_bus_index(resolved_bus) < 0:
		push_warning("SFX bus missing, falling back to Master: %s" % resolved_bus)
		resolved_bus = &"Master"
	player.stream = stream
	player.bus = resolved_bus
	player.volume_db = float(cue.get("volume_db", 0.0))
	player.pitch_scale = _pitch_rng.randf_range(
		float(cue.get("pitch_min", 1.0)),
		float(cue.get("pitch_max", 1.0))
	)
	player.set_meta("sfx_started_at", now)
	player.set_meta("sfx_priority", priority)
	player.play()
	_last_played_at[cue_id] = now
	cue_started.emit(cue_id, resolved_bus)
	return true

func registered_cue_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for cue_id in CUES:
		result.append(cue_id)
	result.sort()
	return result

func cue_definition(cue_id: StringName) -> Dictionary:
	if not CUES.has(cue_id):
		return {}
	return CUES[cue_id].duplicate()

func player_pool_size() -> int:
	return _players.size()

func uses_independent_pitch_rng() -> bool:
	return _pitch_rng != null

func _find_player(priority: int) -> AudioStreamPlayer:
	for player in _players:
		if not player.playing:
			return player
	var oldest_player: AudioStreamPlayer
	var oldest_started_at := Time.get_ticks_msec()
	for player in _players:
		var active_priority := int(player.get_meta("sfx_priority", 1))
		var started_at := int(player.get_meta("sfx_started_at", oldest_started_at))
		if active_priority < priority and (
			oldest_player == null or started_at < oldest_started_at
		):
			oldest_player = player
			oldest_started_at = started_at
	return oldest_player
