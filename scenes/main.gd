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
# Dance break rewards: each on-beat tap = DANCE_SCORE points + 1 cheese (max DANCE_CHEESE per break)
const DANCE_SCORE = 50
const DANCE_CHEESE = 4
var dance_hits = 0
var transition_card: TransitionCard
var companions: Companions
var backdrop: PlanetBackdrop
var banter: Banter


func _ready():
	Game.reset()
	Game.game_over.connect(_on_game_over)
	Game.reward.connect(_on_reward)
	Game.judged.connect(_on_judged)
	Game.grazed.connect(_on_grazed)
	Game.mech_core_ready.connect(_on_mech_core)
	banter = Banter.new()
	banter.name = "Banter"
	add_child(banter)
	backdrop = PlanetBackdrop.new()
	backdrop.name = "PlanetBackdrop"
	add_child(backdrop)
	move_child(backdrop, 0)
	backdrop.set_level(Game.start_level)
	companions = Companions.new()
	companions.name = "Companions"
	add_child(companions)
	Game.dance_changed.connect(func(on): if on: dance_hits = 0)
	Game.shake_requested.connect(func(s): shake_strength = max(shake_strength, s))
	level_runner.level_started.connect(_on_level_started)
	level_runner.wave_started.connect(func(_i, _total): hud.hide_message(); banter.wave_chatter())
	level_runner.boss_incoming.connect(_on_boss_incoming)
	level_runner.boss_spawned.connect(_on_boss_spawned)
	level_runner.level_cleared.connect(_on_level_cleared)
	level_runner.all_levels_cleared.connect(_on_all_levels_cleared)
	level_runner.interlude_started.connect(_on_interlude_started)
	level_runner.interlude_ended.connect(func(perfect): if perfect: hud.flash_text("PERFECT INTERLUDE!  +%d" % Interlude.ALL_BONUS, Color(1, 0.85, 0.4)))
	level_runner.halfway_1up.connect(func(): hud.flash_text("HALFWAY THERE!  +1 LIFE", Color(0.6, 1, 0.7)); Sfx.play("power_up"))
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
	Game.save_session("left_game")
	Engine.time_scale = 1.0
	Game.drawing = false


func _on_level_started(index: int):
	backdrop.set_level(index)
	if transition_card and is_instance_valid(transition_card):
		transition_card.close()
		transition_card = null
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
		hud.show_message("PLANET %d - %s\n%s" % [index + 1, level.title, level.story])


func _on_boss_incoming(boss_name: String):
	var tip = "" if Game.weapon == Game.Weapon.LASER else "\nTip: press 2 for the LASER POINTER - made for bosses"
	hud.show_message("WARNING!\n%s%s" % [boss_name, tip])
	Sfx.play("siren")


func _on_boss_spawned(boss: Boss):
	hud.hide_message()
	hud.show_boss(boss)
	boss.card_started.connect(func(i, _n, _s): banter.boss_card(boss, i))
	boss.armor_changed.connect(func(_p, stunned): if stunned: banter.boss_stunned(boss))
	boss.died.connect(func(_b): banter.boss_defeated(boss))
	# the final boss (Sho) keeps the Princess caged in the corner
	if Levels.LEVELS[level_runner.level_index].get("princess", false) and not boss.is_midboss:
		queen_cage = QueenCage.new()
		queen_cage.position = QUEEN_CAGE_POSITION
		add_child(queen_cage)


func _on_level_cleared(index: int):
	Game.track("levels_cleared")
	Game.save_session("level_%d_cleared" % (index + 1))
	if queen_cage and is_instance_valid(queen_cage) and Levels.LEVELS[index].get("princess", false) and (Game.is_demo() or index == Levels.count() - 1):
		hud.show_message("THE PRINCESS IS FREE!")
		queen_cage.release(player.global_position)
	else:
		if queen_cage and is_instance_valid(queen_cage):
			queen_cage.release(player.global_position)   # world 1 done - the chase continues
		var ratio = 100.0 * Game.level_perfects / max(Game.level_judged, 1)
		transition_card = TransitionCard.create(index, level_runner.last_rank, int(level_runner.level_seconds), int(ratio))
		transition_card.dismissed.connect(level_runner.skip_transition)
		add_child(transition_card)


func _on_interlude_started(interlude: Interlude):
	if transition_card and is_instance_valid(transition_card):
		transition_card.close()
		transition_card = null
	hud.show_message("INTERLUDE ~ %s\n%s" % [interlude.title(), interlude.subtitle()])
	get_tree().create_timer(Conductor.seconds_per_beat * 8.0, false).timeout.connect(func(): if level_runner.state == LevelRunner.State.INTERLUDE: hud.hide_message())


# The rare MECH CORE appears right in front of the cat, with fanfare.
func _on_mech_core():
	Sfx.play("jingle")
	hud.flash_text("MECH CORE!  grab it!", Color(1, 0.85, 0.3))
	add_child.call_deferred(Pickup.create(Pickup.Type.MECH_CORE, player.global_position + Vector2(90, 0)))


var _last_graze_msec = 0

func _on_grazed(at: Vector2, on_beat: bool):
	if Time.get_ticks_msec() - _last_graze_msec < 80:
		return
	_last_graze_msec = Time.get_ticks_msec()
	var spark = Label.new()
	spark.text = "✦" if on_beat else "·"
	spark.add_theme_font_size_override("font_size", 22 if on_beat else 18)
	spark.add_theme_color_override("font_color", Color(1, 0.95, 0.5) if on_beat else Color(1, 1, 1, 0.8))
	spark.position = at - Vector2(6, 14)
	spark.z_index = 40
	add_child(spark)
	var tween = spark.create_tween()
	tween.tween_property(spark, "modulate:a", 0.0, 0.3)
	tween.tween_callback(spark.queue_free)


func _on_judged(judgement: int):
	if not Game.dancing or judgement == Conductor.Judgement.MISS:
		return
	dance_hits += 1
	Game.track("dance_taps")
	Game.add_score(DANCE_SCORE)
	Sfx.play("dance", -6.0)
	if dance_hits <= DANCE_CHEESE:
		add_child.call_deferred(Pickup.create(Pickup.Type.CHEESE, player.global_position + Vector2(60, -30)))


# Combo milestone rewards appear right in front of the cat.
func _on_reward(kind: String):
	Sfx.play("jingle")
	var pickup = Pickup.create(REWARD_TYPES[kind], player.global_position + Vector2(70, 0))
	add_child.call_deferred(pickup)


func _on_all_levels_cleared():
	Game.track("story_completes")
	if Game.challenge != Game.Challenge.NORMAL:
		Game.track("hard_completes")
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
	Game.track("game_overs")
	Game.save_session("game_over")
	var relax = ""
	if offers_relaxed():
		relax = "\nT - switch to RELAXED and try again (slower shots, +1 life, a guardian bubble)"
	hud.show_message("GAME OVER\n%s\nscore %d\nR - try again from here     Esc - title%s" % [Banter.pick(Banter.GAME_OVER), Game.score, relax])


# Beginner care (playtest 3): from the 2nd game over on, offer Relaxed in one key press.
func offers_relaxed() -> bool:
	return Game.assist >= 1 and not Game.relaxed_mode and not Game.endless_mode


func switch_to_relaxed():
	Game.relaxed_mode = true
	Game.save_settings()
	Game.track("switched_to_relaxed")
	retry()


func _unhandled_input(event):
	if not Game.is_game_over:
		return
	if event.is_action_pressed("restart"):
		retry()
	elif event.is_action_pressed("relax") and offers_relaxed():
		switch_to_relaxed()
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

