extends Node2D

# Runs a play session: starts the current level, shows level/wave/boss messages, hands out
# combo rewards, frees the Queen after the final boss, shows game over (R retry level,
# Esc title) and moves to the ending after the last level.

const REWARD_TYPES = {"battery": Pickup.Type.BATTERY, "yarn": Pickup.Type.YARN}
const TITLE_SCENE = "res://scenes/ui/title.tscn"
const ENDING_SCENE = "res://scenes/ui/ending.tscn"
const QUEEN_CAGE_POSITION = Vector2(1190, 130)
const ENDING_DELAY = 3.5

@onready var hud: Hud = $HUD
@onready var crosshair = $Crosshair
@onready var level_runner: LevelRunner = $LevelRunner
@onready var player: Shmitten = $Shmitten

var queen_cage: QueenCage
var shake_strength = 0.0
var game_over_checkpoint = 0   # saved before the runner stops


func _ready():
	Game.reset()
	Game.game_over.connect(_on_game_over)
	Game.reward.connect(_on_reward)
	Game.shake_requested.connect(func(s): shake_strength = max(shake_strength, s))
	level_runner.level_started.connect(_on_level_started)
	level_runner.wave_started.connect(func(_i, _total): hud.hide_message())
	level_runner.boss_incoming.connect(_on_boss_incoming)
	level_runner.boss_spawned.connect(_on_boss_spawned)
	level_runner.level_cleared.connect(_on_level_cleared)
	level_runner.all_levels_cleared.connect(_on_all_levels_cleared)
	if Game.tutorial_mode:
		var tutorial = Tutorial.new()
		tutorial.name = "Tutorial"
		add_child(tutorial)
	elif Game.endless_mode:
		level_runner.start_endless()
	else:
		level_runner.start_level(Game.start_level, Game.start_wave)


# Screen shake: the whole world node jitters (HUD layers stay still), decaying quickly.
func _process(delta):
	if shake_strength > 0.1:
		position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_strength
		shake_strength = lerp(shake_strength, 0.0, min(delta * 12.0, 1.0))
	elif position != Vector2.ZERO:
		position = Vector2.ZERO
		shake_strength = 0.0


func _exit_tree():
	Engine.time_scale = 1.0
	Game.drawing = false


func _on_level_started(index: int):
	if Game.endless_mode:
		hud.show_message("ENDLESS\nbest %d" % Game.best_scores.get("endless", 0))
		return
	var level = Levels.LEVELS[index]
	if level_runner.from_wave > 0:
		var where = "the boss" if level_runner.from_wave >= level.waves.size() else "wave %d" % (level_runner.from_wave + 1)
		var help = ""
		if Game.assist > 0:
			help = "\nASSIST: slower enemy shots, +%d lives" % min(Game.assist, 2)
		hud.show_message("LEVEL %d - TRY AGAIN from %s%s" % [index + 1, where, help])
	else:
		hud.show_message("LEVEL %d - %s\n%s" % [index + 1, level.title, level.story])


func _on_boss_incoming(boss_name: String):
	hud.show_message("WARNING!\n%s" % boss_name)
	Sfx.play("siren")


func _on_boss_spawned(boss: Boss):
	hud.hide_message()
	hud.show_boss(boss)
	# the final boss keeps the Queen caged in the corner
	if level_runner.level_index == Levels.count() - 1:
		queen_cage = QueenCage.new()
		queen_cage.position = QUEEN_CAGE_POSITION
		add_child(queen_cage)


func _on_level_cleared(index: int):
	if index == Levels.count() - 1 and queen_cage:
		hud.show_message("THE QUEEN IS FREE!")
		queen_cage.release(player.global_position)
	else:
		var level = Levels.LEVELS[index]
		var seconds = int(level_runner.level_seconds)
		var ratio = 100.0 * Game.level_perfects / max(Game.level_judged, 1)
		hud.show_message("LEVEL CLEAR!   RANK %s\ntime %d:%02d (par %d:%02d)   perfect %d" % [level_runner.last_rank, seconds / 60, seconds % 60, int(level.par_seconds) / 60, int(level.par_seconds) % 60, int(ratio)] + "%")


# Combo milestone rewards appear right in front of the cat.
func _on_reward(kind: String):
	Sfx.play("jingle")
	var pickup = Pickup.create(REWARD_TYPES[kind], player.global_position + Vector2(70, 0))
	add_child.call_deferred(pickup)


func _on_all_levels_cleared():
	Game.start_level = 0
	Game.start_wave = 0
	Game.clear_assist()
	await get_tree().create_timer(ENDING_DELAY, false).timeout
	get_tree().change_scene_to_file(ENDING_SCENE)


func _on_game_over():
	if Game.endless_mode:
		var best = Game.record_score("endless")
		level_runner.stop()
		Conductor.stop()
		crosshair.set_captured(false)
		hud.show_message("GAME OVER - wave %d\nscore %d%s\nR - play again     Esc - title" % [Game.wave, Game.score, "   NEW BEST!" if best else "   (best %d)" % Game.best_scores.get("endless", 0)])
		return
	game_over_checkpoint = level_runner.checkpoint()
	level_runner.stop()
	Conductor.stop()
	crosshair.set_captured(false)
	hud.show_message("GAME OVER\nscore %d\nR - try again from here     Esc - title" % Game.score)


func _unhandled_input(event):
	if not Game.is_game_over:
		return
	if event.is_action_pressed("restart"):
		retry()
	elif event.is_action_pressed("pause"):
		get_tree().change_scene_to_file(TITLE_SCENE)


# Game over -> retry from the checkpoint with one more assist level (beginner care).
func retry():
	if Game.endless_mode:
		get_tree().reload_current_scene()
		return
	Game.start_level = Game.level
	Game.start_wave = game_over_checkpoint
	Game.add_assist()
	get_tree().reload_current_scene()

