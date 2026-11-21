extends Node

# The beat clock (autoload "Conductor").
#
# Plays a track's 4 layers (drums, bass, arp, lead) in sync with AudioStreamSynchronized and
# emits beat/bar signals. Timing follows the wall clock since play() was called, corrected for
# audio latency (Godot's recommended way to sync gameplay to music). It runs in real time, so
# beats keep coming during slow motion (Engine.time_scale) and while the tree is paused they stop.
#
# judge() rates an input against the nearest beat: PERFECT / GOOD / MISS.

signal beat(n: int)        # n counts beats since the track started (0, 1, 2, ...)
signal bar(n: int)
signal track_started(track_name: String)

enum Judgement { MISS, GOOD, PERFECT }

const LAYERS = ["drums", "bass", "arp", "lead"]
const BEATS_PER_BAR = 4
const PERFECT_WINDOW = 0.05
const GOOD_WINDOW = 0.10
const TRACK_BPM = {
	"level1": 110, "level2": 125, "level3": 140,
	"boss1": 120, "boss2": 135, "boss3": 150,
}
const SETTINGS_PATH = "user://settings.cfg"
const SILENT_DB = -60.0
const MUFFLED_CUTOFF = 900.0

var bpm = 120.0
var seconds_per_beat = 0.5
var track = ""
var playing = false
# Player-adjustable latency compensation in milliseconds (+ = judge later).
var offset_ms = 0.0
# Tests set this to drive the clock directly (seconds); -1 = use the real clock.
var time_override = -1.0

var _player: AudioStreamPlayer
var _stream: AudioStreamSynchronized
var _start_usec = 0
var _pause_started_usec = -1
var _last_beat = -1
var _layer_count = 0
var _music_bus = -1
var _lowpass: AudioEffectLowPassFilter


func _ready():
	# keep ticking while paused so we can track pause time and resume in sync
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_bus()
	_player = AudioStreamPlayer.new()
	_player.bus = "Music"
	add_child(_player)
	_load_settings()


func _setup_bus():
	_music_bus = AudioServer.get_bus_index("Music")
	if _music_bus == -1:
		AudioServer.add_bus()
		_music_bus = AudioServer.bus_count - 1
		AudioServer.set_bus_name(_music_bus, "Music")
		AudioServer.set_bus_send(_music_bus, "Master")
	_lowpass = AudioEffectLowPassFilter.new()
	_lowpass.cutoff_hz = MUFFLED_CUTOFF
	AudioServer.add_bus_effect(_music_bus, _lowpass)
	AudioServer.set_bus_effect_enabled(_music_bus, 0, false)


# Starts a track from its first beat. Layers above `layers` start silent.
func play(track_name: String, layers: int = 2):
	track = track_name
	bpm = TRACK_BPM.get(track_name, 120)
	seconds_per_beat = 60.0 / bpm
	_stream = AudioStreamSynchronized.new()
	_stream.stream_count = LAYERS.size()
	for i in LAYERS.size():
		var path = "res://Audio/Music/%s_%s.wav" % [track_name, LAYERS[i]]
		if ResourceLoader.exists(path):
			_stream.set_sync_stream(i, load(path))
	_player.stream = _stream
	_layer_count = -1
	set_layers(layers)
	_player.play()
	_start_usec = Time.get_ticks_usec()
	_last_beat = -1
	playing = true
	track_started.emit(track)


func stop():
	playing = false
	_player.stop()


# Number of audible layers, 1..4 (drums, +bass, +arp, +lead). Used for music intensity.
func set_layers(count: int):
	count = clamp(count, 1, LAYERS.size())
	if count == _layer_count or _stream == null:
		return
	_layer_count = count
	for i in LAYERS.size():
		var target = 0.0 if i < count else SILENT_DB
		var from = _stream.get_sync_stream_volume(i)
		create_tween().tween_method(func(db): _stream.set_sync_stream_volume(i, db), from, target, 0.4)


func get_layers() -> int:
	return _layer_count


# Muffles the music (low-pass) e.g. while drawing a gesture in slow motion.
func set_muffled(muffled: bool):
	AudioServer.set_bus_effect_enabled(_music_bus, 0, muffled)


# Seconds since the track's first beat, as heard by the player (latency + offset corrected).
func song_time() -> float:
	if time_override >= 0.0:
		return time_override - offset_ms / 1000.0
	if not playing:
		return 0.0
	var now = _pause_started_usec if _pause_started_usec >= 0 else Time.get_ticks_usec()
	var t = (now - _start_usec) / 1_000_000.0
	t -= AudioServer.get_time_to_next_mix() + AudioServer.get_output_latency()
	return t - offset_ms / 1000.0


func beat_position(t: float = song_time()) -> float:
	return t / seconds_per_beat


# 0..1 progress through the current beat (0 = on the beat).
func beat_phase(t: float = song_time()) -> float:
	var p = beat_position(t)
	return p - floor(p)


# Signed seconds from the nearest beat (negative = early).
func beat_error(t: float = song_time()) -> float:
	var p = beat_position(t)
	return (p - round(p)) * seconds_per_beat


func judge(t: float = song_time()) -> Judgement:
	var error = absf(beat_error(t))
	if error <= PERFECT_WINDOW:
		return Judgement.PERFECT
	if error <= GOOD_WINDOW:
		return Judgement.GOOD
	return Judgement.MISS


func _process(_delta):
	# While the game is paused: pause the music and freeze the clock; on resume, shift the
	# start time by the paused duration so beats continue exactly where they left off.
	if get_tree().paused:
		if playing and _pause_started_usec < 0:
			_pause_started_usec = Time.get_ticks_usec()
			_player.stream_paused = true
		return
	if _pause_started_usec >= 0:
		_start_usec += Time.get_ticks_usec() - _pause_started_usec
		_pause_started_usec = -1
		_player.stream_paused = false
	if not playing and time_override < 0.0:
		return
	var current = int(floor(beat_position()))
	while _last_beat < current:
		_last_beat += 1
		if _last_beat >= 0:
			beat.emit(_last_beat)
			if _last_beat % BEATS_PER_BAR == 0:
				bar.emit(_last_beat / BEATS_PER_BAR)


# Tests: restart beat counting (used together with time_override).
func reset_beats():
	_last_beat = -1


func _exit_tree():
	# release the music streams so quitting doesn't report leaks
	_player.stop()
	_player.stream = null
	_stream = null


func set_offset_ms(value: float):
	offset_ms = clamp(value, -200.0, 200.0)
	var config = ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("audio", "beat_offset_ms", offset_ms)
	config.save(SETTINGS_PATH)


func _load_settings():
	var config = ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		offset_ms = config.get_value("audio", "beat_offset_ms", 0.0)
