extends Node

# Global run state (autoload "Game"): score, lives, skill charges, cheese, gun level.

signal score_changed(score: int)
signal lives_changed(lives: int)
signal charges_changed(charges: int, cheese: int)
signal gun_level_changed(level: int)
signal wave_changed(wave: int)
signal game_over
signal combo_changed(combo: int, multiplier: int)
signal judged(judgement: int)
signal reward(kind: String)          # "battery" / "yarn" from combo milestones
signal level_changed(level: int)
signal shake_requested(strength: float)
signal fever_changed(active: bool)
signal second_wind_changed(active: bool)
signal player_hit(cause: String)   # "shot", "ram", "beam" (for stats)

const START_LIVES = 3
const CHEESE_PER_CHARGE = 10
const MAX_CHARGES = 3
const MAX_GUN_LEVEL = 5
# On-beat clicks in a row needed for score multiplier x1, x2, x3, x4
const COMBO_TIERS = [0, 5, 12, 24]
# Combo milestones (on-beat hits in a row) that hand out rewards
const BATTERY_EVERY = 5
const YARN_EVERY = 15
# Kills that weren't on-beat clicks drop 1 cheese every this many kills
const PLAIN_KILLS_PER_CHEESE = 4
# FEVER (rewards skilled players): every FEVER_EVERY on-beat hits in a row -> FEVER_BEATS beats
# of piercing, +50% damage shots and full music.
const FEVER_EVERY = 16
const FEVER_BEATS = 8
const FEVER_DAMAGE = 1.5
var fever_beats = 0

# Physics layer bits (match [layer_names] in project.godot)
const LAYER_PLAYER = 1
const LAYER_PLAYER_SHOT = 2
const LAYER_ENEMY = 4
const LAYER_ENEMY_SHOT = 8
const LAYER_PICKUP = 16

# Playfield in world/screen coordinates
const SCREEN = Rect2(0, 0, 1280, 720)

var score = 0
var lives = START_LIVES
var charges = 0
var cheese = 0
var gun_level = 1
var wave = 0
var combo = 0
var plain_kills = 0
var level = 0
var wave_total = 0
# level to (re)start at when the main scene loads; kept across reset() so retry works
var start_level = 0
# Checkpoint: wave to resume from after a game over (waves.size() = the boss)
var start_wave = 0
# Assist (beginner care): each game over on the same level adds one, up to MAX_ASSIST.
# Effects: enemy shots ASSIST_SHOT_SLOWDOWN slower per level, +1 life per level (up to +2).
const MAX_ASSIST = 3
const ASSIST_SHOT_SLOWDOWN = 0.12
const LEVEL_SHOT_SPEED = [1.0, 1.15, 1.3]   # playtest 1: dodging felt too easy (was 0.8/0.9/1.0)
var assist = 0
# per-level rank stats (time is measured by the level runner)
var level_judged = 0
var level_perfects = 0
var level_deaths = 0   # deaths in the current level attempt (early guardian)
# Second Wind (beginner care, reacts within a level): 2 deaths within SECOND_WIND_WINDOW seconds
# -> enemy shots SECOND_WIND_SLOWDOWN slower for SECOND_WIND_TIME seconds.
const SECOND_WIND_WINDOW = 45.0
const SECOND_WIND_TIME = 45.0
const SECOND_WIND_SLOWDOWN = 0.15
var play_time = 0.0
var recent_deaths = []
var second_wind_until = -1.0
var ranks = []   # rank letter per cleared level this run
# true while the tutorial runs (main.gd starts the Tutorial instead of a level)
var tutorial_mode = false
# Automated playthroughs aim with this instead of the mouse (null = use the mouse)
var aim_override = null

# ---- settings + saved progress (user://settings.cfg, shared with the Conductor's beat offset)
const SETTINGS_PATH = "user://settings.cfg"
var music_volume = 0.8
var sfx_volume = 0.8
var fullscreen = false
var reduce_effects = false   # accessibility: no screen shake, softer flashes
var relaxed_mode = false     # accessibility: always at least assist 1 (slower shots, +1 life, guardian)
var difficulty_chosen = false   # first START asks Relaxed / Normal once
var unlocked_level = 0       # highest story level the player may start
var story_complete = false   # unlocks Endless
var best_scores = {}         # "level1".."level3", "endless" -> best score
var endless_mode = false
var is_game_over = false
var drawing = false   # true while a skill gesture is being drawn (gun is disabled)


func reset():
	score = 0
	lives = START_LIVES + min(assist, 2)
	charges = 0
	cheese = 0
	gun_level = 1
	wave = 0
	combo = 0
	plain_kills = 0
	fever_beats = 0
	recent_deaths.clear()
	second_wind_until = -1.0
	is_game_over = false
	drawing = false
	combo_changed.emit(combo, multiplier())
	score_changed.emit(score)
	lives_changed.emit(lives)
	charges_changed.emit(charges, cheese)
	gun_level_changed.emit(gun_level)
	wave_changed.emit(wave)


func add_score(points: int):
	score += points * multiplier()
	score_changed.emit(score)


func add_cheese(amount: int = 1):
	cheese += amount
	while cheese >= CHEESE_PER_CHARGE:
		cheese -= CHEESE_PER_CHARGE
		charges = min(charges + 1, MAX_CHARGES)
	# at max charges the meter stays full instead of being wasted
	if charges == MAX_CHARGES:
		cheese = min(cheese, CHEESE_PER_CHARGE)
	charges_changed.emit(charges, cheese)


func add_charge(amount: int = 1):
	charges = min(charges + amount, MAX_CHARGES)
	charges_changed.emit(charges, cheese)


# Returns false if there was no charge to spend.
func use_charge() -> bool:
	if charges <= 0:
		return false
	charges -= 1
	charges_changed.emit(charges, cheese)
	return true


func add_gun_level(amount: int = 1):
	gun_level = clamp(gun_level + amount, 1, MAX_GUN_LEVEL)
	gun_level_changed.emit(gun_level)


func multiplier() -> int:
	var tier = 0
	for i in COMBO_TIERS.size():
		if combo >= COMBO_TIERS[i]:
			tier = i
	return tier + 1


# Called for every judged click. On-beat (GOOD/PERFECT) grows the combo, MISS resets it.
# The music gets a layer per multiplier tier: x1 drums+bass, x2 +arp, x3/x4 +lead.
func register_judgement(judgement: int):
	level_judged += 1
	if judgement == Conductor.Judgement.PERFECT:
		level_perfects += 1
	if judgement == Conductor.Judgement.MISS:
		combo = 0
	else:
		combo += 1
		if combo % BATTERY_EVERY == 0:
			reward.emit("battery")
		if combo % YARN_EVERY == 0:
			reward.emit("yarn")
		if combo % FEVER_EVERY == 0:
			fever_beats = FEVER_BEATS
			fever_changed.emit(true)
	judged.emit(judgement)
	combo_changed.emit(combo, multiplier())
	Conductor.set_layers(4 if is_fever() else multiplier() + 1)


func reset_combo():
	combo = 0
	combo_changed.emit(combo, multiplier())
	Conductor.set_layers(2)


# Returns true when this non-rhythm kill earns a cheese (every PLAIN_KILLS_PER_CHEESE-th).
func register_plain_kill() -> bool:
	plain_kills += 1
	return plain_kills % PLAIN_KILLS_PER_CHEESE == 0


func set_level(value: int, total_waves: int):
	level = value
	level_judged = 0
	level_perfects = 0
	level_deaths = 0
	wave_total = total_waves
	wave = 0
	level_changed.emit(level)
	wave_changed.emit(wave)


# Enemy shot speed multiplier: gentler early levels, slower with assist.
func shot_speed_factor() -> float:
	var base = LEVEL_SHOT_SPEED[clamp(level, 0, LEVEL_SHOT_SPEED.size() - 1)]
	var wind = 1.0 - SECOND_WIND_SLOWDOWN if second_wind_active() else 1.0
	return base * (1.0 - ASSIST_SHOT_SLOWDOWN * assist) * wind


func second_wind_active() -> bool:
	return play_time < second_wind_until


func _process(delta):
	if get_tree().paused:
		return
	var was = second_wind_active()
	play_time += delta
	if was and not second_wind_active():
		second_wind_changed.emit(false)


# Called on retry after a game over on the same level.
func add_assist():
	assist = min(assist + 1, MAX_ASSIST)


# New game: no assist.
func clear_assist():
	assist = 1 if relaxed_mode else 0


# Next level: struggling players keep a little help (one level less); others stay at 0.
func carry_assist():
	assist = max(assist - 1, 1 if relaxed_mode else 0)


# Extra warning beats for beams/dashes while assisted.
func warning_beats(base: int) -> int:
	return base + (1 if assist > 0 else 0)


# Screen shake (pixels); the main scene applies it.
func shake(strength: float):
	if reduce_effects:
		return
	shake_requested.emit(strength)


func is_fever() -> bool:
	return fever_beats > 0


func _ready():
	Conductor.beat.connect(_on_beat)
	load_settings()
	apply_settings()


func load_settings():
	var c = ConfigFile.new()
	if c.load(SETTINGS_PATH) != OK:
		return
	music_volume = c.get_value("audio", "music_volume", music_volume)
	sfx_volume = c.get_value("audio", "sfx_volume", sfx_volume)
	fullscreen = c.get_value("video", "fullscreen", fullscreen)
	reduce_effects = c.get_value("access", "reduce_effects", reduce_effects)
	relaxed_mode = c.get_value("access", "relaxed_mode", relaxed_mode)
	difficulty_chosen = c.get_value("access", "difficulty_chosen", difficulty_chosen)
	unlocked_level = c.get_value("progress", "unlocked_level", unlocked_level)
	story_complete = c.get_value("progress", "story_complete", story_complete)
	best_scores = c.get_value("progress", "best_scores", best_scores)


func save_settings():
	var c = ConfigFile.new()
	c.load(SETTINGS_PATH)   # keep other sections (beat offset, tutorial)
	c.set_value("audio", "music_volume", music_volume)
	c.set_value("audio", "sfx_volume", sfx_volume)
	c.set_value("video", "fullscreen", fullscreen)
	c.set_value("access", "reduce_effects", reduce_effects)
	c.set_value("access", "relaxed_mode", relaxed_mode)
	c.set_value("access", "difficulty_chosen", difficulty_chosen)
	c.set_value("progress", "unlocked_level", unlocked_level)
	c.set_value("progress", "story_complete", story_complete)
	c.set_value("progress", "best_scores", best_scores)
	c.save(SETTINGS_PATH)


func apply_settings():
	for bus_name in ["Music", "SFX"]:
		var bus = AudioServer.get_bus_index(bus_name)
		if bus >= 0:
			var volume = music_volume if bus_name == "Music" else sfx_volume
			AudioServer.set_bus_volume_db(bus, linear_to_db(max(volume, 0.0001)))
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)


# A story level was cleared: unlock the next one and keep the best score.
func record_level_clear(level_index: int):
	unlocked_level = max(unlocked_level, min(level_index + 1, 2))
	record_score("level%d" % (level_index + 1))
	save_settings()


func record_score(key: String) -> bool:
	var is_best = score > best_scores.get(key, 0)
	if is_best:
		best_scores[key] = score
		save_settings()
	return is_best


func _on_beat(_n: int):
	if fever_beats > 0:
		fever_beats -= 1
		if fever_beats == 0:
			fever_changed.emit(false)
			Conductor.set_layers(multiplier() + 1)


func set_wave(value: int):
	wave = value
	wave_changed.emit(wave)


# Called when the cat is hit. Returns the lives left.
func lose_life() -> int:
	level_deaths += 1
	recent_deaths.append(play_time)
	recent_deaths = recent_deaths.filter(func(t): return play_time - t <= SECOND_WIND_WINDOW)
	if recent_deaths.size() >= 2:
		var was_active = second_wind_active()
		second_wind_until = play_time + SECOND_WIND_TIME
		if not was_active:
			second_wind_changed.emit(true)
	lives = max(lives - 1, 0)
	lives_changed.emit(lives)
	add_gun_level(-1)
	reset_combo()
	if lives == 0 and not is_game_over:
		is_game_over = true
		game_over.emit()
	return lives
