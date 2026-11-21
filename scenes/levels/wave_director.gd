extends Node

class_name WaveDirector

# Day 1: endless grunt formations that grow each wave.
# Day 4 replaces this with LevelData/WaveData resources (3 levels + bosses).

const GRUNT_SCENE = preload("res://scenes/enemies/grunt.tscn")
const WAVE_DELAY = 1.5
const SPACING = Vector2(78, 70)
const FORMATION_RIGHT_X = 1180.0
const SPAWN_X = 1380.0

var alive = 0
var running = true


func _ready():
	_next_wave.call_deferred()


func _next_wave():
	if not running or Game.is_game_over:
		return
	Game.set_wave(Game.wave + 1)
	spawn_formation(Game.wave)


func formation_size(wave: int) -> Vector2i:
	var rows = min(2 + wave / 2, 6)
	var columns = min(2 + (wave - 1) / 2, 5)
	return Vector2i(columns, rows)


func spawn_formation(wave: int):
	var size = formation_size(wave)
	var height = (size.y - 1) * SPACING.y
	var top = Game.SCREEN.get_center().y - height / 2.0
	for column in size.x:
		for row in size.y:
			var grunt = GRUNT_SCENE.instantiate() as Grunt
			grunt.slot_position = Vector2(FORMATION_RIGHT_X - column * SPACING.x, top + row * SPACING.y)
			# stagger the entry so they stream in
			grunt.position = Vector2(SPAWN_X + column * 40 + row * 20, grunt.slot_position.y)
			grunt.max_health = 2 + wave / 3
			grunt.tree_exited.connect(_on_enemy_gone)
			alive += 1
			get_tree().current_scene.add_child.call_deferred(grunt)


func _on_enemy_gone():
	alive -= 1
	if alive <= 0 and running and is_inside_tree():
		await get_tree().create_timer(WAVE_DELAY, false).timeout
		_next_wave()


func stop():
	running = false
