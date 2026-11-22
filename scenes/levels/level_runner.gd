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
signal halfway_1up
signal interlude_started(interlude: Interlude)
signal interlude_ended(perfect: bool)

enum State { IDLE, INTRO, WAVES, BOSS_INTRO, BOSS, CLEARED, INTERLUDE, DONE }

const INTRO_BARS = 3
const RETRY_INTRO_BARS = 1
const BOSS_INTRO_BARS = 2
const DEMO_LEVELS = 4   # the demo build is world 1 (planets 1-4)
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
var interlude: Interlude
var interludes_enabled = true   # tests switch them off


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
	if Conductor.track == level().track and Conductor.playing:
		Conductor.set_layers(Game.multiplier() + 1)   # the interlude already plays this planet's song
	else:
		Conductor.play(level().track, Game.multiplier() + 1)
	Game.set_dancing(true)
	_set_safe(false)
	for shot in get_tree().get_nodes_in_group("enemy_shots") if is_inside_tree() else []:
		shot.queue_free()   # nothing left over from the last fight
	level_started.emit(level_index)


# SAFE PHASE (v0.12 playtest: "you can die in between levels"): the cleared card and the
# interlude - the cat can't be hit, leftover bullets vanish, the combo is frozen.
func _set_safe(on: bool):
	Game.safe_phase = on
	if on and is_inside_tree():
		for shot in get_tree().get_nodes_in_group("enemy_shots"):
			shot.queue_free()


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
	Game.safe_phase = false
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
		State.INTERLUDE:
			var perfect = interlude.finish() if interlude and is_instance_valid(interlude) else false
			interlude = null
			interlude_ended.emit(perfect)
			start_level(level_index + 1)
		State.INTRO:
			state = State.WAVES
			_next_wave()   # starts at from_wave (or the boss intro if past the last wave)
		State.WAVES:
			if alive <= 0:
				_next_wave()
		State.BOSS_INTRO:
			_spawn_boss()
		State.CLEARED:
			if level_index + 1 < Levels.count() and not (Game.is_demo() and level_index + 1 >= DEMO_LEVELS):
				Game.carry_assist()   # struggling players keep one level less of help
				if interludes_enabled:
					_start_interlude()
				else:
					start_level(level_index + 1)
			else:
				state = State.DONE
				Game.story_complete = true
				if Game.challenge != Game.Challenge.NORMAL:
					Game.hard_cleared = true   # unlocks TOUHOU
				Game.save_settings()
				all_levels_cleared.emit()


# Travel between planets: a calm, silly, can't-get-hurt INTERLUDE (see interlude.gd).
func _start_interlude():
	state = State.INTERLUDE
	bars_to_wait = Interlude.BARS
	_set_safe(true)
	Game.set_dancing(false)
	Conductor.play(Levels.LEVELS[level_index + 1].track, 2)   # calm: drums + bass
	interlude = Interlude.create(level_index)
	get_tree().current_scene.add_child(interlude)
	interlude_started.emit(interlude)


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
	# HALFWAY 1UP (beginner care): reaching the middle of a planet refills one lost life
	if wave_index == waves.size() / 2 and Game.lives < Game.START_LIVES:
		Game.lives += 1
		Game.lives_changed.emit(Game.lives)
		Game.track("halfway_1ups")
		halfway_1up.emit()
	for group in waves[wave_index]:
		for enemy in Levels.create_group(group, level().get("volley_rate", 1.0) * Game.density()):
			enemy.tree_exited.connect(_on_enemy_gone)
			alive += 1
			get_tree().current_scene.add_child.call_deferred(enemy)
			if enemy is Boss:
				boss_spawned.emit.call_deferred(enemy)   # mid-boss: health bar, banter
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
	Game.record_planet(level_index, last_rank)
	Game.record_level_clear(level_index)
	state = State.CLEARED
	bars_to_wait = CLEARED_BARS
	_set_safe(true)
	Game.set_dancing(false)
	level_cleared.emit(level_index)
