extends Node

class_name LevelRunner

# Plays a level from Levels.LEVELS in time with the music:
#   INTRO   - title shown for INTRO_BARS bars
#   WAVES   - each wave spawns on a bar; when it's cleared the next one waits for the next bar
#   CLEARED - after the last wave (Day 5: boss fight goes here), then the next level starts
#   DONE    - all levels finished

signal level_started(index: int)
signal wave_started(index: int, total: int)
signal level_cleared(index: int)
signal all_levels_cleared

enum State { IDLE, INTRO, WAVES, CLEARED, DONE }

const INTRO_BARS = 2
const CLEARED_BARS = 2

var state = State.IDLE
var level_index = 0
var wave_index = -1
var alive = 0
var bars_to_wait = 0


func _ready():
	Conductor.bar.connect(_on_bar)


func level() -> Dictionary:
	return Levels.LEVELS[level_index]


func start_level(index: int):
	level_index = clamp(index, 0, Levels.count() - 1)
	wave_index = -1
	alive = 0
	state = State.INTRO
	bars_to_wait = INTRO_BARS
	Game.set_level(level_index, level().waves.size())
	Conductor.play(level().track, Game.multiplier() + 1)
	level_started.emit(level_index)


func stop():
	state = State.IDLE


func _on_bar(_n: int):
	if state == State.IDLE or state == State.DONE or Game.is_game_over:
		return
	if bars_to_wait > 0:
		bars_to_wait -= 1
		if bars_to_wait > 0:
			return
	match state:
		State.INTRO:
			state = State.WAVES
			_next_wave()
		State.WAVES:
			if alive <= 0:
				_next_wave()
		State.CLEARED:
			if level_index + 1 < Levels.count():
				start_level(level_index + 1)
			else:
				state = State.DONE
				all_levels_cleared.emit()


func _next_wave():
	wave_index += 1
	var waves = level().waves
	if wave_index >= waves.size():
		state = State.CLEARED
		bars_to_wait = CLEARED_BARS
		level_cleared.emit(level_index)
		return
	Game.set_wave(wave_index + 1)
	for group in waves[wave_index]:
		for enemy in Levels.create_group(group):
			enemy.tree_exited.connect(_on_enemy_gone)
			alive += 1
			get_tree().current_scene.add_child.call_deferred(enemy)
	wave_started.emit(wave_index, waves.size())


func _on_enemy_gone():
	alive -= 1
	# the next wave starts on the next bar (handled in _on_bar)
