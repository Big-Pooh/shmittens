extends Node

# Automated player for persona playthroughs (tests/playthrough.gd). Drives the real game:
# WASD via Input actions, aim via Game.aim_override, clicks via Gun.click() at planned times
# around the beat, held fire via the "shoot" action, gestures via GestureInput begin/add/finish.
# Personas differ in timing accuracy, reaction, dodging, pickup greed and gesture skill.
# Dodging calibrated to playtest 1 (a human "could dodge everything easily" where the old average
# bot died ~2x per minute): dodge chance noob 0.7 / average 0.95 / speedrunner 0.99.

const PERSONAS = {
	"noob": {
		"timing_sigma": 0.13, "timing_bias": 0.06, "click_prob": 0.35, "spam_per_sec": 1.2,
		"hold_prob": 0.55, "reaction": 0.40, "dodge_chance": 0.7, "pickup_radius": 150.0,
		"aim_error": 45.0, "home_x": 220.0, "gesture_min_charges": 2, "gesture_noise": 0.16,
		"gesture_mess_chance": 0.25, "draw_time": 1.3, "release_on_beat": false, "release_sigma": 0.2,
	},
	"average": {
		"timing_sigma": 0.06, "timing_bias": 0.02, "click_prob": 0.75, "spam_per_sec": 0.3,
		"hold_prob": 0.25, "reaction": 0.22, "dodge_chance": 0.95, "pickup_radius": 320.0,
		"aim_error": 15.0, "home_x": 260.0, "gesture_min_charges": 1, "gesture_noise": 0.07,
		"gesture_mess_chance": 0.05, "draw_time": 0.8, "release_on_beat": true, "release_sigma": 0.07,
	},
	"speedrunner": {
		"timing_sigma": 0.025, "timing_bias": 0.0, "click_prob": 0.98, "spam_per_sec": 0.0,
		"hold_prob": 0.05, "reaction": 0.12, "dodge_chance": 0.99, "pickup_radius": 450.0,
		"aim_error": 5.0, "home_x": 420.0, "gesture_min_charges": 1, "gesture_noise": 0.04,
		"gesture_mess_chance": 0.0, "draw_time": 0.5, "release_on_beat": true, "release_sigma": 0.03,
	},
}
const DANGER_RADIUS = 46.0
const HORIZON = 0.9

var persona_name = "average"
var p: Dictionary
var rng = RandomNumberGenerator.new()
var stats: Dictionary   # shared with the runner

var cat: Shmitten
var gun
var gestures: GestureInput
var seen_threats = {}       # instance_id -> [first_seen_time, will_react]
var planned_clicks = []     # song times
var holding = false
var hold_until = 0.0
var aim_jitter = Vector2.ZERO
var jitter_timer = 0.0
var stroke = PackedVector2Array()
var stroke_index = 0
var drawing_skill = ""
var release_at = -1.0
var sim_time = 0.0


# persona = "noob" | "average" | "speedrunner" | "skill:<0..1>" (blend: 0 = noob, 0.5 = average, 1 = speedrunner)
func setup(persona: String, seed_value: int, shared_stats: Dictionary):
	persona_name = persona
	if persona.begins_with("skill:"):
		p = blend(float(persona.substr(6)))
	else:
		p = PERSONAS[persona]
	rng.seed = seed_value
	stats = shared_stats


static func blend(skill: float) -> Dictionary:
	skill = clamp(skill, 0.0, 1.0)
	var lo = PERSONAS.noob if skill < 0.5 else PERSONAS.average
	var hi = PERSONAS.average if skill < 0.5 else PERSONAS.speedrunner
	var t = skill * 2.0 if skill < 0.5 else (skill - 0.5) * 2.0
	var out = {}
	for key in lo:
		if typeof(lo[key]) == TYPE_BOOL:
			out[key] = hi[key] if t >= 0.5 else lo[key]
		elif typeof(lo[key]) == TYPE_INT:
			out[key] = int(round(lerp(float(lo[key]), float(hi[key]), t)))
		else:
			out[key] = lerp(lo[key], hi[key], t)
	return out


func _ready():
	var scene = get_tree().current_scene
	cat = scene.get_node("Shmitten")
	gun = cat.get_node("Gun")
	gestures = scene.get_node("GestureInput")
	Conductor.beat.connect(_on_beat)
	gestures.cast.connect(func(skill, empowered): _stat("casts", 1); _stat("empowered", 1 if empowered else 0))
	gestures.fizzled.connect(func(reason): _stat("fizzles", 1); _stat("fizzle_" + reason, 1))


func _exit_tree():
	for action in ["move_up", "move_down", "move_left", "move_right", "shoot"]:
		Input.action_release(action)
	Game.aim_override = null


func _stat(key: String, amount: int):
	stats[key] = stats.get(key, 0) + amount


func _on_beat(n: int):
	var t = (n + 1) * Conductor.seconds_per_beat
	if rng.randf() < p.click_prob:
		planned_clicks.append(t + rng.randfn(p.timing_bias, p.timing_sigma))
	# sometimes hold the button for a few beats instead of clicking
	if not holding and rng.randf() < p.hold_prob * 0.25:
		holding = true
		hold_until = sim_time + Conductor.seconds_per_beat * rng.randi_range(2, 6)


func _physics_process(delta):
	if cat.is_dead or Game.is_game_over:
		_release_all()
		return
	var real_delta = delta / max(Engine.time_scale, 0.01)
	sim_time += real_delta
	var target = _pick_target()
	_aim(target, real_delta)
	_move(target)
	_shoot(real_delta)
	_gesture(target)


func _release_all():
	for action in ["move_up", "move_down", "move_left", "move_right", "shoot"]:
		Input.action_release(action)


func _enemies() -> Array:
	return get_tree().get_nodes_in_group("enemies").filter(func(e): return not e.is_dead and Game.SCREEN.has_point(e.global_position))


func _pick_target():
	var best = null
	var best_score = INF
	for e in _enemies():
		var score = e.global_position.x + absf(e.global_position.y - cat.global_position.y) * 0.5
		if e is Boss:
			score -= 200.0
		if score < best_score:
			best_score = score
			best = e
	return best


func _aim(target, delta):
	jitter_timer -= delta
	if jitter_timer <= 0.0:
		jitter_timer = 0.5
		aim_jitter = Vector2(rng.randfn(0, p.aim_error), rng.randfn(0, p.aim_error))
	if target:
		Game.aim_override = target.global_position + aim_jitter
	else:
		Game.aim_override = cat.global_position + Vector2(600, 0)


func _threats() -> Array:
	# [point_of_danger, direction_hint]; only threats this persona has noticed and reacts to
	var out = []
	var now = sim_time
	for shot in get_tree().get_nodes_in_group("enemy_shots"):
		var rel = shot.global_position - cat.global_position
		var v = shot.velocity
		var t = clamp(-rel.dot(v) / max(v.length_squared(), 1.0), 0.0, HORIZON)
		var closest = rel + v * t
		if closest.length() < DANGER_RADIUS and _noticed(shot, now):
			out.append(closest)
	for node in get_tree().current_scene.get_children():
		if node is EnemyBeam and node.right_x > cat.global_position.x and absf(node.global_position.y - cat.global_position.y) < EnemyBeam.WIDTH / 2.0 + 30.0:
			if _noticed(node, now):
				out.append(Vector2(0, node.global_position.y - cat.global_position.y))
	for e in _enemies():
		if e.global_position.distance_to(cat.global_position) < 110.0 and _noticed(e, now):
			out.append(e.global_position - cat.global_position)
	return out


func _noticed(node: Node, now: float) -> bool:
	var id = node.get_instance_id()
	if not seen_threats.has(id):
		seen_threats[id] = [now, rng.randf() < p.dodge_chance]
	var info = seen_threats[id]
	return info[1] and now - info[0] >= p.reaction


func _move(target):
	var threats = _threats()
	var desired = Vector2.ZERO
	var goal = Vector2(p.home_x, cat.global_position.y)
	if target:
		goal.y = target.global_position.y
	var pickup = _nearest_pickup()
	if pickup:
		goal = pickup.global_position
	if threats.is_empty():
		var to_goal = goal - cat.global_position
		if to_goal.length() > 20.0:
			desired = to_goal.normalized()
	else:
		desired = _safest_direction(goal)
	_press("move_right", desired.x > 0.3)
	_press("move_left", desired.x < -0.3)
	_press("move_down", desired.y > 0.3)
	_press("move_up", desired.y < -0.3)


# Look-ahead dodging (like a human scanning the screen): try 8 directions + staying put,
# simulate noticed bullets/beams/enemies 0.6 s ahead, pick the move with the most clearance
# (ties broken toward the goal). Only threats this persona has noticed are considered.
const MOVE_SPEED = 430.0
const LOOKAHEAD = [0.1, 0.2, 0.3, 0.45, 0.6]

func _safest_direction(goal: Vector2) -> Vector2:
	var now = sim_time
	var shots = []
	for shot in get_tree().get_nodes_in_group("enemy_shots"):
		if _noticed(shot, now):
			shots.append([shot.global_position, shot.velocity])
	var beams = []
	for node in get_tree().current_scene.get_children():
		if node is EnemyBeam and _noticed(node, now):
			beams.append([node.global_position.y, node.right_x, node.warn_time - node.time, node.warn_time + node.active_time - node.time])
	var bodies = []
	for e in _enemies():
		if _noticed(e, now):
			bodies.append(e.global_position)
	var best_dir = Vector2.ZERO
	var best_score = -INF
	var lo = Game.SCREEN.position + Vector2(40, 36)
	var hi = Game.SCREEN.end - Vector2(40, 36)
	for i in 9:
		var dir = Vector2.ZERO if i == 8 else Vector2.from_angle(TAU * i / 8.0)
		var clearance = 200.0
		for t in LOOKAHEAD:
			var pos = (cat.global_position + dir * MOVE_SPEED * t).clamp(lo, hi)
			for s in shots:
				clearance = min(clearance, pos.distance_to(s[0] + s[1] * t))
			for b in beams:
				if t >= b[2] - 0.1 and t <= b[3] and pos.x <= b[1]:
					clearance = min(clearance, absf(pos.y - b[0]) - EnemyBeam.WIDTH / 2.0)
			for body in bodies:
				clearance = min(clearance, pos.distance_to(body) - 40.0)
		var toward_goal = dir.dot((goal - cat.global_position).normalized()) if dir != Vector2.ZERO else 0.0
		var score = min(clearance, 90.0) + toward_goal * 8.0
		if score > best_score:
			best_score = score
			best_dir = dir
	return best_dir


func _nearest_pickup():
	var best = null
	var best_d = p.pickup_radius
	for pickup in get_tree().get_nodes_in_group("pickups"):
		var d = pickup.global_position.distance_to(cat.global_position)
		if d < best_d:
			best = pickup
			best_d = d
	return best


func _press(action: String, on: bool):
	if on and not Input.is_action_pressed(action):
		Input.action_press(action)
	elif not on and Input.is_action_pressed(action):
		Input.action_release(action)


func _shoot(delta):
	if gestures.drawing:
		return
	var now = Conductor.song_time()
	var remaining = []
	for t in planned_clicks:
		if now >= t:
			gun.click()
			_stat("clicks", 1)
		elif t - now < 3.0:
			remaining.append(t)
	planned_clicks = remaining
	if rng.randf() < p.spam_per_sec * delta:
		gun.click()
		_stat("clicks", 1)
	var hold = holding and sim_time < hold_until
	if holding and sim_time >= hold_until:
		holding = false
	_press("shoot", hold)


func _gesture(target):
	if gestures.drawing:
		_continue_stroke()
		return
	if Game.charges < p.gesture_min_charges and not (Game.charges > 0 and _in_danger()):
		return
	var enemies = _enemies()
	var near = enemies.filter(func(e): return e.global_position.distance_to(cat.global_position) < 450.0).size()
	var skill = ""
	if _in_danger() and Game.charges > 0:
		skill = "shield"
	elif target is Boss:
		skill = "laser"
	elif near >= 5:
		skill = "shockwave"
	elif enemies.size() >= 4:
		skill = "lightning"
	if skill == "":
		return
	_begin_stroke(skill, target)


func _in_danger() -> bool:
	return _threats().size() >= 2


func _begin_stroke(skill: String, target):
	drawing_skill = skill
	var center = Vector2(640, 380)
	var size = 140.0
	var corners = []
	if rng.randf() < p.gesture_mess_chance:
		for i in 12:
			corners.append(Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)))
	else:
		match skill:
			"shockwave":
				for i in 25:
					corners.append(Vector2.from_angle(-PI / 2 + TAU * 1.03 * i / 24.0))
			"shield":
				corners = [Vector2(0, -1), Vector2(0.9, 0.6), Vector2(-0.9, 0.6), Vector2(0, -1)]
			"lightning":
				for k in 5:
					corners.append(Vector2(-1 + k * 0.5, -0.5 + (k % 2)))
			"laser":
				var dir = Vector2.RIGHT
				if target:
					dir = (target.global_position - cat.global_position).normalized()
				corners = [-dir, dir]
	# hand wobble: smooth, low-frequency (real mouse strokes don't jitter point-to-point)
	var amp = p.gesture_noise * size
	var phase_a = rng.randf() * TAU
	var phase_b = rng.randf() * TAU
	var count = (corners.size() - 1) * 8
	stroke = PackedVector2Array()
	for i in corners.size() - 1:
		for k in 8:
			var u = float(i * 8 + k) / count
			var q = corners[i].lerp(corners[i + 1], k / 8.0)
			var wobble = Vector2(sin(u * 7.0 + phase_a), cos(u * 5.0 + phase_b)) * amp
			stroke.append(center + q * size + wobble)
	stroke.append(center + corners[corners.size() - 1] * size)
	stroke_index = 0
	release_at = -1.0
	gestures.begin(stroke[0])


func _continue_stroke():
	# draw at the persona's speed (real time), then release (on the beat for skilled players)
	var per_frame = max(1, int(ceil(stroke.size() / (p.draw_time * 60.0))))
	for i in per_frame:
		stroke_index += 1
		if stroke_index < stroke.size():
			gestures.add_point(stroke[stroke_index])
	if stroke_index < stroke.size():
		return
	if release_at < 0.0:
		var now = Conductor.song_time()
		if p.release_on_beat:
			var next_beat = ceil(now / Conductor.seconds_per_beat) * Conductor.seconds_per_beat
			release_at = next_beat + rng.randfn(0, p.release_sigma)
		else:
			release_at = now + abs(rng.randfn(0, p.release_sigma))
	if Conductor.song_time() >= release_at:
		gestures.finish()
