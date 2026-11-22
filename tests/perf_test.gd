extends SceneTree
# SPRINT 7 performance check: BULLET HELL worst case - a boss fight with ~600 bullets alive.
# Runs headless with the real game scripts; reports the average and worst physics+process time
# per frame. Usage: Godot --headless -s tests/perf_test.gd   (prints PERF lines)

func _initialize():
	var game = root.get_node("Game")
	game.persist = false
	game.skip_intro = true
	game.challenge = 2
	game.hard_cleared = true
	change_scene_to_file("res://scenes/main.tscn")
	create_timer(0.5).timeout.connect(_run)


func _run():
	var main = current_scene
	main.level_runner.stop()
	main.get_node("Shmitten").is_invulnerable = true
	var boss = load("res://scenes/enemies/bosses/sho_max.gd").new()
	boss.position = Vector2(1060, 360)
	main.add_child(boss)
	for i in int(OS.get_environment("PERF_BULLETS") if OS.get_environment("PERF_BULLETS") != "" else "600"):
		var shot = load("res://scenes/enemies/enemy_shot.gd").create(Vector2(200 + randf() * 900, 40 + randf() * 640), Vector2.from_angle(randf() * TAU), 20.0, i % 3)
		shot.pulse = true
		main.add_child(shot)
	await process_frame
	var times = []
	var peak = 0
	for f in int(OS.get_environment("PERF_FRAMES") if OS.get_environment("PERF_FRAMES") != "" else "240"):
		peak = max(peak, get_nodes_in_group("enemy_shots").size())
		await process_frame
		# the game's own CPU time per frame (scripts + physics), not the 60 fps frame pacing
		times.append((Performance.get_monitor(Performance.TIME_PROCESS) + Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0)
	times.sort()
	var avg = times.reduce(func(a, b): return a + b, 0.0) / times.size()
	print("PERF bullets_peak=%d avg_ms=%.2f p95_ms=%.2f max_ms=%.2f" % [peak, avg, times[int(times.size() * 0.95)], times[-1]])
	quit()
