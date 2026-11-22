extends Node

class_name LevelRunner

# Plays a level from Levels.LEVELS in time with the music:
#   INTRO      - title + story for INTRO_BARS bars
#   WAVES      - each wave spawns on a bar; when it's cleared the next one waits for the next bar
#   BOSS_INTRO - "WARNING" + boss name, boss music starts, BOSS_INTRO_BARS bars
#   BOSS       - until the boss dies
#   CLEARED    - CLEARED_BARS bars (the transition card), then the next level (or DONE)
# Dance breaks (playtest 2: "dead time between waves"): during the intro, between a cleared
# wave and the next one, and during the boss warning, Game.dancing is on - the cat dances,
# pickups fly to her, and on-beat taps earn cheese (see main.gd).

signal level_started(index: int)
signal wave_started(index: int, total: int)
signal boss_incoming(boss_name: String)
signal boss_spawned(boss: Boss)
signal level_cleared(index: int)
signal all_levels_cleared

enum State { IDLE, INTRO, WAVES, BOSS_INTRO, BOSS, CLEARED, DONE }

const INTRO_BARS = 3
const RETRY_INTRO_BARS = 1
const BOSS_INTRO_BARS = 2
const CLEARED_BARS = 4   # the transition card (Space skips ahead)

var state = State.IDLE
var level_index = 0
var wave_index = -1
var alive = 0
var bars_to_wait = 0
var boss: Boss
var from_wave = 0
var endless = false
var level_seconds = 0.0   # game time spent fighting this level (waves + boss)
var last_rank = ""


func _ready():
	Conductor.bar.connect(_on_bar)


func level() -> Dictionary:
	return Levels.LEVELS[level_index]


# from_wave > 0 resumes at a checkpoint (waves.size() = straight to the boss).
func start_level(index: int, resume_wave: int = 0):
	level_index = clamp(index, 0, Levels.count() - 1)
	from_wave = clamp(resume_wave, 0, level().waves.size())
	wave_index = from_wave - 1
	alive = 0
	boss = null
	state = State.INTRO
	level_seconds = 0.0
	bars_to_wait = RETRY_INTRO_BARS if from_wave > 0 else INTRO_BARS
	Game.set_level(level_index, level().waves.size())
	Conductor.play(level().track, Game.multiplier() + 1)
	Game.set_dancing(true)
	level_started.emit(level_index)


func _process(delta):
	if state == State.WAVES or state == State.BOSS_INTRO or state == State.BOSS:
		level_seconds += delta


# Endless mode: no level ends; bosses every Endless.BOSS_EVERY waves.
func start_endless():
	endless = true
	level_index = 0
	wave_index = -1
	from_wave = 0
	alive = 0
	boss = null
	state = State.INTRO
	level_seconds = 0.0
	bars_to_wait = RETRY_INTRO_BARS
	Game.set_level(0, 0)
	Conductor.play(Endless.TRACKS[0], Game.multiplier() + 1)
	level_started.emit(level_index)


func stop():
	state = State.IDLE
	Game.set_dancing(false)


# The transition card was dismissed: move on at the next bar.
func skip_transition():
	if state == State.CLEARED and bars_to_wait > 1:
		bars_to_wait = 1


func _on_bar(_n: int):
	if not is_inside_tree():
		return
	if state == State.IDLE or state == State.DONE or state == State.BOSS or Game.is_game_over:
		return
	if bars_to_wait > 0:
		bars_to_wait -= 1
		if bars_to_wait > 0:
			return
	match state:
		State.INTRO:
			state = State.WAVES
			_next_wave()   # starts at from_wave (or the boss intro if past the last wave)
		State.WAVES:
			if alive <= 0:
				_next_wave()
		State.BOSS_INTRO:
			_spawn_boss()
		State.CLEARED:
			if level_index + 1 < Levels.count():
				Game.carry_assist()   # struggling players keep one level less of help
				start_level(level_index + 1)
			else:
				state = State.DONE
				Game.story_complete = true
				Game.save_settings()
				all_levels_cleared.emit()


func _next_wave():
	wave_index += 1
	if endless:
		_next_endless_wave()
		return
	var waves = level().waves
	if wave_index >= waves.size():
		_start_boss_intro()
		return
	Game.set_wave(wave_index + 1)
	Game.set_dancing(false)
	for group in waves[wave_index]:
		for enemy in Levels.create_group(group, level().get("volley_rate", 1.0)):
			enemy.tree_exited.connect(_on_enemy_gone)
			alive += 1
			get_tree().current_scene.add_child.call_deferred(enemy)
	wave_started.emit(wave_index, waves.size())


# Where a retry after game over resumes: the current wave, or the boss.
func checkpoint() -> int:
	match state:
		State.WAVES:
			return max(wave_index, 0)
		State.BOSS_INTRO, State.BOSS, State.CLEARED, State.DONE:
			return level().waves.size()
	return from_wave


func _on_enemy_gone():
	alive -= 1
	if alive <= 0 and state == State.WAVES and is_inside_tree():
		Game.set_dancing(true)
	# the next wave starts on the next bar (handled in _on_bar)


func _start_boss_intro():
	state = State.BOSS_INTRO
	bars_to_wait = BOSS_INTRO_BARS
	boss = Levels.create_boss(level_index)
	Game.set_wave(-1)   # HUD shows BOSS
	# switching tracks restarts the bar count, so the intro is measured in boss-music bars
	Conductor.play(level().boss_track, Game.multiplier() + 1)
	boss_incoming.emit(boss.boss_name)


const BOSS_MIN_LIVES = 2   # lives are topped up to at least this when a boss appears

func _spawn_boss():
	state = State.BOSS
	Game.set_dancing(false)
	if Game.lives < BOSS_MIN_LIVES:
		Game.lives = BOSS_MIN_LIVES
		Game.lives_changed.emit(Game.lives)
	boss.died.connect(_on_boss_died)
	get_tree().current_scene.add_child(boss)
	boss_spawned.emit(boss)


func _next_endless_wave():
	var stage = Endless.stage(wave_index)
	if Game.level != stage:
		Game.level = stage
		Conductor.play(Endless.TRACKS[stage], Game.multiplier() + 1)
	Game.set_wave(wave_index + 1)
	Game.set_dancing(false)
	if Endless.is_boss_wave(wave_index):
		state = State.BOSS
		boss = Levels.create_boss(stage)
		boss.max_health *= Endless.boss_health_scale(wave_index)
		boss.died.connect(func(_b): state = State.WAVES)
		get_tree().current_scene.add_child(boss)
		boss_spawned.emit(boss)
		return
	for group in Endless.wave_groups(wave_index):
		for enemy in Levels.create_group(group):
			enemy.tree_exited.connect(_on_enemy_gone)
			alive += 1
			get_tree().current_scene.add_child.call_deferred(enemy)
	wave_started.emit(wave_index, 0)


func _on_boss_died(_boss):
	if endless:
		return
	var ratio = float(Game.level_perfects) / max(Game.level_judged, 1)
	last_rank = Levels.rank(level_seconds, level().par_seconds, ratio, Game.assist > 0 or from_wave > 0)
	Game.ranks.append(last_rank)
	Game.record_level_clear(level_index)
	state = State.CLEARED
	bars_to_wait = CLEARED_BARS
	Game.set_dancing(false)
	level_cleared.emit(level_index)
