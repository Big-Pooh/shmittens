extends SceneTree

# Headless test run. Prints only failures plus a one-line summary.
#   Godot --headless --path . -s tests/run_tests.gd

var passed = 0
var failed = 0
var main: Node
var game: Node
var cat
# loaded at runtime (see note in _initialize)
var PlayerShot
var EnemyShot
var Pickup
const CHEESE = 0
const BATTERY = 1
const YARN = 2


func _initialize():
	# Game classes are loaded at runtime, not referenced by name: in -s mode this file is
	# compiled before the Game/Sfx autoloads exist, so naming them here fails to compile.
	_watchdog.call_deferred()
	_run.call_deferred()


func _watchdog():
	await create_timer(60.0, true, false, true).timeout
	print("FAIL: tests timed out after 60s")
	quit(2)


func check(condition: bool, name: String):
	if condition:
		passed += 1
	else:
		failed += 1
		print("FAIL: ", name)


func wait(seconds: float):
	await create_timer(seconds, false).timeout


func frames(n: int):
	for i in n:
		await physics_frame


func _start_main():
	change_scene_to_file("res://scenes/main.tscn")
	# the scene switch happens on the next rendered frame
	for i in 3:
		await process_frame
	main = current_scene
	game = root.get_node("Game")
	cat = main.get_node("Shmitten")
	# keep tests deterministic: no automatic waves
	main.wave_director.stop()
	for node in get_nodes_in_group("enemies"):
		node.queue_free()
	await frames(2)


func _spawn_grunt(at: Vector2, health := 2):
	var grunt = load("res://scenes/enemies/grunt.tscn").instantiate()
	grunt.position = at
	grunt.slot_position = at
	grunt.max_health = health
	grunt.cheese_chance = 0.0
	grunt.battery_chance = 0.0
	grunt.yarn_chance = 0.0
	main.add_child(grunt)
	return grunt


func _run():
	PlayerShot = load("res://scenes/player/player_shot.gd")
	EnemyShot = load("res://scenes/enemies/enemy_shot.gd")
	Pickup = load("res://scenes/pickups/pickup.gd")
	await _start_main()

	# --- cat stays on screen
	cat.position = Vector2(-500, 5000)
	await frames(2)
	check(game.SCREEN.has_point(cat.position), "cat is clamped to the screen")
	cat.position = Vector2(200, 360)

	# --- shots kill a grunt and score
	var grunt = _spawn_grunt(Vector2(600, 360), 2)
	await frames(2)
	for i in 2:
		main.add_child(PlayerShot.create(Vector2(500, 360), Vector2.RIGHT))
		await wait(0.2)
	check(grunt.is_dead, "two shots kill a 2-health grunt")
	check(game.score == grunt.score_value, "killing a grunt scores %d (got %d)" % [grunt.score_value, game.score])

	# --- one shot only damages one enemy
	var a = _spawn_grunt(Vector2(700, 200), 5)
	var b = _spawn_grunt(Vector2(700, 200), 5)
	await frames(2)
	main.add_child(PlayerShot.create(Vector2(620, 200), Vector2.RIGHT))
	await wait(0.2)
	check(a.health + b.health == 9, "a shot damages only one enemy")
	a.queue_free(); b.queue_free()

	# --- pickups
	game.add_cheese(game.CHEESE_PER_CHARGE)
	check(game.charges == 1 and game.cheese == 0, "10 cheese = 1 charge")
	var battery = Pickup.create(BATTERY, cat.position + Vector2(60, 0))
	main.add_child(battery)
	await wait(0.4)
	check(game.charges == 2, "battery is pulled in and adds a charge (charges=%d)" % game.charges)
	var yarn = Pickup.create(YARN, cat.position + Vector2(60, 0))
	main.add_child(yarn)
	await wait(0.4)
	check(game.gun_level == 2, "yarn raises gun level (level=%d)" % game.gun_level)
	game.add_charge(10)
	check(game.charges == game.MAX_CHARGES, "charges are capped")
	check(game.use_charge() and game.charges == game.MAX_CHARGES - 1, "using a charge")

	# --- gun fires one shot per stream
	var before = main.get_children().filter(func(n): return n.get_script() == PlayerShot).size()
	cat.get_node("Gun").fire()
	var after = main.get_children().filter(func(n): return n.get_script() == PlayerShot).size()
	check(after - before == game.gun_level, "gun fires %d streams at level %d (got %d)" % [game.gun_level, game.gun_level, after - before])

	# --- enemy shot hits the cat
	var lives = game.lives
	main.add_child(EnemyShot.create(cat.global_position + cat.get_node("Hitbox").position, Vector2.LEFT, 1.0))
	await frames(3)
	check(game.lives == lives - 1, "enemy shot costs a life")
	check(game.gun_level == 1, "dying loses a gun level")
	check(not cat.hit(), "can't be hit again while dead")
	await wait(1.2)
	check(not cat.is_dead and cat.is_invulnerable, "respawns invulnerable")
	check(not cat.hit(), "invulnerable cat ignores hits")
	await wait(2.2)
	check(not cat.is_invulnerable, "invulnerability ends")

	# --- touching an enemy costs a life and destroys it
	var rammer = _spawn_grunt(cat.global_position, 9)
	await frames(3)
	check(game.lives == lives - 2 and rammer.is_dead, "ramming an enemy costs a life and kills it")

	# --- game over + restart
	await wait(1.2)
	cat.is_invulnerable = false
	cat.hit()
	check(game.is_game_over, "game over at 0 lives")
	var restart = InputEventAction.new()
	restart.action = "restart"
	restart.pressed = true
	root.push_input(restart)
	await frames(4)
	check(not game.is_game_over and game.lives == game.START_LIVES and game.score == 0, "restart resets the run")

	# --- wave director spawns a formation
	await frames(5)
	check(get_nodes_in_group("enemies").size() > 0, "a wave spawns after restart")

	await _rhythm_tests()

	print("%d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)


# ---------------------------------------------------------------- Day 2: rhythm

func _rhythm_tests():
	var conductor = root.get_node("Conductor")
	# the restart test reloaded the scene, so grab fresh references
	await _start_main()
	var spb = conductor.seconds_per_beat
	check(is_equal_approx(spb, 60.0 / 110.0), "level1 plays at 110 BPM")

	# judging windows (time_override drives the clock)
	var saved_offset = conductor.offset_ms
	conductor.offset_ms = 0.0
	conductor.time_override = 4 * spb + 0.02
	check(conductor.judge() == conductor.Judgement.PERFECT, "20 ms late = PERFECT")
	conductor.time_override = 4 * spb - 0.08
	check(conductor.judge() == conductor.Judgement.GOOD, "80 ms early = GOOD")
	conductor.time_override = 4 * spb + 0.2
	check(conductor.judge() == conductor.Judgement.MISS, "200 ms late = MISS")
	conductor.offset_ms = 60.0
	conductor.time_override = 4 * spb + 0.06
	check(conductor.judge() == conductor.Judgement.PERFECT, "offset setting shifts the judgement")
	conductor.offset_ms = 0.0

	# combo + multiplier + music layers
	game.reset()
	for i in 5:
		game.register_judgement(conductor.Judgement.PERFECT)
	check(game.combo == 5 and game.multiplier() == 2, "5 on-beat clicks = x2 (combo %d, x%d)" % [game.combo, game.multiplier()])
	check(conductor.get_layers() == 3, "x2 adds the arp layer (layers=%d)" % conductor.get_layers())
	game.add_score(100)
	check(game.score == 200, "score is multiplied (score=%d)" % game.score)
	game.register_judgement(conductor.Judgement.MISS)
	check(game.combo == 0 and game.multiplier() == 1, "an off-beat click resets the combo")

	# a clicked shot on the beat does double damage
	conductor.time_override = 8 * spb
	var gun = cat.get_node("Gun")
	var shots_before = main.get_children().filter(func(n): return n.get_script() == PlayerShot)
	gun.click()
	var new_shots = main.get_children().filter(func(n): return n.get_script() == PlayerShot and not shots_before.has(n))
	check(new_shots.size() > 0 and is_equal_approx(new_shots[0].damage, 2.0), "PERFECT click shot does 2x damage")
	check(game.combo == 1, "on-beat click starts a combo")
	conductor.time_override = 8 * spb + 0.25
	gun.click()
	check(game.combo == 0, "off-beat click resets the combo")

	# grunts step left on each beat (and not between beats)
	var grunt = _spawn_grunt(Vector2(900, 300), 50)
	grunt.entering = false
	await frames(2)
	conductor.time_override = 20 * spb + 0.1
	conductor.reset_beats()
	await process_frame
	await frames(8)
	var x0 = grunt.position.x
	conductor.time_override = 21 * spb + 0.1
	await process_frame
	await frames(8)
	var x1 = grunt.position.x
	conductor.time_override = 21 * spb + 0.3
	await process_frame
	await frames(8)
	check(x1 < x0 - 10, "grunt steps on the beat (moved %.1f)" % (x0 - x1))
	check(is_equal_approx(grunt.position.x, x1), "grunt doesn't step between beats")
	grunt.queue_free()

	conductor.time_override = -1.0
	conductor.offset_ms = saved_offset
