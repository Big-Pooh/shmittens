extends Node2D

# Runs a play session: resets state, shows game over, restarts on R / Enter.

@onready var hud: Hud = $HUD
@onready var crosshair = $Crosshair
@onready var wave_director: WaveDirector = $WaveDirector


func _ready():
	Game.reset()
	Game.game_over.connect(_on_game_over)


func _on_game_over():
	wave_director.stop()
	crosshair.set_captured(false)
	hud.show_message("GAME OVER\nscore %d   -   press R to retry" % Game.score)


func _unhandled_input(event):
	if Game.is_game_over and event.is_action_pressed("restart"):
		get_tree().reload_current_scene()
