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
const LEVEL_SHOT_SPEED = [0.8, 0.9, 1.0]
var assist = 0
# per-level rank stats (time is measured by the level runner)
var level_judged = 0
var level_perfects = 0
# true while the tutorial runs (main.gd starts the Tutorial instead of a level)
var tutorial_mode = false
# Automated playthroughs aim with this instead of the mouse (null = use the mouse)
var aim_override = null
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
	judged.emit(judgement)
	combo_changed.emit(combo, multiplier())
	Conductor.set_layers(multiplier() + 1)


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
	wave_total = total_waves
	wave = 0
	level_changed.emit(level)
	wave_changed.emit(wave)


# Enemy shot speed multiplier: gentler early levels, slower with assist.
func shot_speed_factor() -> float:
	var base = LEVEL_SHOT_SPEED[clamp(level, 0, LEVEL_SHOT_SPEED.size() - 1)]
	return base * (1.0 - ASSIST_SHOT_SLOWDOWN * assist)


# Called on retry after a game over on the same level.
func add_assist():
	assist = min(assist + 1, MAX_ASSIST)


# New game or new level: no assist.
func clear_assist():
	assist = 0


# Screen shake (pixels); the main scene applies it.
func shake(strength: float):
	shake_requested.emit(strength)


func set_wave(value: int):
	wave = value
	wave_changed.emit(wave)


# Called when the cat is hit. Returns the lives left.
func lose_life() -> int:
	lives = max(lives - 1, 0)
	lives_changed.emit(lives)
	add_gun_level(-1)
	reset_combo()
	if lives == 0 and not is_game_over:
		is_game_over = true
		game_over.emit()
	return lives
