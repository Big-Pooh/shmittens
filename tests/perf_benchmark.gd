extends SceneTree

# Frame-time + memory benchmark under deliberately heavy load (needs a real window, not --headless):
#   ~/Desktop/Godot_v4.7.2.app/Contents/MacOS/Godot --path . -s tests/perf_benchmark.gd
# Final boss enraged + 2 extra waves + constant skills and gunfire for 6 seconds.
# Prints average/worst frame time, peak node count, static memory, and leftovers after clearing.

func _initialize(): run.call_deferred()
func objs(): return Performance.get_monitor(Performance.OBJECT_COUNT)
func nodes(): return Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
func mem_mb(): return Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
func run():
	change_scene_to_file("res://scenes/main.tscn")
	for i in 30: await process_frame
	var main = current_scene
	var c = root.get_node("Conductor")
	main.level_runner.stop()
	# 1) track changes: do objects accumulate?
	var o0 = objs()
	for k in 20:
		c.play(["level1", "boss1", "level2"][k % 3])
		for i in 5: await process_frame
	await create_timer(1.0).timeout   # let the 0.4 s layer fades finish
	print("track changes x20: objects %d -> %d (delta %d)" % [o0, objs(), objs() - o0])
	# 2) heavy load: final boss phase 2 + 2 waves + skills, measure frame times
	main.player.is_invulnerable = true
	var n0 = nodes()
	var L = load("res://scenes/levels/levels.gd")
	var boss = L.create_boss(2)
	boss.slot_position = Vector2(1060, 360)
	main.add_child(boss)
	for w in [3, 4]:
		for g in L.LEVELS[2].waves[w]:
			for e in L.create_group(g): main.add_child(e)
	for i in 120: await process_frame
	boss.take_damage(boss.max_health * 0.55)
	var g = main.get_node("GestureInput")
	var worst = 0.0
	var total = 0.0
	var frames = 0
	var t_end = Time.get_ticks_msec() + 6000
	var last = Time.get_ticks_usec()
	var peak_nodes = 0
	while Time.get_ticks_msec() < t_end:
		await process_frame
		var now = Time.get_ticks_usec()
		var dt = (now - last) / 1000.0
		last = now
		worst = max(worst, dt); total += dt; frames += 1
		peak_nodes = max(peak_nodes, nodes())
		if frames % 40 == 0:
			g.cast_skill(["shockwave", "laser", "lightning"][(frames / 40) % 3], true, Vector2.RIGHT)
		if frames % 10 == 0:
			main.player.get_node("Gun").fire(1.0)
	print("heavy load 6s: avg %.1f ms/frame (%.0f fps), worst frame %.1f ms, peak nodes %d, static mem %.1f MB" % [total / frames, 1000.0 * frames / total, worst, peak_nodes, mem_mb()])
	# 3) clean-up: everything spawned should be freed
	for e in get_nodes_in_group("enemies"): e.queue_free()
	for e in get_nodes_in_group("enemy_shots"): e.queue_free()
	for e in get_nodes_in_group("pickups"): e.queue_free()
	await create_timer(2.5).timeout
	print("after clearing: nodes %d (baseline %d), orphan nodes %d" % [nodes(), n0, Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)])
	quit()
