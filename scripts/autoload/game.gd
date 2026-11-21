extends Node

# Global run state (autoload "Game"): score, lives, skill charges, cheese, gun level.

signal score_changed(score: int)
signal lives_changed(lives: int)
signal charges_changed(charges: int, cheese: int)
signal gun_level_changed(level: int)
signal wave_changed(wave: int)
signal game_over

const START_LIVES = 3
const CHEESE_PER_CHARGE = 10
const MAX_CHARGES = 3
const MAX_GUN_LEVEL = 5

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
var is_game_over = false


func reset():
	score = 0
	lives = START_LIVES
	charges = 0
	cheese = 0
	gun_level = 1
	wave = 0
	is_game_over = false
	score_changed.emit(score)
	lives_changed.emit(lives)
	charges_changed.emit(charges, cheese)
	gun_level_changed.emit(gun_level)
	wave_changed.emit(wave)


func add_score(points: int):
	score += points
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


func set_wave(value: int):
	wave = value
	wave_changed.emit(wave)


# Called when the cat is hit. Returns the lives left.
func lose_life() -> int:
	lives = max(lives - 1, 0)
	lives_changed.emit(lives)
	add_gun_level(-1)
	if lives == 0 and not is_game_over:
		is_game_over = true
		game_over.emit()
	return lives
