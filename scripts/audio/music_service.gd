extends Node

signal track_changed(track_id: StringName)

const CROSSFADE_SECONDS := 1.25
const SCENE_POLL_SECONDS := 0.25

const GLASS_ANTECHAMBER := preload(
	"res://resources/audio/music/glass_antechamber.wav"
)
const MASKED_TABLE := preload(
	"res://resources/audio/music/masked_table.wav"
)
const LOADED_DICE := preload(
	"res://resources/audio/music/loaded_dice.wav"
)
const GOLD_CONTRACT := preload(
	"res://resources/audio/music/gold_contract.wav"
)
const MIRROR_REFRACTION := preload(
	"res://resources/audio/music/mirror_refraction.wav"
)
const FACELESS_PROTOCOL := preload(
	"res://resources/audio/music/faceless_protocol.wav"
)

const TRACK_ORDER: Array[StringName] = [
	&"menu",
	&"journey",
	&"encounter",
	&"encounter_gold_corridor",
	&"encounter_mirror_hall",
	&"encounter_faceless_hub",
]
const TRACKS := {
	&"menu": {
		"stream": GLASS_ANTECHAMBER,
		"bus": &"Music",
		"volume_db": -2.0,
	},
	&"journey": {
		"stream": MASKED_TABLE,
		"bus": &"Music",
		"volume_db": -3.0,
	},
	&"encounter": {
		"stream": LOADED_DICE,
		"bus": &"Music",
		"volume_db": -2.5,
	},
	&"encounter_gold_corridor": {
		"stream": GOLD_CONTRACT,
		"bus": &"Music",
		"volume_db": -2.5,
	},
	&"encounter_mirror_hall": {
		"stream": MIRROR_REFRACTION,
		"bus": &"Music",
		"volume_db": -2.5,
	},
	&"encounter_faceless_hub": {
		"stream": FACELESS_PROTOCOL,
		"bus": &"Music",
		"volume_db": -2.5,
	},
}

var _players: Array[AudioStreamPlayer] = []
var _active_player_index := -1
var _current_track: StringName = &""
var _last_scene_path := ""
var _scene_poll_elapsed := SCENE_POLL_SECONDS
var _crossfade_tween: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for index in range(2):
		var player := AudioStreamPlayer.new()
		player.name = "MusicPlayer%d" % index
		player.bus = &"Music"
		add_child(player)
		_players.append(player)
	call_deferred("_sync_scene_context")

func _process(delta: float) -> void:
	_scene_poll_elapsed += delta
	if _scene_poll_elapsed < SCENE_POLL_SECONDS:
		return
	_scene_poll_elapsed = 0.0
	_sync_scene_context()

func registered_track_ids() -> Array[StringName]:
	return TRACK_ORDER.duplicate()

func track_definition(track_id: StringName) -> Dictionary:
	if not TRACKS.has(track_id):
		return {}
	return TRACKS[track_id].duplicate()

func current_track_id() -> StringName:
	return _current_track

func is_playing() -> bool:
	return (
		_active_player_index >= 0
		and _players[_active_player_index].playing
	)

func context_for_scene_path(scene_path: String) -> StringName:
	if scene_path.ends_with("/main_menu_screen.tscn"):
		return &"menu"
	if (
		scene_path.ends_with("/shop_screen.tscn")
		or scene_path.ends_with("/rule_archive_screen.tscn")
	):
		return &"journey"
	if scene_path.ends_with(".tscn"):
		return &"encounter"
	return &""

func context_for_area_phase(
	phase_name: StringName,
	area_id: StringName = &""
) -> StringName:
	if phase_name in [
		&"route_choice",
		&"shop",
		&"engraving_reward",
		&"engraving_install",
		&"complete",
	]:
		return &"journey"
	if phase_name in [&"normal_room", &"dealer"]:
		match area_id:
			&"gold_corridor":
				return &"encounter_gold_corridor"
			&"mirror_hall":
				return &"encounter_mirror_hall"
			&"faceless_hub":
				return &"encounter_faceless_hub"
		return &"encounter"
	return &""

func play_area_phase(
	phase_name: StringName,
	area_id: StringName = &""
) -> bool:
	var context := context_for_area_phase(phase_name, area_id)
	if context == &"":
		return false
	var current_scene := get_tree().current_scene
	if current_scene != null:
		_last_scene_path = current_scene.scene_file_path
	return play_context(context)

func play_context(track_id: StringName, crossfade := true) -> bool:
	if not TRACKS.has(track_id):
		push_warning("Unknown music context: %s" % track_id)
		return false
	if (
		_current_track == track_id
		and _active_player_index >= 0
		and _players[_active_player_index].playing
	):
		return true

	var definition: Dictionary = TRACKS[track_id]
	var source := definition.get("stream") as AudioStreamWAV
	if source == null:
		push_warning("Music context has no WAV stream: %s" % track_id)
		return false
	var bus_name := StringName(definition.get("bus", &"Music"))
	if AudioServer.get_bus_index(bus_name) < 0:
		push_warning("Music bus missing, falling back to Master")
		bus_name = &"Master"

	if _crossfade_tween != null and _crossfade_tween.is_valid():
		_crossfade_tween.kill()
	var next_index := 0 if _active_player_index != 0 else 1
	var next_player := _players[next_index]
	next_player.stop()
	next_player.stream = _looping_copy(source)
	next_player.bus = bus_name
	var target_volume := float(definition.get("volume_db", 0.0))
	var previous_player: AudioStreamPlayer
	if _active_player_index >= 0:
		previous_player = _players[_active_player_index]

	if crossfade and previous_player != null and previous_player.playing:
		next_player.volume_db = -80.0
		next_player.play()
		_crossfade_tween = create_tween()
		_crossfade_tween.set_parallel(true)
		_crossfade_tween.tween_property(
			next_player,
			"volume_db",
			target_volume,
			CROSSFADE_SECONDS
		)
		_crossfade_tween.tween_property(
			previous_player,
			"volume_db",
			-80.0,
			CROSSFADE_SECONDS
		)
		_crossfade_tween.chain().tween_callback(previous_player.stop)
	else:
		if previous_player != null:
			previous_player.stop()
		next_player.volume_db = target_volume
		next_player.play()

	_active_player_index = next_index
	_current_track = track_id
	track_changed.emit(track_id)
	return true

func stop_music() -> void:
	if _crossfade_tween != null and _crossfade_tween.is_valid():
		_crossfade_tween.kill()
	for player in _players:
		player.stop()
	_active_player_index = -1
	_current_track = &""

func _looping_copy(source: AudioStreamWAV) -> AudioStreamWAV:
	var result := source.duplicate(true) as AudioStreamWAV
	result.loop_mode = AudioStreamWAV.LOOP_FORWARD
	result.loop_begin = 0
	result.loop_end = maxi(
		1,
		roundi(result.get_length() * result.mix_rate)
	)
	return result

func _sync_scene_context() -> void:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return
	var scene_path := current_scene.scene_file_path
	if scene_path == _last_scene_path:
		return
	_last_scene_path = scene_path
	var context := context_for_scene_path(scene_path)
	if context != &"":
		play_context(context)
