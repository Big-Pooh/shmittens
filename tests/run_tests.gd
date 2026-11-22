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
var Shockwave
var LaserBeam
var ChainLightning
var Levels
var EnemyBeam
var ShieldMouseScript
const CHEESE = 0
const BATTERY = 1
const YARN = 2


func _initialize():
	# Game classes are loaded at runtime, not referenced by name: in -s mode this file is
	# compiled before the Game/Sfx autoloads exist, so naming them here fails to compile.
	_watchdog.call_deferred()
	_run.call_deferred()


func _watchdog():
	await create_timer(120.0, true, false, true).timeout
	print("FAIL: tests timed out after 120s")
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
	# older tests were written for the Spread gun (playtest 3 made Fish the default)
	game.weapon = game.Weapon.SPREAD
	# keep tests deterministic: no automatic waves
	main.level_runner.stop()
	for node in get_nodes_in_group("enemies"):
		node.queue_free()
	await frames(2)


func _spawn_grunt(at: Vector2, health := 2):
	var grunt = load("res://scenes/enemies/grunt.tscn").instantiate()
	grunt.position = at
	grunt.slot_position = at
	grunt.max_health = health
	grunt.drops = false
	main.add_child(grunt)
	return grunt


func _run():
	PlayerShot = load("res://scenes/player/player_shot.gd")
	EnemyShot = load("res://scenes/enemies/enemy_shot.gd")
	Pickup = load("res://scenes/pickups/pickup.gd")
	Shockwave = load("res://scenes/gestures/skills/shockwave.gd")
	LaserBeam = load("res://scenes/gestures/skills/laser_beam.gd")
	ChainLightning = load("res://scenes/gestures/skills/chain_lightning.gd")
	# snapshot the player's real settings file; it is restored byte-for-byte after the run
	var settings_snapshot = FileAccess.get_file_as_string("user://settings.cfg") if FileAccess.file_exists("user://settings.cfg") else ""
	Levels = load("res://scenes/levels/levels.gd")
	# the opening story plays before the very first game; tests start games directly
	root.get_node("Game").skip_intro = true
	# tests assume NORMAL difficulty regardless of the player's saved choice (restored after)
	root.get_node("Game").challenge = 0
	root.get_node("Game").relaxed_mode = false
	# restore the player's real settings after the run (some tests change and save them)
	var original = {"chosen": root.get_node("Game").difficulty_chosen, "relaxed": root.get_node("Game").relaxed_mode}
	# tests must never write the player's real save (the persistence test enables it briefly)
	root.get_node("Game").persist = false
	EnemyBeam = load("res://scenes/enemies/enemy_beam.gd")
	ShieldMouseScript = load("res://scenes/enemies/shield_mouse.gd")
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
	check(is_equal_approx(a.health + b.health, 10.0 - PlayerShot.POINT_BLANK), "a shot damages only one enemy")   # (spread pellet, point-blank x1.3)
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
	check(after - before == cat.get_node("Gun").shots_per_fire(), "gun fires %d pellets at level %d (got %d)" % [cat.get_node("Gun").shots_per_fire(), game.gun_level, after - before])

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
	check(not game.is_game_over and game.lives == game.START_LIVES + 1 and game.assist == 1 and game.score == 0, "retry restarts with +1 assist life")

	# --- the level restarts (intro first, then waves)
	await frames(5)
	check(current_scene.level_runner.state == current_scene.level_runner.State.INTRO, "level restarts after retry")

	await _rhythm_tests()
	await _gesture_tests()
	await _rhythm_loop_tests()
	await _enemy_tests()
	await _level_tests()
	await _boss_tests()
	await _polish_tests()
	await _full_run_test()
	await _memory_tests()
	await _tutorial_tests()
	await _assist_tests()
	_rank_tests()
	await _lead_note_tests()
	await _boss_assist_tests()
	await _guardian_tests()
	await _fever_tests()
	_volley_rate_tests()
	await _iteration1_tests()
	_second_wind_tests()
	await _spell_chain_tests()
	await _screen_tests()
	await _playtest2_tests()
	await _playtest3_tests()
	await _playtest4_tests()
	await _story_tests()
	await _playtest5_tests()
	await _designer7_tests()

	game.difficulty_chosen = original.chosen
	game.relaxed_mode = original.relaxed
	if settings_snapshot != "":
		var f = FileAccess.open("user://settings.cfg", FileAccess.WRITE)
		f.store_string(settings_snapshot)
		f.close()
	print("%d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)


# ---------------------------------------------------------------- Day 2: rhythm

func _rhythm_tests():
	var conductor = root.get_node("Conductor")
	# the restart test reloaded the scene, so grab fresh references
	await _start_main()
	var spb = conductor.seconds_per_beat
	check(is_equal_approx(spb, 60.0 / 92.0), "level1 plays at 92 BPM (playtest 2: slower start)")

	# judging windows (time_override drives the clock)
	var saved_offset = conductor.offset_ms
	conductor.offset_ms = 0.0
	conductor.time_override = 4 * spb + 0.02
	check(conductor.judge() == conductor.Judgement.PERFECT, "20 ms late = PERFECT")
	conductor.time_override = 4 * spb - 0.08
	check(conductor.judge() == conductor.Judgement.GOOD, "80 ms early = GOOD")
	conductor.time_override = 4 * spb + 0.2
	check(conductor.judge() == conductor.Judgement.MISS, "200 ms late = MISS")
	game.assist = 1
	conductor.time_override = 4 * spb + 0.12
	check(conductor.judge() == conductor.Judgement.GOOD, "assisted players get a wider GOOD window (120 ms)")
	game.assist = 0
	check(conductor.judge() == conductor.Judgement.MISS, "normal GOOD window is 100 ms")
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


# ---------------------------------------------------------------- Day 3: gestures

var rng = RandomNumberGenerator.new()


func _stroke(corners: Array, size: float, rotation: float, wobble: float, per_segment := 12) -> PackedVector2Array:
	var out = PackedVector2Array()
	for i in corners.size() - 1:
		for k in per_segment:
			out.append(corners[i].lerp(corners[i + 1], float(k) / per_segment))
	out.append(corners[corners.size() - 1])
	var result = PackedVector2Array()
	for p in out:
		result.append((p * size).rotated(rotation) + Vector2(640, 360) + Vector2(rng.randf_range(-wobble, wobble), rng.randf_range(-wobble, wobble)))
	return result


func _circle_stroke(size: float) -> PackedVector2Array:
	var corners = []
	var start = rng.randf() * TAU
	var dir = 1.0 if rng.randf() < 0.5 else -1.0
	for i in 33:
		corners.append(Vector2.from_angle(start + dir * TAU * 1.03 * i / 32.0))
	return _stroke(corners, size, 0.0, size * 0.05, 2)


func _triangle_stroke(size: float) -> PackedVector2Array:
	var c = [Vector2(0, -1), Vector2(0.9, 0.6), Vector2(-0.9, 0.6)]
	if rng.randf() < 0.5:
		c.reverse()
	return _stroke(c + [c[0]], size, rng.randf_range(-0.4, 0.4), size * 0.05)


func _zigzag_stroke(size: float) -> PackedVector2Array:
	var c = []
	for k in rng.randi_range(3, 5) + 1:
		c.append(Vector2(k * 0.5, (k % 2) * 0.9))
	var angle = rng.randf_range(-0.3, 0.3) + (PI / 2.0 if rng.randf() < 0.3 else 0.0)
	# ~2px jitter: real mouse strokes are smooth (small deltas), unlike random per-point noise
	return _stroke(c, size, angle, 2.0)


# dead enemies are freed shortly after dying
func _gone(enemy) -> bool:
	return not is_instance_valid(enemy) or enemy.is_dead


func _gesture_tests():
	await _start_main()
	var conductor = root.get_node("Conductor")
	rng.seed = 42
	var recognizer = load("res://scenes/gestures/gesture_recognizer.gd").new()

	# recogniser accuracy on varied synthetic strokes (sizes 40-160 px, both directions, wobble)
	var makers = {"circle": _circle_stroke, "triangle": _triangle_stroke, "zigzag": _zigzag_stroke}
	for shape in makers:
		var correct = 0
		for i in 15:
			if recognizer.recognize(makers[shape].call(rng.randf_range(40, 160))).name == shape:
				correct += 1
		check(correct == 15, "%s recognised %d/15" % [shape, correct])
	var line = recognizer.recognize(_stroke([Vector2(0, 0), Vector2(1, -1)], 150, 0.0, 2.0))
	check(line.name == "line" and line.direction.dot(Vector2(1, -1).normalized()) > 0.98, "line recognised with its direction")
	var rejected = 0
	for i in 40:
		var p = Vector2(640, 360)
		var pts = PackedVector2Array([p])
		for k in 30:
			p += Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(10, 40)
			pts.append(p)
		if recognizer.recognize(pts).name == "":
			rejected += 1
	check(rejected >= 38, "random scribbles rejected (%d/40)" % rejected)
	check(recognizer.recognize(PackedVector2Array([Vector2(0, 0), Vector2(20, 5)])).name == "", "tiny strokes ignored")

	# drawing flow: slow motion, muffle, gun disabled, charge spent, skill cast
	var gestures = main.get_node("GestureInput")
	conductor.offset_ms = 0.0
	conductor.time_override = 30 * conductor.seconds_per_beat + 0.3   # off-beat
	game.charges = 2
	var circle = _circle_stroke(120)
	gestures.begin(circle[0])
	check(is_equal_approx(Engine.time_scale, gestures.SLOW_MO_SCALE) and game.drawing, "drawing starts slow motion")
	check(not cat.can_shoot(), "gun disabled while drawing")
	for p in circle:
		gestures.add_point(p)
	var cast_log = []
	gestures.cast.connect(func(skill, empowered): cast_log.append([skill, empowered]))
	gestures.finish()
	check(is_equal_approx(Engine.time_scale, 1.0) and not game.drawing, "releasing ends slow motion")
	check(cast_log.size() == 1 and cast_log[0][0] == "shockwave" and not cast_log[0][1], "circle casts a (normal) shockwave off-beat")
	check(game.charges == 1, "casting spends a charge")
	await frames(30)

	# on-beat release = empowered
	conductor.time_override = 31 * conductor.seconds_per_beat + 0.01
	var triangle = _triangle_stroke(100)
	gestures.begin(triangle[0])
	for p in triangle:
		gestures.add_point(p)
	gestures.finish()
	check(cast_log.size() == 2 and cast_log[1] == ["shield", true], "on-beat triangle casts an EMPOWERED shield")
	check(cat.has_shield() and not cat.hit(), "shield blocks hits")
	check(is_equal_approx(cat.get_node("Shield").duration, 6.0), "empowered shield lasts 6s")
	cat.get_node("Shield").queue_free()
	await frames(2)

	# fizzle and no-charge cost nothing
	var charges = game.charges
	gestures.begin(Vector2(640, 360))
	for k in 30:
		gestures.add_point(Vector2(640, 360) + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(20, 200))
	gestures.finish()
	check(game.charges == charges, "a fizzle costs no charge")
	game.charges = 0
	var zigzag = _zigzag_stroke(120)
	gestures.begin(zigzag[0])
	for p in zigzag:
		gestures.add_point(p)
	gestures.finish()
	check(cast_log.size() == 2, "no cast without charges")

	# slow motion is capped at 2 real seconds
	gestures.begin()
	await create_timer(2.3, true, false, true).timeout
	check(not gestures.drawing and is_equal_approx(Engine.time_scale, 1.0), "drawing auto-ends after 2s")

	# skill effects
	for node in get_nodes_in_group("enemies"):
		node.queue_free()
	await frames(2)
	cat.position = Vector2(200, 360)
	var near = _spawn_grunt(Vector2(400, 360), 5)
	var far = _spawn_grunt(Vector2(1100, 100), 5)
	await frames(2)
	main.add_child(Shockwave.create(cat.global_position, false))
	await wait(0.7)
	check(_gone(near) and not _gone(far), "shockwave hits enemies in range only")

	var on_line = _spawn_grunt(Vector2(900, 360), 7)
	var off_line = _spawn_grunt(Vector2(900, 600), 7)
	await frames(2)
	main.add_child(LaserBeam.create(cat, Vector2.RIGHT, false))
	await wait(0.6)
	check(_gone(on_line) and not _gone(off_line) and far.health == 5.0, "laser hits only what's on the beam")

	for node in get_nodes_in_group("enemies"):
		node.queue_free()
	await frames(2)
	var chain = []
	for i in 7:
		chain.append(_spawn_grunt(Vector2(500 + i * 120, 300), 4))
	await frames(2)
	main.add_child(ChainLightning.create(cat.global_position, Vector2(500, 300), false))
	await frames(2)
	var struck = chain.filter(func(g): return _gone(g)).size()
	check(struck == 5, "lightning hits the target + 4 jumps (%d)" % struck)

	conductor.time_override = -1.0


# ---------------------------------------------------------------- Day 4 + revision 1

func _count(group: String, filter := Callable()) -> int:
	var nodes = get_nodes_in_group(group)
	if filter.is_valid():
		nodes = nodes.filter(filter)
	return nodes.size()


func _clear_world():
	for g in ["enemies", "pickups", "enemy_shots"]:
		for node in get_nodes_in_group(g):
			node.queue_free()
	await frames(2)


func _rhythm_loop_tests():
	await _start_main()
	var conductor = root.get_node("Conductor")
	await _clear_world()
	cat.position = Vector2(150, 650)   # keep the cat away so pickups don't get collected

	# drops follow the killing shot's timing
	var perfect = _spawn_grunt(Vector2(700, 200), 1)
	perfect.drops = true
	await frames(2)
	perfect.take_hit(2.0, Vector2.RIGHT, conductor.Judgement.PERFECT)
	await frames(3)
	check(_count("pickups") == 2, "PERFECT kill drops 2 cheese (%d)" % _count("pickups"))
	await _clear_world()
	var good = _spawn_grunt(Vector2(700, 200), 1)
	good.drops = true
	await frames(2)
	good.take_hit(1.5, Vector2.RIGHT, conductor.Judgement.GOOD)
	await frames(3)
	check(_count("pickups") == 1, "GOOD kill drops 1 cheese")
	await _clear_world()
	game.plain_kills = 0
	for i in 4:
		var plain = _spawn_grunt(Vector2(700, 100 + i * 80), 1)
		plain.drops = true
		await frames(1)
		plain.take_hit(1.0, Vector2.RIGHT, -1)
	await frames(3)
	check(_count("pickups") == 1, "4 off-beat kills drop exactly 1 cheese (%d)" % _count("pickups"))
	await _clear_world()

	# combo milestones
	game.reset()
	var rewards = []
	game.reward.connect(func(kind): rewards.append(kind))
	for i in 15:
		game.register_judgement(conductor.Judgement.GOOD)
	check(rewards == ["battery", "battery", "battery", "yarn"], "milestones: battery every 5, yarn at 15 (%s)" % [rewards])
	await frames(3)
	check(_count("pickups") == 4, "milestone rewards appear in the world")

	# holding fire shoots on the beat, unjudged
	await _clear_world()
	var gun = cat.get_node("Gun")
	gun.last_click_msec = -100000
	var before = main.get_children().filter(func(n): return n.get_script() == PlayerShot).size()
	var combo_before = game.combo
	Input.action_press("shoot")
	gun._on_beat(1)
	Input.action_release("shoot")
	var held = main.get_children().filter(func(n): return n.get_script() == PlayerShot)
	check(held.size() - before == gun.shots_per_fire() and held[-1].judgement == -1 and is_equal_approx(held[-1].damage, gun.HELD_DAMAGE), "held fire shoots on the beat (0.6 dmg, unjudged)")
	check(game.combo == combo_before, "held fire doesn't touch the combo")
	gun._on_beat(2)
	check(main.get_children().filter(func(n): return n.get_script() == PlayerShot).size() == held.size(), "no beat shot when not holding")


func _enemy_tests():
	await _start_main()
	await _clear_world()
	cat.position = Vector2(200, 500)

	# grunt firing rotation: slot 1 of 3 fires on beat 3 of bars 1, 4, 7...
	var grunt = _spawn_grunt(Vector2(900, 300), 9)
	grunt.fire_slot = 1
	grunt.fire_slots = 3
	var fires = []
	for n in 48:
		if grunt.should_fire(n):
			fires.append(n)
	check(fires == [6, 18, 30, 42], "grunt fires in a fixed rotation (%s)" % [fires])
	var before_volley = _count("enemy_shots")
	grunt.on_beat(6)
	await frames(1)
	var volley = get_nodes_in_group("enemy_shots")
	check(volley.size() == before_volley + 1 and volley[-1].velocity.normalized().dot((cat.global_position - grunt.global_position).normalized()) > 0.99, "grunt volleys aim at the cat")

	# gunner: warning flash on beat 4, aimed shot on the downbeat
	var gunner = load("res://scenes/enemies/gunner.tscn").instantiate()
	gunner.position = Vector2(900, 200)
	main.add_child(gunner)
	await frames(2)
	gunner.on_beat(3)
	check(gunner.sprite.modulate != Color.WHITE, "gunner flashes before firing")
	var shots_before = _count("enemy_shots")
	gunner.on_beat(4)
	await frames(1)
	var shots = get_nodes_in_group("enemy_shots")
	check(shots.size() == shots_before + 3, "gunner fires a 3-shot spread on the downbeat")
	if shots.size() > 0:
		var aim = shots[-2].velocity.normalized()   # middle shot of the spread
		check(aim.dot((cat.global_position - gunner.global_position).normalized()) > 0.99, "gunner shot is aimed at the cat")

	# dasher: lines up with the cat, then charges on a downbeat after one bar
	var dasher = load("res://scenes/enemies/dasher.tscn").instantiate()
	dasher.position = Vector2(1150, 200)
	main.add_child(dasher)
	await frames(2)
	for n in range(1, 4):
		dasher._on_conductor_beat(n)
		await wait(0.15)
	check(dasher.position.y > 300 and not dasher.dashing and dasher.locked, "dasher slides toward the cat's height, then locks its line")
	dasher._on_conductor_beat(4)
	check(dasher.dashing, "dasher charges on the downbeat after warning")
	var x0 = dasher.position.x
	await wait(0.2)
	check(dasher.position.x < x0 - 100, "dasher moves fast when charging")

	# shield mouse: plate blocks off-beat frontal shots; beat, angle and skills get through
	var conductor = root.get_node("Conductor")
	game.gun_level = 1   # (rank: enemy health grows with gun level)
	var shielded = load("res://scenes/enemies/shield_mouse.tscn").instantiate()
	shielded.position = Vector2(800, 400)
	shielded.max_health = 20
	shielded.drops = false
	main.add_child(shielded)
	await frames(2)
	shielded.take_hit(1.0, Vector2.RIGHT, -1)
	shielded.take_hit(1.0, Vector2(1, 0.3), conductor.Judgement.MISS)
	check(shielded.health == 20.0, "plate blocks off-beat and held shots from the front")
	shielded.take_hit(2.0, Vector2.RIGHT, conductor.Judgement.PERFECT)
	check(shielded.health == 18.0, "PERFECT shot smashes through the plate")
	shielded.take_hit(1.0, Vector2(0.3, 1), -1)
	check(shielded.health == 17.0, "steep-angle shot gets past the plate")
	shielded.take_damage(5.0)
	check(shielded.health == 12.0, "skills ignore the plate")


func _level_tests():
	await _start_main()
	var conductor = root.get_node("Conductor")
	var runner = main.level_runner
	await _clear_world()

	# every formation fits on screen
	var all_inside = true
	for level in Levels.LEVELS:
		for wave in level.waves:
			for group in wave:
				for slot in Levels.formation_slots(group):
					if not Rect2(40, 40, 1240, 640).has_point(slot):
						all_inside = false
	check(all_inside, "all formation slots are on screen")
	var wave_counts = Levels.LEVELS.map(func(l): return l.waves.size())
	var midbosses = 0
	for level in Levels.LEVELS:
		for wave in level.waves:
			for group in wave:
				if group.enemy == "midboss":
					midbosses += 1
					var mb = Levels.create_midboss(group)
					check(mb.is_midboss and mb.cards.size() == 2 and mb.get_script() != load("res://scenes/enemies/bosses/mecha_tank.gd"), "mid-boss %s is a unique boss with 2 spell cards" % mb.boss_name)
					mb.free()
	check(wave_counts.all(func(n): return n == 10) and midbosses == 3, "every planet has 10 waves; planets 2-4 have a mid-boss (%s, %d)" % [wave_counts, midbosses])

	# drive the music bar by bar and clear each wave by force
	var spb = conductor.seconds_per_beat
	var bar = [0]
	var next_bar = func():
		bar[0] += 1
		conductor.time_override = bar[0] * 4 * conductor.seconds_per_beat + 0.01
		await process_frame
		await frames(3)
	conductor.time_override = 0.01
	runner.start_level(0)
	conductor.reset_beats()
	await process_frame
	check(runner.state == runner.State.INTRO and game.level == 0, "level 1 starts with its intro")
	await next_bar.call()
	await next_bar.call()
	check(runner.state == runner.State.WAVES and game.wave == 1, "wave 1 starts after the 2-bar intro")
	check(_count("enemies") == 9, "wave 1 spawns a 3x3 grid (%d)" % _count("enemies"))
	var waves = Levels.LEVELS[0].waves.size()
	for w in waves:
		for e in get_nodes_in_group("enemies"):
			e.queue_free()
		await frames(2)
		await next_bar.call()
	check(runner.state == runner.State.BOSS_INTRO and conductor.track == "boss1", "after the last wave: boss warning + boss music")
	# a track change restarts the beat clock: restart our fake clock too
	bar[0] = 0
	game.lives = 1
	await next_bar.call()
	await next_bar.call()
	var bosses = get_nodes_in_group("bosses")
	check(runner.state == runner.State.BOSS and bosses.size() == 1, "boss spawns after the 2-bar warning")
	check(game.lives >= runner.BOSS_MIN_LIVES, "lives are topped up to at least 2 at the boss")
	if bosses.size() == 1:
		bosses[0].die()
	await frames(2)
	check(runner.state == runner.State.CLEARED, "killing the boss clears the level")
	check(main.transition_card != null and main.transition_card.is_inside_tree(), "a transition card shows between levels")
	main.transition_card.dismissed.emit()   # SPACE on the card: move on at the next bar
	await next_bar.call()
	bar[0] = 0
	check(main.transition_card == null, "the card closes when the next level starts")
	check(game.level == 1 and conductor.track == "level2", "level 2 starts with its own music (%s)" % conductor.track)
	conductor.time_override = -1.0


# ---------------------------------------------------------------- Day 5: bosses + screens

func _make_boss(path: String, at := Vector2(1000, 360)):
	var boss = load(path).new()
	boss.position = at
	boss.drops = false
	main.add_child(boss)
	await frames(2)
	boss.card_intro = 0   # skip the spell card's name intro (2 invulnerable beats)
	return boss


func _boss_tests():
	await _start_main()
	var conductor = root.get_node("Conductor")
	await _clear_world()
	cat.position = Vector2(200, 360)
	cat.is_invulnerable = true   # keep the cat alive through boss attacks

	# armour: off-beat/held 50%, on-beat 100%, skills 100%
	var tank = await _make_boss("res://scenes/enemies/bosses/mecha_tank.gd")
	var full = tank.max_health
	tank.take_hit(10.0, Vector2.RIGHT, -1)
	check(is_equal_approx(tank.health, full - 5.0), "held shot does 50% to a boss")
	tank.take_hit(10.0, Vector2.RIGHT, conductor.Judgement.MISS)
	check(is_equal_approx(tank.health, full - 10.0), "off-beat click does 50% to a boss")
	tank.take_hit(10.0, Vector2.RIGHT, conductor.Judgement.PERFECT)
	check(is_equal_approx(tank.health, full - 20.0), "on-beat click does full damage to a boss")
	tank.take_damage(10.0)
	check(is_equal_approx(tank.health, full - 30.0), "skills do full damage to a boss")

	# tank pattern: 5-shot left-pointing arc on the downbeat (not aimed)
	var shots = _count("enemy_shots")
	tank.on_beat(4)
	await frames(1)
	check(_count("enemy_shots") - shots == 5, "tank fires a 5-shot arc on the downbeat")
	var arc_shots = get_nodes_in_group("enemy_shots").slice(-5)
	check(arc_shots.all(func(e): return e.velocity.x < 0.0), "the arc points left, away from the boss")
	# the melody is a stave: notes fly straight left, higher pitch = higher on screen
	shots = _count("enemy_shots")
	tank.on_lead_note(7, 1)
	tank.on_lead_note(0, 1)
	await frames(1)
	var melody = get_nodes_in_group("enemy_shots").slice(-2)
	check(_count("enemy_shots") - shots == 2 and melody[0].position.y < melody[1].position.y and is_zero_approx(melody[0].velocity.y), "lead notes are staff notes: straight left, higher pitch higher up")
	# phase 2: beat armour
	var phases = []
	tank.phase_changed.connect(func(p): phases.append(p))
	tank.take_damage(tank.health - tank.max_health * 0.4)
	check(is_equal_approx(tank.health, tank.max_health * 0.5) and tank.card == 1, "damage can't spill past a spell card: it stops at the card's share")
	tank.card_intro = 0
	check(tank.phase == 2 and phases == [2] and tank.is_armored() and is_equal_approx(tank.armor, tank.ARMOR_PIPS), "phase 2 below half health raises 5 pips of beat armour")
	var hp = tank.health
	tank.take_hit(10.0, Vector2.RIGHT, conductor.Judgement.GOOD)
	tank.take_hit(10.0, Vector2.RIGHT, -1)
	check(is_equal_approx(tank.health, hp), "armoured: GOOD and held shots do no damage")
	tank.take_hit(10.0, Vector2.RIGHT, conductor.Judgement.PERFECT)
	check(is_equal_approx(tank.health, hp - 10.0), "armoured: PERFECT shots do full damage")
	check(is_equal_approx(tank.armor, tank.ARMOR_PIPS - 1.0 - 0.5 - 0.1), "each hit chips the armour (PERFECT 1, GOOD 0.5, held 0.1)")
	for i in 4:
		tank.take_hit(0.01, Vector2.RIGHT, conductor.Judgement.PERFECT)
	check(tank.is_stunned() and not tank.is_armored(), "breaking the last pip stuns the boss")
	shots = _count("enemy_shots")
	tank._on_conductor_beat(8)
	tank._on_lead_note(3, 1)
	await frames(1)
	check(_count("enemy_shots") <= shots, "a stunned boss doesn't fire")   # (<=: bullets cleared at the card change may still be freeing)
	hp = tank.health
	tank.take_hit(10.0, Vector2.RIGHT, -1)
	check(is_equal_approx(tank.health, hp - 15.0), "a stunned boss takes 1.5x damage from everything")
	for n in tank.STUN_BEATS:
		tank._on_conductor_beat(9 + n)
	check(not tank.is_stunned() and tank.is_armored() and is_equal_approx(tank.armor, tank.ARMOR_PIPS), "after the stun the armour comes back")
	# off-beat play alone still breaks the armour eventually (the beat is the key way, not the only one)
	var misses = 0
	while tank.is_armored() and misses < 100:
		tank.take_hit(0.01, Vector2.RIGHT, conductor.Judgement.MISS)
		misses += 1
	check(misses <= 40 and tank.is_stunned(), "off-beat shots alone break the armour too, just slowly (%d)" % misses)
	tank.queue_free()
	await _clear_world()
	# assisted players: GOOD cracks a whole pip
	game.assist = 1
	var easy = await _make_boss("res://scenes/enemies/bosses/mecha_tank.gd")
	easy.take_damage(easy.health - easy.max_health * 0.4)
	easy.card_intro = 0
	easy.take_hit(1.0, Vector2.RIGHT, conductor.Judgement.GOOD)
	check(is_equal_approx(easy.armor, easy.ARMOR_PIPS - 1.0), "with assist, GOOD shots crack a whole pip")
	game.assist = 0
	easy.queue_free()
	await _clear_world()

	# mothership: a full-height wall with one gap; beam hits only along its line
	var ship = await _make_boss("res://scenes/enemies/bosses/mothership.gd")
	shots = _count("enemy_shots")
	ship.on_beat(0)
	await frames(2)
	var wall = get_nodes_in_group("enemy_shots").slice(shots)
	var gap_y = load("res://scenes/enemies/bosses/mothership.gd").gap_for_bar(0)
	check(wall.size() >= 9 and wall.all(func(e): return absf(e.position.y - gap_y) > 70.0), "mothership wall leaves a gap at the predictable height (%d shots)" % wall.size())
	var beam = EnemyBeam.create(900, 300, 0.0, 1.0)
	check(beam.hits(Vector2(200, 310)) and not beam.hits(Vector2(200, 380)) and not beam.hits(Vector2(1000, 300)), "beam hits only along its line")
	beam.free()
	ship.queue_free()
	await _clear_world()

	# rat king: no guards any more (they blocked shots); phase 2 adds crossing spirals
	var king = await _make_boss("res://scenes/enemies/bosses/rat_king.gd")
	var enemies_before = _count("enemies")
	king.take_damage(king.max_health * 0.6)
	await frames(2)
	check(_count("enemies") == enemies_before, "Rat King no longer summons shot-blocking guards")
	shots = _count("enemy_shots")
	king.on_beat(1)
	await frames(1)
	check(_count("enemy_shots") - shots == 2, "Rat King's 2nd card: two counter-rotating spiral arms per beat")
	king.queue_free()
	await _clear_world()

	# boss death drops a guaranteed reward
	var reward_tank = await _make_boss("res://scenes/enemies/bosses/mecha_tank.gd")
	reward_tank.drops = true
	reward_tank.die()
	await frames(3)
	check(_count("pickups") == 7, "boss drops 5 cheese + battery + yarn (%d)" % _count("pickups"))

	# final level: boss fight shows the caged Queen; clearing frees her
	await _clear_world()
	var runner = main.level_runner
	conductor.time_override = 0.01
	var last = Levels.count() - 1
	runner.start_level(last)
	runner.wave_index = Levels.LEVELS[last].waves.size() - 1
	runner.state = runner.State.WAVES
	runner._next_wave()   # -> boss intro
	runner._spawn_boss()
	await frames(2)
	check(main.queen_cage != null and main.queen_cage.is_inside_tree(), "final boss fight (Sho) shows the caged Princess")
	check(runner.boss.get_script() == load("res://scenes/enemies/bosses/sho.gd") and runner.boss.cards.size() == 4, "Sho is the final boss, with 4 spell cards")
	var cleared = []
	runner.all_levels_cleared.connect(func(): cleared.append(true))
	runner.boss.die()
	await frames(2)
	check(runner.state == runner.State.CLEARED, "final boss defeated -> cleared")
	runner.bars_to_wait = 1
	runner._on_bar(0)
	check(cleared == [true], "after the final level: all levels cleared")
	conductor.time_override = -1.0
	cat.is_invulnerable = false


func _screen_tests():
	await _start_main()
	# pause menu: pauses, slider sets and saves the beat offset, resume unpauses
	var conductor = root.get_node("Conductor")
	var saved = conductor.offset_ms
	var pause = main.get_node("PauseMenu")
	pause.toggle()
	check(paused and pause.is_open(), "pause menu pauses the game")
	pause.offset_slider.value = 35
	check(is_equal_approx(conductor.offset_ms, 35.0), "offset slider sets the beat offset")
	pause.toggle()
	check(not paused and not pause.is_open(), "resume unpauses")
	conductor.set_offset_ms(saved)

	# title -> start -> main at level 1
	change_scene_to_file("res://scenes/ui/title.tscn")
	for i in 3:
		await process_frame
	check(current_scene.name == "Title", "title screen loads")
	game.difficulty_chosen = true
	current_scene.start_game()
	for i in 3:
		await process_frame
	check(current_scene.name == "Main" and game.level == 0, "Start loads the game at level 1")
	game.tutorial_mode = false

	# ending screen loads and shows the score
	change_scene_to_file("res://scenes/ui/ending.tscn")
	for i in 3:
		await process_frame
	check(current_scene.name == "Ending", "ending screen loads")


# ---------------------------------------------------------------- Day 6: polish

func _polish_tests():
	await _start_main()
	await _clear_world()
	var conductor = root.get_node("Conductor")
	# beat hints: sparkles + edge glow on each beat, more on the downbeat
	var fx = main.get_node("BeatFX")
	conductor.stop()   # no real beats during this test
	fx.sparkles.clear()
	fx._on_beat(1)
	check(fx.sparkles.size() == fx.SPARKLES_PER_BEAT and fx.edge_glow > 0.0, "sparkles + edge glow on a beat")
	fx.sparkles.clear()
	fx._on_beat(4)
	check(fx.sparkles.size() == fx.SPARKLES_PER_DOWNBEAT and is_equal_approx(fx.edge_glow, 1.0), "bigger burst on the downbeat")
	await wait(0.6)
	check(fx.sparkles.is_empty(), "sparkles fade out")

	# dasher shows a harmless warning line before charging
	var dasher = load("res://scenes/enemies/dasher.tscn").instantiate()
	dasher.position = Vector2(1150, 300)
	dasher.drops = false
	main.add_child(dasher)
	await frames(2)
	dasher.beats_alive = 2
	var lines_before = main.get_children().filter(func(n): return n.get_script() == EnemyBeam).size()
	dasher.on_beat(2)
	var lines = main.get_children().filter(func(n): return n.get_script() == EnemyBeam)
	check(lines.size() == lines_before + 1 and lines[-1].active_time == 0.0, "dasher shows a warning-only line")
	dasher.queue_free()

	# screen shake moves the world, then settles
	game.shake(12.0)
	await frames(2)
	var moved = main.position != Vector2.ZERO
	await wait(1.0)
	check(moved and main.position == Vector2.ZERO, "screen shake moves the world, then settles")


# Plays through every level, wave and boss (forcing each to clear) and reaches the ending.
func _full_run_test():
	await _start_main()
	var conductor = root.get_node("Conductor")
	var runner = main.level_runner
	cat.is_invulnerable = true
	var bar = [0]
	var next_bar = func():
		bar[0] += 1
		conductor.time_override = bar[0] * 4 * conductor.seconds_per_beat + 0.01
		await process_frame
		await frames(2)
	conductor.time_override = 0.01
	runner.start_level(0)
	var bosses_beaten = 0
	var guard = 0
	while runner.state != runner.State.DONE and guard < 300:
		guard += 1
		var track = conductor.track
		match runner.state:
			runner.State.WAVES:
				for e in get_nodes_in_group("enemies"):
					e.queue_free()
				await frames(2)
			runner.State.BOSS:
				runner.boss.die()
				bosses_beaten += 1
				await frames(2)
		await next_bar.call()
		if conductor.track != track:
			bar[0] = 0   # a new track restarts the clock
	check(runner.state == runner.State.DONE and bosses_beaten == Levels.count(), "full run: every planet and boss completed (bosses %d)" % bosses_beaten)
	conductor.time_override = -1.0
	await wait(4.0)
	check(current_scene.name == "Ending", "full run ends on the rescue screen")


# ---------------------------------------------------------------- memory / leaks

func _memory_tests():
	await _start_main()
	var conductor = root.get_node("Conductor")
	main.level_runner.stop()
	cat.is_invulnerable = true
	await wait(0.5)
	var nodes_before = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	# a busy fight: boss + two waves + skills, then clear everything
	var boss = Levels.create_boss(2)
	main.add_child(boss)
	for w in [3, 4]:
		for g in Levels.LEVELS[2].waves[w]:
			for e in Levels.create_group(g):
				main.add_child(e)
	await wait(1.0)
	var gestures = main.get_node("GestureInput")
	for skill in ["shockwave", "laser", "lightning"]:
		gestures.cast_skill(skill, true, Vector2.RIGHT)
		await wait(0.2)
	for g in ["enemies", "enemy_shots", "pickups"]:
		for n in get_nodes_in_group(g):
			n.queue_free()
	await wait(2.5)   # let explosions, popups and effects finish
	var nodes_after = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	check(nodes_after <= nodes_before, "no leftover nodes after a busy fight (%d -> %d)" % [nodes_before, nodes_after])
	check(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT) == 0, "no orphan nodes")
	# music track changes don't accumulate objects (after fades settle)
	conductor.play("level1")
	await wait(1.0)
	var objects_before = Performance.get_monitor(Performance.OBJECT_COUNT)
	for k in 12:
		conductor.play(["level1", "boss1", "level2"][k % 3])
		await wait(0.05)
	await wait(1.0)
	var growth = Performance.get_monitor(Performance.OBJECT_COUNT) - objects_before
	check(growth <= 4, "track changes don't leak objects (growth %d)" % growth)
	cat.is_invulnerable = false


# ---------------------------------------------------------------- Day 7: tutorial

func _load_main_with_tutorial():
	game.tutorial_mode = true
	change_scene_to_file("res://scenes/main.tscn")
	for i in 4:
		await process_frame
	main = current_scene
	cat = main.get_node("Shmitten")


func _tutorial_tests():
	var TutorialScript = load("res://scenes/tutorial.gd")
	var was_done = TutorialScript.is_done()   # restore the player's real setting afterwards
	var conductor = root.get_node("Conductor")

	await _load_main_with_tutorial()
	var tutorial = main.get_node_or_null("Tutorial")
	check(tutorial != null and tutorial.step == 0 and main.level_runner.state == main.level_runner.State.IDLE, "tutorial runs instead of a level")
	check(cat.is_invulnerable, "the cat can't be hurt in the tutorial")
	# 1: move
	cat.position += Vector2(300, 0)
	await process_frame
	cat.position += Vector2(-300, 0)
	await process_frame
	check(tutorial.step == 1, "step 1 completes after moving")
	# 2: three on-beat clicks (a miss doesn't count)
	game.register_judgement(conductor.Judgement.MISS)
	for i in 3:
		game.register_judgement(conductor.Judgement.GOOD)
	check(tutorial.step == 2, "step 2 completes after 3 on-beat clicks")
	# 3: hold fire through 4 beats
	Input.action_press("shoot")
	for n in 4:
		tutorial._on_beat(n)
	Input.action_release("shoot")
	check(tutorial.step == 3, "step 3 completes after holding fire for 4 beats")
	# 4: try the weapons (the one you hold counts)
	var others = [0, 1, 2].filter(func(w): return w != game.weapon)
	game.set_weapon(others[0])
	check(tutorial.step == 3, "one weapon switch isn't enough")
	game.set_weapon(others[1])
	check(tutorial.step == 4, "step 4 completes after trying all three weapons")
	game.set_weapon(game.Weapon.SPREAD)
	await frames(3)
	var practice = get_nodes_in_group("enemies")
	check(practice.size() == 6 and practice.all(func(e): return not e.marching), "practice mice appear and stay put")
	# 4: earn a charge
	game.add_charge(1)
	# process_frame fires *before* nodes' _process, so wait two frames
	await process_frame
	await process_frame
	check(tutorial.step == 5 and game.charges == game.MAX_CHARGES, "step 5 completes with a charge; step 6 gives free charges")
	check(tutorial.guide.focus_shape == "circle", "the spell step shows the shape to trace (circle first)")
	# 5: cast each skill in order (wrong order doesn't count)
	var gestures = main.get_node("GestureInput")
	gestures.cast_skill("laser", false, Vector2.RIGHT)
	check(tutorial.gesture_index == 0, "wrong gesture doesn't advance")
	for skill in ["shockwave", "laser", "lightning", "shield"]:
		gestures.cast_skill(skill, false, Vector2.RIGHT)
	check(tutorial.step == 6 and tutorial.practice_boss != null, "after the spells comes the spell-card step (a practice boss)")
	await frames(3)
	var trainer = tutorial.practice_boss
	trainer.entering = false
	await frames(2)
	trainer.card_intro = 0
	game.player_hit.emit("shot")   # got hit during the card: not captured
	trainer.take_damage(trainer.max_health)
	await frames(3)
	check(tutorial.step == 6 and tutorial.card_attempts == 1, "a card cleared after being hit doesn't count: try again")
	await frames(3)
	trainer = tutorial.practice_boss
	trainer.entering = false
	await frames(2)
	trainer.card_intro = 0
	trainer.take_damage(trainer.max_health)
	await frames(2)
	check(tutorial.step == 7, "capturing the practice spell card completes the tutorial")
	await wait(4.5)
	for i in 3:
		await process_frame
	check(not game.tutorial_mode and current_scene.level_runner.state == current_scene.level_runner.State.INTRO and game.level == 0, "after the tutorial, level 1 starts")
	check(TutorialScript.is_done(), "tutorial is remembered as done")

	# Tab skips straight to level 1
	await _load_main_with_tutorial()
	var tab = InputEventKey.new()
	tab.physical_keycode = KEY_TAB
	tab.pressed = true
	root.push_input(tab)
	for i in 4:
		await process_frame
	check(not game.tutorial_mode and current_scene.get_node_or_null("Tutorial") == null, "Tab skips the tutorial")

	# Start offers the tutorial only the first time
	var saved_choice = game.difficulty_chosen
	game.difficulty_chosen = true
	TutorialScript.set_done(false)
	change_scene_to_file("res://scenes/ui/title.tscn")
	for i in 3:
		await process_frame
	current_scene.start_game()
	for i in 4:
		await process_frame
	check(current_scene.get_node_or_null("Tutorial") != null, "first Start runs the tutorial")
	TutorialScript.set_done(true)
	change_scene_to_file("res://scenes/ui/title.tscn")
	for i in 3:
		await process_frame
	current_scene.start_game()
	for i in 4:
		await process_frame
	check(current_scene.get_node_or_null("Tutorial") == null, "later Starts go straight to level 1")
	TutorialScript.set_done(was_done)
	# first START asks for the difficulty once
	game.difficulty_chosen = false
	var saved_relaxed = game.relaxed_mode
	change_scene_to_file("res://scenes/ui/title.tscn")
	for i in 3:
		await process_frame
	current_scene.start_game()
	check(current_scene.get_node_or_null("DifficultyChoice") != null, "first START asks Relaxed / Normal")
	current_scene.choose_difficulty(true)
	for i in 4:
		await process_frame
	check(game.relaxed_mode and game.difficulty_chosen and current_scene.name == "Main", "choosing RELAXED saves it and starts the game")
	game.relaxed_mode = saved_relaxed
	game.difficulty_chosen = saved_choice
	game.clear_assist()
	game.tutorial_mode = false
	game.save_settings()
	game.tutorial_mode = false


# ---------------------------------------------------------------- tuning: checkpoints + assist

func _assist_tests():
	game.clear_assist()
	game.start_wave = 0
	await _start_main()
	var conductor = root.get_node("Conductor")
	var runner = main.level_runner
	check(is_equal_approx(game.shot_speed_factor(), 1.0), "level 1 enemy shots at x1.0")
	# reach wave 3 of level 1, then lose all lives
	conductor.time_override = 0.01
	runner.start_level(0, 2)
	check(runner.wave_index == 1 and runner.state == runner.State.INTRO, "starting from a checkpoint skips earlier waves")
	runner.state = runner.State.WAVES
	runner.wave_index = 2
	game.lives = 1
	cat.is_invulnerable = false
	cat.hit("shot")
	check(game.is_game_over and main.game_over_checkpoint == 2, "game over remembers the current wave")
	main.retry()
	for i in 4:
		await process_frame
	var retried = current_scene
	check(retried.level_runner.from_wave == 2 and game.assist == 1 and game.lives == game.START_LIVES + 1, "retry resumes at that wave with assist")
	check(is_equal_approx(game.shot_speed_factor(), 1.0 * (1.0 - game.ASSIST_SHOT_SLOWDOWN)), "assist slows enemy shots")
	for i in 5:
		game.add_assist()
	check(game.assist == game.MAX_ASSIST, "assist is capped")
	game.reset()
	check(game.lives == game.START_LIVES + 2, "assist lives are capped at +2")
	# boss checkpoint
	retried.level_runner.state = retried.level_runner.State.BOSS
	check(retried.level_runner.checkpoint() == Levels.LEVELS[0].waves.size(), "dying at the boss resumes at the boss")
	# a new level / new game clears the assist
	game.assist = 1
	retried.level_runner.state = retried.level_runner.State.CLEARED
	retried.level_runner.bars_to_wait = 1
	retried.level_runner._on_bar(0)
	check(game.assist == 0 and game.level == 1, "assist 1 carries over as 0 to the next level")
	game.assist = 3
	game.carry_assist()
	check(game.assist == 2 and game.warning_beats(2) == 3, "heavier assist carries over reduced; assisted warnings get +1 beat")
	game.clear_assist()
	game.start_wave = 0
	conductor.time_override = -1.0


func _rank_tests():
	check(Levels.rank(40, 45, 0.7, false) == "S", "rank S: under par, 70% perfect")
	check(Levels.rank(60, 45, 0.5, false) == "A", "rank A: within 1.5x par, 50% perfect")
	check(Levels.rank(200, 45, 0.9, false) == "B", "rank B: slow but no game over")
	check(Levels.rank(30, 45, 0.9, true) == "C", "rank C: cleared after a game over")


func _boss_assist_tests():
	await _start_main()
	await _clear_world()
	main.level_runner.stop()
	cat.is_invulnerable = true
	game.assist = 1
	var tank = await _make_boss("res://scenes/enemies/bosses/mecha_tank.gd")
	var full = tank.health
	tank.take_hit(10.0, Vector2.RIGHT, -1)
	check(is_equal_approx(tank.health, full - 7.5), "with assist, off-beat shots do 75% to bosses")
	game.assist = 2
	var shots = _count("enemy_shots")
	tank.fan(5, 12.0, 300.0)
	await frames(1)
	check(_count("enemy_shots") - shots == 3, "assist 2 thins boss fans (5 -> 3)")
	var assisted_tank = await _make_boss("res://scenes/enemies/bosses/mecha_tank.gd")
	check(is_equal_approx(assisted_tank.max_health, 380.0 * 0.7), "assist 2 cuts boss health by 30%")
	assisted_tank.queue_free()
	game.assist = 0
	tank.queue_free()
	cat.is_invulnerable = false


func _guardian_tests():
	await _start_main()
	main.level_runner.stop()
	game.assist = 0
	await wait(0.5)
	check(not cat.guardian_ready, "no guardian without assist or deaths")
	game.level_deaths = 2
	await wait(12.3)
	check(cat.guardian_ready, "early guardian after 2 deaths in the level (12 s)")
	cat.guardian_ready = false
	game.level_deaths = 0
	game.assist = 3
	await wait(5.3)
	check(cat.guardian_ready, "guardian charges after a game over (assist 3: 5 s)")
	var lives = game.lives
	check(not cat.hit("shot") and game.lives == lives and not cat.guardian_ready, "guardian absorbs one hit")
	game.assist = 0


func _fever_tests():
	await _start_main()
	await _clear_world()
	main.level_runner.stop()
	var conductor = root.get_node("Conductor")
	game.reset()
	for i in 15:
		game.register_judgement(conductor.Judgement.GOOD)
	check(not game.is_fever(), "no FEVER before 16 on-beat hits")
	game.register_judgement(conductor.Judgement.GOOD)
	check(game.is_fever() and game.fever_beats == game.FEVER_BEATS, "16 on-beat hits in a row start FEVER")
	var a = _spawn_grunt(Vector2(600, 300), 5)
	var b = _spawn_grunt(Vector2(700, 300), 5)
	await frames(2)
	var shot = PlayerShot.create(Vector2(500, 300), Vector2.RIGHT, 1.0)
	main.add_child(shot)
	await wait(0.35)
	var fever_hit = 1.5 * 1.3   # FEVER +50%, point-blank spread pellet x1.3
	check(is_equal_approx(a.health, 5.0 - fever_hit) and is_equal_approx(b.health, 5.0 - fever_hit), "FEVER shots pierce and do +50 percent (%.2f, %.2f)" % [a.health, b.health])
	for n in game.FEVER_BEATS:
		game._on_beat(n)
	check(not game.is_fever(), "FEVER ends after 8 beats")
	var normal = PlayerShot.create(Vector2(500, 300), Vector2.RIGHT, 1.0)
	check(not normal.pierce and normal.damage == 1.0, "normal shots again after FEVER")
	normal.free()


func _volley_rate_tests():
	var group = {"enemy": "grunt", "formation": "grid", "columns": 3, "rows": 2, "health": 1}
	var normal = Levels.create_group(group)
	var gentle = Levels.create_group(group, 0.5)
	check(normal[0].fire_slots == 3 and gentle[0].fire_slots == 6, "level 1 volley rate halves grunt fire frequency")
	for e in normal + gentle:
		e.free()


func _lead_note_tests():
	await _start_main()
	main.level_runner.stop()
	var conductor = root.get_node("Conductor")
	var notes = []
	conductor.lead_note.connect(func(pitch, length): notes.append([pitch, length]))
	conductor.time_override = 0.0
	conductor.play("level1", 2)
	# advance one full bar (8 eighth notes) of the first bar's melody
	conductor.time_override = 4 * conductor.seconds_per_beat - 0.01
	await process_frame
	await process_frame
	check(notes.size() == MusicPatterns.LEAD[0].size() and notes[0] == [MusicPatterns.LEAD[0][0][1], MusicPatterns.LEAD[0][0][2]], "Conductor emits the lead melody notes of bar 1 (%d)" % notes.size())
	conductor.time_override = -1.0


# ---------------------------------------------------------------- GTM iteration 1: settings, progress, endless

func _iteration1_tests():
	var saved = {"music": game.music_volume, "sfx": game.sfx_volume, "reduce": game.reduce_effects, "relaxed": game.relaxed_mode,
		"unlocked": game.unlocked_level, "story": game.story_complete, "best": game.best_scores.duplicate()}
	# settings persist. Writing is enabled only here: first reload the player's real values from
	# disk (earlier tests changed progress in memory), test, then write the real values back.
	game.persist = true
	game.load_settings()
	var real_music = game.music_volume
	game.music_volume = 0.3
	game.save_settings()
	game.music_volume = 0.9
	game.load_settings()
	check(is_equal_approx(game.music_volume, 0.3), "settings are saved and loaded")
	game.apply_settings()
	check(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))), 0.3), "music volume applies to the Music bus")
	game.music_volume = real_music
	game.save_settings()
	game.apply_settings()
	game.persist = false
	game.challenge = 0   # the reload above restored the player's own difficulty
	# reduce effects disables shake; relaxed mode keeps assist >= 1
	await _start_main()
	main.level_runner.stop()
	game.reduce_effects = true
	game.shake(15.0)
	await frames(2)
	check(main.position == Vector2.ZERO, "reduce effects disables screen shake")
	game.reduce_effects = false
	game.relaxed_mode = true
	game.clear_assist()
	check(game.assist == 1, "relaxed mode starts with assist 1")
	game.carry_assist()
	check(game.assist == 1, "relaxed mode never drops below assist 1")
	game.relaxed_mode = false
	game.clear_assist()
	# progress: clearing a level unlocks the next and records the best score
	game.unlocked_level = 0
	game.score = 1234
	game.record_level_clear(0)
	check(game.unlocked_level == 1 and game.best_scores.get("level1", 0) >= 1234, "level clear unlocks the next level and saves the best score")
	# endless waves scale up; bosses every 5th wave
	var e = load("res://scenes/levels/endless.gd")
	check(e.is_boss_wave(4) and not e.is_boss_wave(3) and e.stage(5) == 1, "endless: boss every 5 waves, music stage advances")
	check(e.wave_groups(10)[0].health > e.wave_groups(0)[0].health or e.wave_groups(10)[0].enemy != e.wave_groups(0)[0].enemy, "endless waves get tougher")
	game.endless_mode = true
	change_scene_to_file("res://scenes/main.tscn")   # not _start_main(): that stops the runner
	for i in 4:
		await process_frame
	main = current_scene
	# the intro can already be over: the track's "bar 0" counts as an intro bar (known off-by-one, harmless)
	check(main.level_runner.endless and main.level_runner.state != main.level_runner.State.IDLE, "endless mode starts from the title flag")
	game.endless_mode = false
	# restore the player's real settings and progress
	game.music_volume = saved.music
	game.sfx_volume = saved.sfx
	game.reduce_effects = saved.reduce
	game.relaxed_mode = saved.relaxed
	game.unlocked_level = saved.unlocked
	game.story_complete = saved.story
	game.best_scores = saved.best
	game.save_settings()
	game.apply_settings()


func _second_wind_tests():
	game.reset()
	game.level = 0
	var normal = game.shot_speed_factor()
	game.play_time = 100.0
	game.lose_life()
	check(not game.second_wind_active(), "one death: no Second Wind")
	game.play_time = 130.0
	game.lose_life()
	check(game.second_wind_active() and is_equal_approx(game.shot_speed_factor(), normal * 0.85), "2 deaths within 45 s: Second Wind slows shots 15 percent")
	game.play_time = 180.0
	check(not game.second_wind_active(), "Second Wind wears off after 45 s")
	game.reset()


func _spell_chain_tests():
	await _start_main()
	main.level_runner.stop()
	var conductor = root.get_node("Conductor")
	var gestures = main.get_node("GestureInput")
	var spb = conductor.seconds_per_beat
	conductor.time_override = 8 * spb + 0.01            # bar 2
	gestures.cast_skill("shield", false)
	check(gestures.chain == 0 and is_equal_approx(game.spell_power, 1.0), "first cast: no chain")
	conductor.time_override = 12 * spb + 0.01           # bar 3 (consecutive)
	gestures.cast_skill("shield", false)
	check(gestures.chain == 1 and is_equal_approx(game.spell_power, 1.25), "cast on the next bar chains (+25 percent)")
	conductor.time_override = 16 * spb + 0.01
	gestures.cast_skill("shield", false)
	conductor.time_override = 20 * spb + 0.01
	gestures.cast_skill("shield", false)
	conductor.time_override = 24 * spb + 0.01
	gestures.cast_skill("shield", false)
	check(gestures.chain == gestures.CHAIN_MAX, "chain caps at x%d" % (gestures.CHAIN_MAX + 1))
	conductor.time_override = 36 * spb + 0.01           # skipped bars
	gestures.cast_skill("shield", false)
	check(gestures.chain == 0, "skipping a bar breaks the chain")
	var wave = Shockwave.create(Vector2.ZERO, false)
	check(is_equal_approx(wave.damage, Shockwave.DAMAGE * game.spell_power), "skills use the chain power")
	wave.free()
	conductor.time_override = -1.0


# ---------------------------------------------------------------- playtest 2
func _shots() -> Array:
	return main.get_children().filter(func(n): return n.get_script() == PlayerShot)


func _playtest2_tests():
	await _start_main()
	main.level_runner.stop()
	await _clear_world()
	var gun = cat.get_node("Gun")
	cat.position = Vector2(300, 360)
	game.aim_override = Vector2(900, 360)

	# weapons: spread = streams, laser = one piercing bolt that scales with level, fish = homing
	game.gun_level = 3
	game.set_weapon(game.Weapon.SPREAD)
	var before = _shots().size()
	gun.fire(1.0)
	check(_shots().size() - before == 5, "spread fires 2 + gun level pellets")
	game.set_weapon(game.Weapon.LASER)
	before = _shots().size()
	gun.fire(1.0)
	var bolt = _shots()[-1]
	check(_shots().size() - before == 1 and bolt.pierce and is_equal_approx(bolt.damage, gun.LASER_BASE + 2 * gun.LASER_PER_LEVEL), "laser: one piercing bolt, damage grows with gun level")
	game.set_weapon(game.Weapon.FISH)
	before = _shots().size()
	gun.fire(1.0)
	check(_shots().size() - before == gun.FISH_COUNT[3] and _shots()[-1].kind == PlayerShot.Kind.FISH, "fish: homing shots, count by gun level")
	# a fish fired straight right curves toward a mouse above it
	await _clear_world()
	var target = load("res://scenes/enemies/grunt.tscn").instantiate()
	target.position = Vector2(560, 200)
	target.max_health = 50
	main.add_child(target)
	var fish = PlayerShot.create(Vector2(300, 360), Vector2.RIGHT, 0.1, -1, PlayerShot.Kind.FISH)
	main.add_child(fish)
	await frames(10)
	check(is_instance_valid(fish) and fish.velocity.y < -50.0, "fish home in on the nearest mouse")
	game.aim_override = null
	game.set_weapon(game.Weapon.SPREAD)
	game.cycle_weapon(1)
	check(game.weapon == game.Weapon.LASER, "Q/E cycle weapons")
	game.cycle_weapon(-2)
	check(game.weapon == game.Weapon.FISH, "cycling wraps around")
	game.set_weapon(game.Weapon.SPREAD)
	await _clear_world()

	# focus: slower movement and the hitbox is drawn
	cat.velocity = Vector2.ZERO
	game.focus_override = true
	Input.action_press("move_right")
	await frames(20)
	var focused_speed = cat.velocity.length()
	game.focus_override = false
	await frames(20)
	var normal_speed = cat.velocity.length()
	Input.action_release("move_right")
	check(focused_speed < normal_speed * 0.5 and normal_speed > 500.0, "focus (Shift) moves slower (%d vs %d)" % [focused_speed, normal_speed])
	game.focus_override = true
	await frames(2)
	await process_frame
	var marker = cat.get_node("FocusMarker")
	check(marker.visible and marker.z_index > cat.get_node("Sprite2D").z_index, "focus shows the hitbox above the cat sprite")
	game.focus_override = false
	var shift = InputEventKey.new()
	shift.physical_keycode = KEY_SHIFT
	shift.keycode = KEY_SHIFT
	shift.pressed = true
	Input.parse_input_event(shift)
	Input.flush_buffered_events()
	check(Input.is_action_pressed("focus"), "the Shift key triggers focus")
	shift.pressed = false
	Input.parse_input_event(shift)
	Input.flush_buffered_events()
	# snappy controls: from full speed right, reversing gets to full speed left within ~0.1 s
	Input.action_press("move_left")
	await frames(6)
	Input.action_release("move_left")
	check(cat.velocity.x < -400.0, "reversing direction is near-instant (%d)" % cat.velocity.x)
	cat.velocity = Vector2.ZERO
	cat.position = Vector2(300, 360)
	await frames(5)

	# stronger magnet: cheese 300 px away gets pulled in
	var cheese = Pickup.create(Pickup.Type.CHEESE, cat.position + Vector2(300, 0))
	main.add_child(cheese)
	var cheese_before = game.cheese + game.charges * game.CHEESE_PER_CHARGE
	await wait(0.8)
	check(game.cheese + game.charges * game.CHEESE_PER_CHARGE == cheese_before + 1, "the magnet pulls cheese from 300 px away")

	# dance break: clearing a wave starts it; on-beat taps give score + cheese; next wave ends it
	main.level_runner.state = main.level_runner.State.WAVES
	main.level_runner.alive = 1
	main.level_runner._on_enemy_gone()
	check(game.dancing, "clearing a wave starts a dance break")
	var score = game.score
	game.register_judgement(root.get_node("Conductor").Judgement.PERFECT)
	await frames(2)
	check(game.score > score and _count("pickups") >= 1, "an on-beat tap while dancing gives score and cheese")
	var far = Pickup.create(Pickup.Type.CHEESE, Vector2(1100, 100))
	main.add_child(far)
	await wait(1.2)
	check(not is_instance_valid(far), "during a dance break every pickup flies to the cat")
	main.level_runner._next_wave()
	check(not game.dancing, "the next wave ends the dance break")
	main.level_runner.stop()
	await _clear_world()

	# HUD message: first line big, the rest small and wrapped inside the screen
	main.hud.show_message("LEVEL 1 - MOUSE FACTORY\n" + "a very long story line that would have run off the screen before ".repeat(3))
	await frames(2)
	var body = main.hud.message_body
	check(main.hud.message_title.text == "LEVEL 1 - MOUSE FACTORY" and body.get_line_count() > 1, "long messages wrap onto several lines")
	check(body.get_global_rect().position.x >= 0 and body.get_global_rect().end.x <= 1280, "messages stay inside the screen")
	main.hud.hide_message()

	# spell guide: shows while drawing, lights up the shape being drawn
	var gestures = main.get_node("GestureInput")
	game.add_charge(1)
	gestures.begin(Vector2(400, 300))
	check(gestures.guide.panel, "the spell guide shows while drawing")
	for i in 41:
		gestures.add_point(Vector2(400, 300) + Vector2.from_angle(-PI / 2 + TAU * i / 40.0) * 80.0 + Vector2(0, 80))
	check(gestures.guide.matched == "circle", "the guide lights up the shape you're drawing (%s)" % gestures.guide.matched)
	gestures.cancel()
	check(not gestures.guide.panel, "the guide hides when drawing stops")
	game.gun_level = 1


# ---------------------------------------------------------------- playtest 3
func _formation() -> Array:
	var enemies = []
	for g in Levels.LEVELS[0].waves[1]:
		for e in Levels.create_group(g):
			e.position = e.slot_position
			e.slot_position = Vector2.INF
			e.max_health = 100
			e.drops = false
			main.add_child(e)
			enemies.append(e)
	return enemies


func _hurt(enemies: Array) -> int:
	return enemies.filter(func(e): return is_instance_valid(e) and e.health < 100).size()


func _playtest3_tests():
	await _start_main()
	main.level_runner.stop()
	await _clear_world()
	var gestures = main.get_node("GestureInput")
	var conductor = root.get_node("Conductor")
	cat.position = Vector2(220, 360)
	cat.is_invulnerable = true

	# draw where it hits: a circle drawn around the formation (cat far away on the left)
	var enemies = _formation()
	await frames(2)
	var circle = PackedVector2Array()
	for i in 33:
		circle.append(Vector2(1030, 360) + Vector2.from_angle(TAU * i / 32.0) * 150.0)
	gestures.cast_skill("shockwave", false, Vector2.RIGHT, circle)
	await frames(30)
	check(_hurt(enemies) >= 12, "a circle drawn around the mice bursts there (%d/16 hit)" % _hurt(enemies))
	await _clear_world()
	# a slightly tilted line drawn through a row still slashes along it
	enemies = _formation()
	await frames(2)
	var row_y = enemies[0].position.y
	gestures.cast_skill("laser", false, Vector2.RIGHT, PackedVector2Array([Vector2(800, row_y - 20), Vector2(1200, row_y + 20)]))
	await frames(10)
	check(_hurt(enemies) >= 4, "a line drawn through a row slashes along it (%d hit)" % _hurt(enemies))
	await _clear_world()
	# a zigzag over the formation strikes along it
	enemies = _formation()
	await frames(2)
	var zig = PackedVector2Array([Vector2(900, 250), Vector2(980, 470), Vector2(1060, 250), Vector2(1140, 470)])
	gestures.cast_skill("lightning", false, Vector2.RIGHT, zig)
	await frames(2)
	check(_hurt(enemies) >= 5, "a zigzag over the mice strikes along it (%d hit)" % _hurt(enemies))
	await _clear_world()

	# casting clears bullets on screen, some become cheese
	await wait(0.6)   # let the previous slash fade (it erases bullets too)
	for i in 5:
		main.add_child(EnemyShot.create(Vector2(560, 420 + i * 40), Vector2.LEFT, 10.0))
	await frames(1)
	gestures.cast_skill("shield", false)
	await frames(2)
	check(_count("enemy_shots") == 0 and _count("pickups") >= 5, "a spell turns the bullets on screen into cheese")
	await _clear_world()

	# snap assist: after 2 unrecognised strokes, a sloppy shape is accepted
	game.add_charge(3)
	var wobbly = PackedVector2Array()
	for i in 30:
		var a = TAU * i / 29.0 * 0.82
		wobbly.append(Vector2(500, 360) + Vector2.from_angle(a) * (90.0 + 30.0 * sin(a * 5.0)))
	var scribble = PackedVector2Array([Vector2(400, 300), Vector2(520, 310), Vector2(410, 330), Vector2(530, 420), Vector2(420, 300), Vector2(470, 450)])
	var r = gestures.recognizer.recognize(wobbly)
	gestures.fizzles_in_a_row = 0
	for k in 2:
		gestures.begin(scribble[0])
		for p in scribble:
			gestures.add_point(p)
		gestures.finish()
	check(gestures.fizzles_in_a_row >= 2, "unrecognised strokes count as fizzles in a row")
	if r.name == "" and r.score >= gestures.SNAP_MIN_SCORE:
		gestures.begin(wobbly[0])
		for p in wobbly:
			gestures.add_point(p)
		var snapped = gestures.finish()
		check(snapped.get("snapped", false), "after 2 fizzles a close-enough stroke snaps to its shape (%s %.2f)" % [r.best, r.score])
	else:
		check(true, "snap assist: test stroke was %s (%.2f), nothing to snap" % [r.name, r.score])
	await _clear_world()

	# spells hurt bosses for real: >= 7% of max health; armoured: crack 2 pips
	var boss = await _make_boss("res://scenes/enemies/bosses/mecha_tank.gd")
	var hp = boss.health
	boss.take_skill_damage(1.0)
	check(is_equal_approx(hp - boss.health, boss.max_health * boss.SKILL_MIN_FRACTION), "a spell takes at least 5% of a boss health")
	boss.take_damage(boss.health - boss.max_health * 0.4)
	boss.card_intro = 0
	boss.take_skill_damage(1.0, "shockwave")
	check(is_equal_approx(boss.armor, boss.ARMOR_PIPS - 2.0), "a circle or line cracks 2 pips of beat armour")
	boss.take_skill_damage(1.0, "lightning")
	check(boss.is_stunned() and boss.armor == 0.0, "SPELL BREAK: zigzag lightning shatters all the beat armour")
	boss.queue_free()
	await _clear_world()

	# spell cards: names, invulnerable intro, timer out -> next card without capture
	boss = await _make_boss("res://scenes/enemies/bosses/rat_king.gd")
	check(boss.cards.size() == 3 and boss.card == 0 and boss.cards[0].name != "", "King Ratbert has 3 named spell cards")
	boss.card_intro = 2
	hp = boss.health
	boss.take_hit(10.0, Vector2.RIGHT, conductor.Judgement.PERFECT)
	check(is_equal_approx(boss.health, hp), "a card's name intro is invulnerable")
	boss.card_intro = 0
	var ended = []
	boss.card_ended.connect(func(i, captured): ended.append([i, captured]))
	boss.card_time = 0.01
	await frames(3)
	check(boss.card == 1 and ended == [[0, false]] and is_equal_approx(boss.health, boss.max_health * 0.65), "timer out ends the card without a capture")
	boss.card_intro = 0
	var score = game.score
	boss.take_damage(boss.health - boss.card_floor)
	check(boss.card == 2 and ended[-1] == [1, true] and game.score >= score + boss.CAPTURE_SCORE, "clearing a card without getting hit captures it (+bonus)")
	boss.queue_free()
	await _clear_world()

	# bomb: spends every charge, clears bullets, protects, hits bosses
	game.charges = 0
	game.add_charge(3)
	var old_bullets = []
	for i in 4:
		old_bullets.append(EnemyShot.create(Vector2(600, 200 + i * 80), Vector2.LEFT, 10.0))
		main.add_child(old_bullets[-1])
	cat.is_invulnerable = false
	boss = await _make_boss("res://scenes/enemies/bosses/mecha_tank.gd")
	hp = boss.health
	check(gestures.bomb(), "the bomb goes off with charges")
	await frames(2)
	check(game.charges == 0 and old_bullets.all(func(b): return not is_instance_valid(b)) and cat.is_invulnerable, "the bomb spends all charges, clears bullets and protects the cat")
	check(is_equal_approx(hp - boss.health, boss.max_health * boss.BOMB_FRACTION * 3) and not boss.card_clean, "the bomb hits the boss (4% per charge) and fails the capture")
	check(not gestures.bomb(), "no bomb without charges")
	boss.queue_free()
	cat.is_invulnerable = true
	await _clear_world()

	# weapons: spread pellets fall off with distance and erase bullets
	var pellet = PlayerShot.create(Vector2(100, 360), Vector2.RIGHT, 1.0)
	check(is_equal_approx(pellet.damage_now(), pellet.POINT_BLANK), "spread pellets hit extra hard point-blank")
	pellet.position = Vector2(800, 360)
	check(is_equal_approx(pellet.damage_now(), pellet.FALLOFF_MIN), "spread pellets fall off with distance")
	pellet.free()
	var bullet = EnemyShot.create(Vector2(600, 360), Vector2.ZERO, 0.0)
	main.add_child(bullet)
	main.add_child(PlayerShot.create(Vector2(560, 360), Vector2.RIGHT, 1.0))
	await frames(6)
	check(not is_instance_valid(bullet), "spread pellets erase enemy bullets")
	var fresh = load("res://scripts/autoload/game.gd").new()
	check(fresh.weapon == game.Weapon.FISH, "fish is the default weapon")
	fresh.free()
	await _clear_world()

	# overdrive: banked at a 50 combo, F unleashes a 5 s beam that hits on the 8ths
	game.set_overdrive(0)
	game.reset_combo()
	for i in game.OVERDRIVE_COMBO:
		game.register_judgement(conductor.Judgement.PERFECT)
	check(game.overdrive == 1, "a 50 combo banks an overdrive")
	var target = load("res://scenes/enemies/grunt.tscn").instantiate()
	target.position = Vector2(700, 360)
	target.max_health = 500
	main.add_child(target)
	game.aim_override = Vector2(700, 360)
	check(cat.get_node("Gun").unleash_overdrive() and game.overdrive == 2, "F unleashes the overdrive")
	await wait(1.2)
	check(target.health < 500, "the overdrive beam hits what you aim at")
	await wait(game.OVERDRIVE_SECONDS)
	check(game.overdrive == 0, "the overdrive ends after 5 s")
	game.aim_override = null
	await _clear_world()

	# graze + freeze-and-scatter bullets
	var grazes = game.session.get("grazes", 0.0)
	score = game.score
	var near = EnemyShot.create(cat.global_position + cat.get_node("Hitbox").position + Vector2(200, 22), Vector2.LEFT, 400.0)
	main.add_child(near)
	await wait(0.8)
	check(game.session.get("grazes", 0.0) > grazes and game.score > score, "a bullet brushing past the cat counts as a graze")
	var frozen = EnemyShot.create(Vector2(900, 200), Vector2.LEFT, 200.0, EnemyShot.Kind.ORB).freeze(0.1, 0.2, 300.0, true)
	main.add_child(frozen)
	await wait(0.2)
	var held_still = frozen.position
	await wait(0.05)
	check(frozen.position == held_still, "freeze bullets stop in mid-air")
	await wait(0.2)
	var to_cat = (cat.global_position - frozen.global_position).normalized()
	check(frozen.velocity.normalized().dot(to_cat) > 0.95, "...then re-aim at the cat")
	await _clear_world()

	# beginner care: from the 2nd game over, Relaxed is offered in one key press
	game.assist = 1
	var was_relaxed = game.relaxed_mode
	game.relaxed_mode = false
	check(main.offers_relaxed(), "after a game over, Relaxed is offered")
	game.assist = 0
	check(not main.offers_relaxed(), "not offered on the first game over")
	game.relaxed_mode = was_relaxed
	cat.is_invulnerable = false


# ---------------------------------------------------------------- playtest 4
func _playtest4_tests():
	await _start_main()
	main.level_runner.stop()
	game.level = 2   # companions join from planet 2, mech parts from planet 3
	await _clear_world()
	var conductor = root.get_node("Conductor")
	cat.position = Vector2(220, 360)
	cat.is_invulnerable = true

	# companions join every 10 combo, zap on the beat, leave when the combo breaks
	var crew = main.companions
	conductor.beat.disconnect(crew._on_beat)   # drive the companions' beats by hand (no live beats)
	game.reset_combo()
	for i in 10:
		game.register_judgement(conductor.Judgement.PERFECT)
	check(crew.count() == 1, "a companion joins at 10 combo")
	for i in 20:
		game.register_judgement(conductor.Judgement.PERFECT)
	check(crew.count() == 3, "three companions at 30 combo")
	var target = load("res://scenes/enemies/grunt.tscn").instantiate()
	target.position = Vector2(700, 360)
	target.max_health = 50
	main.add_child(target)
	await frames(2)
	crew._on_beat(0)
	check(is_equal_approx(target.health, 50 - crew.ZAP_DAMAGE), "Pip zaps the nearest mouse on beat 1 (only Pip acts) (%.2f)" % target.health)
	cat.is_invulnerable = false
	cat.companion_bubble = false
	crew._on_beat(1)
	check(cat.companion_bubble and is_equal_approx(target.health, 50 - crew.ZAP_DAMAGE), "Nori gives the cat a one-hit bubble on beat 2")
	check(not cat.hit("shot") and not cat.companion_bubble and not cat.is_dead, "Nori's bubble absorbs one hit")
	var kiwi_at = crew.members[2].sprite.position
	var near_shot = EnemyShot.create(kiwi_at + Vector2(60, 0), Vector2.LEFT, 1.0)
	main.add_child(near_shot)
	await frames(1)
	crew._on_beat(3)
	await frames(1)
	check(not is_instance_valid(near_shot) and is_equal_approx(target.health, 50 - crew.ZAP_DAMAGE), "Kiwi's mini shockwave on beat 4 erases nearby bullets")
	cat.is_invulnerable = true
	game.register_judgement(conductor.Judgement.MISS)
	check(crew.count() == 0, "companions leave when the combo breaks")
	conductor.beat.connect(crew._on_beat)
	await _clear_world()

	# PERFECT laser crits
	var gun = cat.get_node("Gun")
	game.set_weapon(game.Weapon.LASER)
	game.gun_level = 1
	game.aim_override = Vector2(900, 360)
	game.fever_beats = 0   # the combo above triggered FEVER (+50%)
	gun.fire(2.0, conductor.Judgement.PERFECT)
	var bolt = _shots()[-1]
	check(bolt.crit and is_equal_approx(bolt.damage, 2.0 * gun.LASER_BASE * gun.LASER_CRIT), "a PERFECT laser shot is a critical hit (x1.5)")
	gun.fire(1.0, -1)
	check(not _shots()[-1].crit, "held laser shots don't crit")
	game.aim_override = null
	game.set_weapon(game.Weapon.SPREAD)
	await _clear_world()

	# challenge modes
	var saved = [game.challenge, game.relaxed_mode, game.hard_cleared]
	game.hard_cleared = false
	game.set_difficulty("touhou")
	check(game.challenge == game.Challenge.HARD, "TOUHOU stays locked until HARD is beaten")
	game.hard_cleared = true
	game.set_difficulty("touhou")
	check(game.is_touhou() and game.density() == 2.0, "TOUHOU doubles pattern density once unlocked")
	game.add_assist()
	check(game.assist == 0, "no assists on HARD/TOUHOU")
	var boss = load("res://scenes/enemies/bosses/mecha_tank.gd").new()
	boss.position = Vector2(1000, 360)
	boss.drops = false
	main.add_child(boss)
	await frames(2)
	check(is_equal_approx(boss.max_health, 380.0 * 2.0), "TOUHOU bosses have 2x health")
	var shots = _count("enemy_shots")
	boss.ring(10, 100.0)
	await frames(1)
	check(_count("enemy_shots") - shots == 20, "TOUHOU rings have twice the bullets")
	boss.queue_free()
	game.reset()
	check(game.bomb_stock == 1, "TOUHOU: a free bomb per life")
	game.set_difficulty("hard")
	check(game.challenge == game.Challenge.HARD and game.shot_speed_factor() > 1.0, "HARD: faster bullets")
	game.challenge = saved[0]
	game.relaxed_mode = saved[1]
	game.hard_cleared = saved[2]
	game.reset()
	await _clear_world()

	# overdrive hits hard
	var beam_script = load("res://scenes/player/overdrive_beam.gd")
	check(beam_script.TICK_DAMAGE >= 8.0, "overdrive ticks hit hard (%.0f)" % beam_script.TICK_DAMAGE)
	cat.is_invulnerable = false


func _story_tests():
	# every NEW GAME opens with the story, then the game starts
	game.skip_intro = false
	game.difficulty_chosen = true
	change_scene_to_file("res://scenes/ui/title.tscn")
	for i in 3:
		await process_frame
	current_scene.start_game()
	for i in 4:
		await process_frame
	check(current_scene.name == "IntroStory", "the opening story plays before the first game")
	for i in 5:
		current_scene.next()
	for i in 4:
		await process_frame
	check(current_scene.name == "Main", "after the story, the game starts")
	game.skip_intro = true
	main = current_scene
	cat = main.get_node("Shmitten")
	main.level_runner.stop()
	# the planet map between levels has home + every planet
	var card = load("res://scenes/ui/transition_card.gd").create(0, "A", 60, 50)
	main.add_child(card)
	await frames(1)
	check(card._stops() == Levels.count() + 1 and card._stop_name(0) == "PISITANIA" and card._stop_name(Levels.count()) == "FLEXOR", "the map runs from Pisitania to Flexor")
	card.queue_free()
	check(main.backdrop != null and main.hud._planet() == Levels.LEVELS[game.level].title, "each level has its planet (backdrop + HUD name)")
	# Sho's patterns: rose, rain curtain with a safe column
	var sho = load("res://scenes/enemies/bosses/sho.gd").new()
	sho.position = Vector2(1000, 360)
	sho.drops = false
	main.add_child(sho)
	await frames(2)
	var shots = _count("enemy_shots")
	sho.curtain(12, 150.0, 400.0)
	await frames(1)
	var rain = get_nodes_in_group("enemy_shots").slice(shots)
	check(rain.size() >= 8 and rain.all(func(e): return absf(e.position.x - 400.0) >= 70.0 and e.velocity.y > 0.0), "protein rain falls from the top and leaves a safe column")
	shots = _count("enemy_shots")
	sho.rose(18, 190.0, 5)
	await frames(1)
	var bloom = get_nodes_in_group("enemy_shots").slice(shots)
	var speeds = bloom.map(func(e): return e.velocity.length())
	check(bloom.size() == 18 and speeds.max() > speeds.min() * 1.5, "a rose blooms: bullet speeds vary around the ring")
	sho.queue_free()
	await _clear_world()


# ---------------------------------------------------------------- playtest 5
func _playtest5_tests():
	await _start_main()
	main.level_runner.stop()
	game.level = 2   # companions join from planet 2, mech parts from planet 3
	await _clear_world()
	var conductor = root.get_node("Conductor")
	var gestures = main.get_node("GestureInput")
	cat.position = Vector2(220, 360)
	cat.is_invulnerable = true

	# bombs: one per planet and they need 2 charges
	game.bomb_stock = 0
	game.bomb_used_this_level = false
	game.charges = 1
	check(not gestures.bomb(), "no bomb with only 1 charge")
	game.charges = 3
	check(gestures.bomb(), "a bomb with 2+ charges")
	game.charges = 3
	check(not gestures.bomb(), "only one bomb per planet")
	game.set_level(1, 5)
	check(gestures.bomb(), "a new planet gives a new bomb")
	cat.is_invulnerable = true
	await _clear_world()

	# boss bullets pulse with the beat
	var boss = await _make_boss("res://scenes/enemies/bosses/mecha_tank.gd")
	var shots = _count("enemy_shots")
	boss.ring(6, 100.0)
	await frames(1)
	var ringed = get_nodes_in_group("enemy_shots").slice(shots)
	check(ringed.size() > 0 and ringed.all(func(e): return e.pulse), "boss bullets pulse with the music")
	# armoured cards stream on the hi-hats
	boss.take_damage(boss.health - boss.max_health * 0.4)
	boss.card_intro = 0
	await frames(2)   # bullets cleared at the card change finish freeing
	shots = _count("enemy_shots")
	boss._on_eighth(3)
	boss._on_eighth(4)
	await frames(1)
	check(_count("enemy_shots") - shots == 1, "armoured cards fire on the off-beat hi-hat only")
	boss.queue_free()
	await _clear_world()

	# mech parts -> mech core -> mech suit
	game.level = 2
	game.mech_parts = 0
	game.mech_used_this_level = false
	var cores = [0]
	game.mech_core_ready.connect(func(): cores[0] += 1)
	for i in game.MECH_PARTS_NEEDED - 1:
		game.add_mech_part("test")
	check(game.mech_parts == game.MECH_PARTS_NEEDED - 1 and cores[0] == 0, "mech parts add up")
	game.add_mech_part("test")
	await frames(2)
	check(cores[0] == 1 and game.mech_parts == 0 and get_nodes_in_group("pickups").any(func(p): return p.type == Pickup.Type.MECH_CORE), "4 parts drop a MECH CORE")
	for i in game.MECH_PARTS_NEEDED + 2:
		game.add_mech_part("test")
	check(cores[0] == 1 and game.mech_parts == game.MECH_PARTS_NEEDED - 1, "only one mech per planet: parts wait at 3/4")
	game.set_level(2, 5)
	game.add_mech_part("test")
	check(cores[0] == 2, "...and the next planet releases the next core")
	game.reset_combo()
	for i in game.MECH_COMBO:
		game.register_judgement(conductor.Judgement.PERFECT)
	check(game.mech_parts == 1, "a 75 combo earns a mech part")
	game.mech_parts = 0
	await _clear_world()
	cat.start_mech()
	check(cat.is_mech() and cat.mech_armor == cat.MECH_ARMOR, "the core turns the cat into MECHA-MEOW")
	game.aim_override = Vector2(900, 360)
	var before = _shots().size()
	cat.get_node("Gun").fire(1.0)
	check(_shots().size() - before == 1 and _shots()[-1].damage >= 3.0 and _shots()[-1].pierce, "the mech fires a heavy piercing beam rifle")
	var dummy = load("res://scenes/enemies/grunt.tscn").instantiate()
	dummy.position = cat.global_position + Vector2(120, 0)
	dummy.max_health = 50
	main.add_child(dummy)
	await frames(1)
	check(cat.get_node("Gun").saber_slash() == 1 and dummy.health < 50, "the beam saber slashes mice in front of the mech")
	dummy.queue_free()
	await frames(1)
	cat.is_invulnerable = false
	check(not cat.hit("shot") and cat.mech_armor == cat.MECH_ARMOR - 1 and not cat.is_dead, "mech armour absorbs hits")
	for p in get_nodes_in_group("pickups"):
		p.free()   # stray mech cores from the tests above would restart the mech
	cat.mech_time = 0.01
	await frames(3)
	check(not cat.is_mech() and cat.sprite.hframes == 10, "the mech wears off and the cat hops out")
	game.aim_override = null
	cat.is_invulnerable = false
	await _clear_world()
	# gags: bosses quip at every spell card, mice and the cat chat
	var banter = main.banter
	var quip_boss = await _make_boss("res://scenes/enemies/bosses/sho.gd")
	var bubbles = banter.bubbles.size()
	banter.boss_card(quip_boss, 0)
	check(banter.bubbles.size() == bubbles + 1 and banter.text_of(banter.bubbles[-1][0]) == "Do you even lift, kitty?", "Sho quips at his first spell card")
	quip_boss.queue_free()
	game.reset_combo()
	bubbles = banter.bubbles.size()
	for i in 10:
		game.register_judgement(conductor.Judgement.PERFECT)
	check(banter.bubbles.size() > bubbles and Banter_lines_has(banter.text_of(banter.bubbles[-1][0])), "the cat makes a pun every 10 combo")
	game.reset_combo()
	await _clear_world()

	# spell captures: a card captured with a drawn spell gives a mech part; without one it doesn't
	game.mech_parts = 0
	game.mech_used_this_level = false
	var capt = await _make_boss("res://scenes/enemies/bosses/rat_king.gd")
	capt.take_damage(capt.health - capt.card_floor)
	check(game.mech_parts == 0 and capt.card == 1, "capturing without a spell gives no mech part")
	capt.card_intro = 0
	capt.take_skill_damage(1.0)
	capt.take_damage(capt.health - capt.card_floor)
	check(game.mech_parts == 1, "capturing a card you hit with a spell gives a mech part")
	capt.queue_free()
	await _clear_world()
	# spread eats bullets into cheese
	var cheese_before = game.cheese + game.charges * game.CHEESE_PER_CHARGE
	game.charges = 0
	game.cheese = 0
	for i in game.BULLETS_PER_CHEESE:
		game.eat_bullet()
	check(game.cheese == 1, "spread pellets eat bullets: every 3 = 1 cheese")
	# playtest 7 spell roles: weak-to spell x2, short slash, zigzag x3 on shield mice
	var weak_boss = await _make_boss("res://scenes/enemies/bosses/mecha_tank.gd")
	var hp0 = weak_boss.health
	weak_boss.take_skill_damage(1.0, "shockwave")
	var plain_hit = hp0 - weak_boss.health
	hp0 = weak_boss.health
	weak_boss.take_skill_damage(1.0, weak_boss.weak_spell())
	check(weak_boss.weak_spell() == "laser" and is_equal_approx(hp0 - weak_boss.health, plain_hit * 2.0), "each card is weak to one spell (x2)")
	weak_boss.queue_free()
	var slash = load("res://scenes/gestures/skills/laser_beam.gd").slash(Vector2(600, 300), Vector2(700, 300), false)
	check(slash.distance_to_beam(Vector2(950, 300)) < INF and slash.distance_to_beam(Vector2(1100, 300)) == INF, "a drawn slash reaches 300 px each way, not the whole screen")
	slash.free()
	var shielded = load("res://scenes/enemies/shield_mouse.tscn").instantiate()
	shielded.position = Vector2(900, 200)
	shielded.max_health = 100
	main.add_child(shielded)
	await frames(1)
	shielded.take_skill_damage(5.0, "lightning")
	check(is_equal_approx(shielded.max_health - shielded.health, 15.0), "zigzag lightning does x3 to shield mice (%.1f of %.1f)" % [shielded.health, shielded.max_health])
	shielded.queue_free()
	game.level = 0
	game.reset_combo()
	for i in 10:
		game.register_judgement(conductor.Judgement.PERFECT)
	check(main.companions.count() == 0, "no companions on planet 1 (one new system at a time)")
	game.mech_parts = 0
	game.add_mech_part("test")
	check(game.mech_parts == 0, "no mech parts before planet 3")
	game.reset_combo()
	game.level = 2
	await _clear_world()

func Banter_lines_has(text: String) -> bool:
	return load("res://scenes/ui/banter.gd").CAT_COMBO.has(text)


# ---------------------------------------------------------------- designer-7 iteration
func _designer7_tests():
	var conductor = root.get_node("Conductor")
	var saved_offset = conductor.offset_ms
	conductor.offset_ms = 0.0
	var cal = load("res://scenes/ui/calibration.gd").new()
	root.add_child(cal)
	await process_frame
	for i in cal.TAPS_NEEDED - 1:
		cal.tap(0.04 if i % 2 == 0 else 0.05)
	cal.tap(0.9)   # an outlier is ignored
	check(not cal.finished, "rhythm check ignores outlier taps")
	cal.tap(0.045)
	check(cal.finished and absf(conductor.offset_ms - 45.0) <= 5.5, "rhythm check sets the beat offset from the median tap error (%.0f ms)" % conductor.offset_ms)
	cal.queue_free()
	conductor.set_offset_ms(saved_offset)
	check(is_equal_approx(conductor.perfect_window(), conductor.PERFECT_WINDOW + (conductor.WEB_EXTRA if OS.has_feature("web") else 0.0)), "the PERFECT window is wider only on the web")
	# content pass: mid-boss patterns, splitter, bomber, planet challenges
	await _start_main()
	main.level_runner.stop()
	await _clear_world()
	cat.position = Vector2(220, 360)
	cat.is_invulnerable = true
	var jr = await _make_boss("res://scenes/enemies/bosses/tanky_jr.gd")
	jr.card = 1
	var shots = _count("enemy_shots")
	jr.on_hat(1)
	await frames(1)
	check(_count("enemy_shots") - shots == 1, "Tanky Jr.'s Baby Snake streams on the hi-hats")
	jr.queue_free()
	var guard = await _make_boss("res://scenes/enemies/bosses/royal_guard.gd")
	guard.card = 1
	shots = _count("enemy_shots")
	guard.on_beat(0)
	await frames(1)
	var pincer = get_nodes_in_group("enemy_shots").slice(shots)
	check(pincer.any(func(e): return e.velocity.y > 0) and pincer.any(func(e): return e.velocity.y < 0), "Royal Guard's pincer closes from top and bottom")
	guard.queue_free()
	await _clear_world()
	var sp = load("res://scenes/enemies/splitter.tscn").instantiate()
	sp.position = Vector2(900, 360)
	sp.drops = false
	main.add_child(sp)
	await frames(1)
	var before = _count("enemies")
	sp.die()
	await frames(2)
	check(get_nodes_in_group("enemies").filter(func(e): return e.get_script() == sp.get_script() and e.is_mini).size() == 2, "a splitter pops into 2 minis")
	await _clear_world()
	var bomb_mouse = load("res://scenes/enemies/bomber.tscn").instantiate()
	bomb_mouse.position = Vector2(900, 200)
	main.add_child(bomb_mouse)
	await frames(1)
	bomb_mouse.on_beat(0)
	await frames(1)
	var bombs = get_nodes_in_group("enemy_shots").filter(func(e): return e.burst_ring > 0)
	check(bombs.size() == 1, "the beat-bomber drops a bomb")
	shots = _count("enemy_shots")
	bombs[0]._burst(1)
	await frames(1)
	check(_count("enemy_shots") - shots >= 7, "the bomb bursts into a ring on the downbeat")
	bomb_mouse.queue_free()
	await _clear_world()
	game.set_level(0, 8)
	game.level_cards_met = 2
	game.level_cards_captured = 2
	for sk in ["shockwave", "laser", "lightning", "shield"]:
		game.level_spells[sk] = true
	var res = game.challenge_results()
	check(res.no_hit and res.all_cards and res.all_spells, "challenges: no hits, every card captured, all 4 spells")
	var saved_records = game.planet_records.duplicate(true)
	game.record_planet(0, "A")
	check(game.stars(0) == 3 and game.planet_records.level1.rank in ["A", "S"], "a planet record keeps the best rank and the stars")
	game.planet_records = saved_records
	cat.is_invulnerable = false
	# rank: tougher mice when the gun is stronger
	game.gun_level = 5
	var tough = load("res://scenes/enemies/grunt.tscn").instantiate()
	tough.max_health = 10
	main.add_child(tough)
	await frames(1)
	check(is_equal_approx(tough.max_health, 10 * (1 + 4 * game.RANK_PER_GUN_LEVEL)), "rank: mice are tougher when your gun is stronger (%.1f)" % tough.max_health)
	tough.queue_free()
	game.gun_level = 1
	# presentation: per-planet melodies, portraits, hit-pause
	var MP = load("res://scripts/music_patterns.gd")
	check(MP.lead("level1") != MP.lead("level2") and MP.lead("level3") != MP.lead("level4"), "every planet has its own melody")
	check(MP.lead("boss1")[0].size() == MP.lead("level1")[0].size(), "each boss plays a variation of its planet's motif")
	var q = await _make_boss("res://scenes/enemies/bosses/sho.gd")
	main.banter.boss_card(q, 0)
	check(main.banter.bubbles[-1][0].find_children("*", "TextureRect", true, false).size() == 1, "speech bubbles show the speaker's portrait")
	q.queue_free()
	game.reduce_effects = false
	game.drawing = false
	Engine.time_scale = 1.0
	game.hit_pause(0.05)
	check(Engine.time_scale < 0.1, "hit-pause freezes the action on big impacts")
	await create_timer(0.12, true, false, true).timeout
	check(is_equal_approx(Engine.time_scale, 1.0), "...for a moment only")
	await _clear_world()
	# GTM: gamepad mappings, feedback links, demo flag
	var pad_ok = true
	for action in ["move_up", "move_left", "shoot", "focus", "weapon_next", "bomb", "overdrive", "pause", "draw", "aim_left", "aim_up"]:
		if not InputMap.action_get_events(action).any(func(e): return e is InputEventJoypadButton or e is InputEventJoypadMotion):
			pad_ok = false
	check(pad_ok, "every action has a gamepad binding (sticks, buttons, LT to draw)")
	check(game.FEEDBACK_URL.begins_with("https://github.com/") and game.BUG_URL.contains("bug_report"), "feedback and bug-report links point at the issue templates")
	check(not game.is_demo(), "the desktop build is not the demo")

