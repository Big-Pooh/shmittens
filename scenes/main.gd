extends Node2D

# Runs a play session: starts the current level, shows level/wave messages, hands out
# combo rewards, shows game over and retries the level on R / Enter.

const REWARD_TYPES = {"battery": Pickup.Type.BATTERY, "yarn": Pickup.Type.YARN}

@onready var hud: Hud = $HUD
@onready var crosshair = $Crosshair
@onready var level_runner: LevelRunner = $LevelRunner
@onready var player: Shmitten = $Shmitten


func _ready():
	Game.reset()
	Game.game_over.connect(_on_game_over)
	Game.reward.connect(_on_reward)
	level_runner.level_started.connect(_on_level_started)
	level_runner.wave_started.connect(func(_i, _total): hud.hide_message())
	level_runner.level_cleared.connect(func(_i): hud.show_message("LEVEL CLEAR!"))
	level_runner.all_levels_cleared.connect(_on_all_levels_cleared)
	level_runner.start_level(Game.start_level)


func _exit_tree():
	Engine.time_scale = 1.0
	Game.drawing = false


func _on_level_started(index: int):
	var level = Levels.LEVELS[index]
	hud.show_message("LEVEL %d\n%s" % [index + 1, level.title])


# Combo milestone rewards appear right in front of the cat.
func _on_reward(kind: String):
	var pickup = Pickup.create(REWARD_TYPES[kind], player.global_position + Vector2(70, 0))
	add_child.call_deferred(pickup)


func _on_all_levels_cleared():
	hud.show_message("ALL LEVELS CLEAR!\nscore %d" % Game.score)
	Game.start_level = 0


func _on_game_over():
	level_runner.stop()
	Conductor.stop()
	crosshair.set_captured(false)
	hud.show_message("GAME OVER\nscore %d   -   press R to retry level %d" % [Game.score, Game.level + 1])


func _unhandled_input(event):
	if Game.is_game_over and event.is_action_pressed("restart"):
		Game.start_level = Game.level
		get_tree().reload_current_scene()
