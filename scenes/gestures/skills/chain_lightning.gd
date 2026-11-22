extends Node2D

class_name ChainLightning

# Zigzag gesture: lightning strikes along the zigzag you DREW (playtest 3: draw where it hits).
# Every enemy within STRIKE_RADIUS of the stroke is hit (up to STRIKES, nearest to the stroke
# first). If nothing is near the stroke, it jumps to the nearest enemy within JUMP_RANGE of the
# stroke's end, so a near miss still does something. Empowered: +50% damage, more strikes.
# create() (from the cat toward a point) is kept for old callers and tests.

const DAMAGE = 7.0
const STRIKES = 6
const EMPOWERED_STRIKES = 9
const STRIKE_RADIUS = 110.0
const JUMP_RANGE = 300.0
const SHOW_TIME = 0.35
const COLOR = Color(1.0, 0.95, 0.4)
# kept for compatibility
const JUMPS = 4
const EMPOWERED_JUMPS = 6

var origin: Vector2
var aim: Vector2
var stroke = PackedVector2Array()   # the drawn zigzag (world coordinates); empty = old mode
var damage = DAMAGE
var jumps = JUMPS
var strikes = STRIKES
var path = PackedVector2Array()
var bolts: Array = []               # [from, to] pairs drawn as bolts
var targets: Array = []
var time = 0.0


static func create(from: Vector2, toward: Vector2, empowered: bool) -> ChainLightning:
	var bolt = ChainLightning.new()
	bolt.origin = from
	bolt.aim = toward
	bolt.damage = DAMAGE * (1.5 if empowered else 1.0) * Game.spell_power
	bolt.jumps = EMPOWERED_JUMPS if empowered else JUMPS
	return bolt


static func along(points: PackedVector2Array, empowered: bool) -> ChainLightning:
	var bolt = ChainLightning.new()
	bolt.stroke = points
	bolt.origin = points[0] if points.size() > 0 else Vector2.ZERO
	bolt.aim = points[points.size() - 1] if points.size() > 0 else Vector2.ZERO
	bolt.damage = DAMAGE * (1.5 if empowered else 1.0) * Game.spell_power
	bolt.strikes = EMPOWERED_STRIKES if empowered else STRIKES
	return bolt


func _ready():
	z_index = 20
	if stroke.size() >= 2:
		_strike_along()
	else:
		_strike_chain()


static func distance_to_stroke(p: Vector2, pts: PackedVector2Array) -> float:
	var best = INF
	for i in pts.size() - 1:
		best = min(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, pts[i], pts[i + 1])))
	return best


func _strike_along():
	path = stroke
	var candidates = get_tree().get_nodes_in_group("enemies").filter(func(e): return not e.is_dead)
	var near = []
	for e in candidates:
		var d = distance_to_stroke(e.global_position, stroke)
		if d <= STRIKE_RADIUS:
			near.append([d, e])
	near.sort_custom(func(a, b): return a[0] < b[0])
	for pair in near.slice(0, strikes):
		targets.append(pair[1])
	if targets.is_empty():
		var fallback = _nearest(candidates, aim, JUMP_RANGE)
		if fallback:
			targets.append(fallback)
	for enemy in targets:
		var from = _closest_on_stroke(enemy.global_position)
		bolts.append([from, enemy.global_position])
		enemy.take_skill_damage(damage)


func _closest_on_stroke(p: Vector2) -> Vector2:
	var best = stroke[0]
	for i in stroke.size() - 1:
		var q = Geometry2D.get_closest_point_to_segment(p, stroke[i], stroke[i + 1])
		if q.distance_to(p) < best.distance_to(p):
			best = q
	return best


func _strike_chain():
	path.append(origin)
	var candidates = get_tree().get_nodes_in_group("enemies").filter(func(e): return not e.is_dead)
	if candidates.is_empty():
		path.append(aim)   # nothing to hit: a bolt toward the cursor, for feedback
		return
	var current = _nearest(candidates, aim, INF)
	while current and targets.size() <= jumps:
		targets.append(current)
		candidates.erase(current)
		path.append(current.global_position)
		current = _nearest(candidates, current.global_position, JUMP_RANGE)
	for enemy in targets:
		enemy.take_skill_damage(damage)


func _nearest(candidates: Array, to: Vector2, max_distance: float):
	var best = null
	var best_distance = max_distance
	for enemy in candidates:
		var d = enemy.global_position.distance_to(to)
		if d < best_distance:
			best = enemy
			best_distance = d
	return best


func _process(delta):
	time += delta
	queue_redraw()
	if time >= SHOW_TIME:
		queue_free()


func _jagged(a: Vector2, b: Vector2, fade: float):
	var bolt = PackedVector2Array([a])
	var segments = 8
	for s in range(1, segments):
		var p = a.lerp(b, float(s) / segments)
		bolt.append(p + (b - a).orthogonal().normalized() * randf_range(-14, 14))
	bolt.append(b)
	draw_polyline(bolt, Color(COLOR, fade), 5.0)
	draw_polyline(bolt, Color(1, 1, 1, fade), 2.0)


func _draw():
	var fade = 1.0 - time / SHOW_TIME
	for i in range(1, path.size()):
		_jagged(path[i - 1], path[i], fade)
	for pair in bolts:
		_jagged(pair[0], pair[1], fade)
