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
	Levels = load("res://scenes/levels/levels.gd")
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

	# --- the level restarts (intro first, then waves)
	await frames(5)
	check(current_scene.level_runner.state == current_scene.level_runner.State.INTRO, "level restarts after retry")

	await _rhythm_tests()
	await _gesture_tests()
	await _rhythm_loop_tests()
	await _enemy_tests()
	await _level_tests()

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
	check(held.size() - before == game.gun_level and held[-1].judgement == -1 and is_equal_approx(held[-1].damage, 1.0), "held fire shoots on the beat (1.0 dmg, unjudged)")
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
	check(shots.size() == shots_before + 1, "gunner fires on the downbeat")
	if shots.size() > 0:
		var aim = shots[-1].velocity.normalized()
		check(aim.dot((cat.global_position - gunner.global_position).normalized()) > 0.99, "gunner shot is aimed at the cat")

	# dasher: lines up with the cat, then charges on a downbeat after one bar
	var dasher = load("res://scenes/enemies/dasher.tscn").instantiate()
	dasher.position = Vector2(1150, 200)
	main.add_child(dasher)
	await frames(2)
	for n in range(1, 4):
		dasher._on_conductor_beat(n)
		await wait(0.15)
	check(dasher.position.y > 300 and not dasher.dashing, "dasher slides toward the cat's height")
	dasher._on_conductor_beat(4)
	check(dasher.dashing, "dasher charges on the downbeat after a bar")
	var x0 = dasher.position.x
	await wait(0.2)
	check(dasher.position.x < x0 - 100, "dasher moves fast when charging")

	# shield mouse: plate blocks off-beat frontal shots; beat, angle and skills get through
	var conductor = root.get_node("Conductor")
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

	# drive the music bar by bar and clear each wave by force
	var spb = conductor.seconds_per_beat
	var bar = [0]
	var next_bar = func():
		bar[0] += 1
		conductor.time_override = bar[0] * 4 * spb + 0.01
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
	check(runner.state == runner.State.CLEARED, "level is cleared after its last wave")
	await next_bar.call()
	await next_bar.call()
	check(game.level == 1 and conductor.track == "level2", "level 2 starts with its own music (%s)" % conductor.track)
	conductor.time_override = -1.0
