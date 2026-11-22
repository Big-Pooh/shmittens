extends SceneTree

# Sped-up complete playthroughs with an automated player persona.
#   Godot --headless --fixed-fps 60 --path . -s tests/playthrough.gd -- <persona> <seed>
# personas: noob, average, speedrunner. Runs as fast as the CPU allows (game time is simulated).
# Retries a level after game over (like a real player) up to MAX_RETRIES per level.
# Prints one JSON line per run: per-level deaths (by cause), game overs, judgements, combo,
# skills, time, plus whether the game was finished.

const MAX_RETRIES = 6
const MAX_GAME_SECONDS = 2400.0

var persona = "average"
var seed_value = 1
var stats = {}           # bot-level counters (current level)
var levels = []          # per-level summaries
var level_stats = {}
var game
var conductor
var sim_seconds = 0.0
var bot = null
var relaxed = false   # tester picked RELAXED at the first-start prompt


func _initialize():
	var args = OS.get_cmdline_user_args()
	if args.size() > 0:
		persona = args[0]
	if args.size() > 1:
		seed_value = int(args[1])
	relaxed = args.size() > 2 and args[2] == "relaxed"
	seed(seed_value)
	_run.call_deferred()


func _new_level_stats(index: int) -> Dictionary:
	return {"level": index + 1, "deaths": 0, "causes": {}, "game_overs": 0, "seconds": 0.0,
		"perfect": 0, "good": 0, "miss": 0, "max_combo": 0, "boss_seconds": 0.0, "cleared": false}


func _run():
	game = root.get_node("Game")
	conductor = root.get_node("Conductor")
	conductor.sim_clock = true
	conductor.time_override = 0.0
	game.tutorial_mode = false
	game.start_level = 0
	game.relaxed_mode = relaxed
	game.clear_assist()
	game.judged.connect(_on_judged)
	game.player_hit.connect(_on_hit)
	game.combo_changed.connect(func(c, _m): level_stats.max_combo = max(level_stats.get("max_combo", 0), c))
	level_stats = _new_level_stats(0)
	change_scene_to_file("res://scenes/main.tscn")
	var finished = false
	while sim_seconds < MAX_GAME_SECONDS:
		await physics_frame
		sim_seconds += 1.0 / 60.0   # one fixed 60 fps frame
		var scene = current_scene
		if scene == null:
			continue
		if scene.name == "Ending":
			finished = true
			level_stats.cleared = true
			break
		if scene.name != "Main":
			continue
		if bot == null or not is_instance_valid(bot):
			bot = load("res://tests/persona_bot.gd").new()
			bot.setup(persona, seed_value * 1000 + levels.size() * 10 + level_stats.game_overs, stats)
			scene.add_child(bot)
		level_stats.seconds += 1.0 / 60.0
		if scene.level_runner.state == scene.level_runner.State.BOSS:
			level_stats.boss_seconds += 1.0 / 60.0
		# level finished -> start a new record
		if game.level + 1 > level_stats.level:
			level_stats.cleared = true
			_close_level()
			level_stats = _new_level_stats(game.level)
		if game.is_game_over:
			level_stats.game_overs += 1
			if level_stats.game_overs > MAX_RETRIES:
				break
			conductor.time_override = 0.0
			scene.retry()   # same retry path as a player pressing R
			bot = null
			for i in 3:
				await process_frame
	_close_level()
	var summary = {"persona": persona, "seed": seed_value, "finished": finished,
		"game_seconds": snappedf(sim_seconds, 0.1), "score": game.score, "levels": levels}
	print("RESULT " + JSON.stringify(summary))
	quit()


func _close_level():
	level_stats.seconds = snappedf(level_stats.seconds, 0.1)
	level_stats.boss_seconds = snappedf(level_stats.boss_seconds, 0.1)
	for key in ["clicks", "casts", "empowered", "fizzles", "fizzle_unrecognised", "fizzle_no_charge"]:
		level_stats[key] = stats.get(key, 0)
	stats.clear()
	levels.append(level_stats.duplicate(true))


func _on_judged(judgement: int):
	match judgement:
		2: level_stats.perfect += 1
		1: level_stats.good += 1
		_: level_stats.miss += 1


func _on_hit(cause: String):
	level_stats.deaths += 1
	var phase = "boss" if current_scene and current_scene.name == "Main" and current_scene.level_runner.state == current_scene.level_runner.State.BOSS else "waves"
	var key = "%s@%s" % [cause, phase]
	level_stats.causes[key] = level_stats.causes.get(key, 0) + 1
