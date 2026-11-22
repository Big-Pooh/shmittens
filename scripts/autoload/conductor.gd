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
# A note of the lead melody starts now (pitch = scale index 0..7, length in 8th notes).
signal lead_note(pitch: int, length: int)
signal eighth(n: int)   # every 8th note (odd n = the off-beat hi-hat)

enum Judgement { MISS, GOOD, PERFECT }

const LAYERS = ["drums", "bass", "arp", "lead"]
const BEATS_PER_BAR = 4
const PERFECT_WINDOW = 0.05
const GOOD_WINDOW = 0.10
const ASSIST_GOOD_WINDOW = 0.14   # beginner care: wider GOOD window while assisted
const TRACK_BPM = {
	# playtest 2: slower to start (was 110/125/140, bosses 120/135/150); keep in sync with tools/gen_audio.py
	"level1": 92, "level2": 104, "level3": 116,
	"boss1": 100, "boss2": 112, "boss3": 124,
	"level4": 120, "boss4": 128,
	"level5": 108, "boss5": 116, "level6": 124, "boss6": 132,
	"level7": 112, "boss7": 120, "level8": 128, "boss8": 136,
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
# Simulation (automated playthroughs): advance time_override by unscaled frame time each frame
var sim_clock = false

var _player: AudioStreamPlayer
var _stream: AudioStreamSynchronized
var _start_usec = 0
var _pause_started_usec = -1
# bumped by play(); lets the beat loop notice a track change made by a beat listener
var _generation = 0
var _last_beat = -1
var _last_eighth = -1
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
	# release the previous track's stream + playback before building the new one (avoids a leak)
	_player.stop()
	_player.stream = null
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
	_last_eighth = -1
	_generation += 1
	# tests drive the clock directly: a new track restarts it at 0, like the real clock
	if time_override >= 0.0:
		time_override = 0.0
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


# Browsers add audio jitter: the PERFECT window is WEB_EXTRA s wider in the web build.
const WEB_EXTRA = 0.015

func perfect_window() -> float:
	return PERFECT_WINDOW + (WEB_EXTRA if OS.has_feature("web") else 0.0)


func judge(t: float = song_time()) -> Judgement:
	var error = absf(beat_error(t))
	if error <= perfect_window():
		return Judgement.PERFECT
	if error <= (ASSIST_GOOD_WINDOW if Game.assist > 0 else GOOD_WINDOW):
		return Judgement.GOOD
	return Judgement.MISS


# Sprint 7 performance: the beat phase computed ONCE per frame for every bullet that pulses
# (calling beat_phase() per bullet queried the audio clock hundreds of times a frame).
var frame_phase = 0.0


func _process(_delta):
	frame_phase = beat_phase() if playing or time_override >= 0.0 else 0.0
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
	if sim_clock and time_override >= 0.0:
		time_override += _delta / max(Engine.time_scale, 0.01)
	if not playing and time_override < 0.0:
		return
	var current = int(floor(beat_position()))
	var generation = _generation
	while _last_beat < current:
		_last_beat += 1
		if _last_beat >= 0:
			beat.emit(_last_beat)
			if _last_beat % BEATS_PER_BAR == 0:
				bar.emit(_last_beat / BEATS_PER_BAR)
		# a listener started a new track (e.g. boss music): stop emitting the old track's beats
		if _generation != generation:
			break
	if _generation != generation:
		return
	# lead melody notes (8th-note grid), from the generated MusicPatterns
	var eighth_now = int(floor(beat_position() * 2.0))
	while _last_eighth < eighth_now:
		_last_eighth += 1
		if _last_eighth < 0:
			continue
		eighth.emit(_last_eighth)
		var bar_index = (_last_eighth / 8) % MusicPatterns.BARS
		var step = _last_eighth % 8
		for note in MusicPatterns.lead(track)[bar_index]:
			if note[0] == step:
				lead_note.emit(note[1], note[2])
		if _generation != generation:
			break


# Tests: restart beat counting (used together with time_override).
func reset_beats():
	_last_beat = -1
	_last_eighth = -1


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
