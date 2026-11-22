extends Node2D

class_name ChainLightning

# Zigzag gesture: lightning strikes the enemy nearest the cursor, then jumps to the nearest
# not-yet-hit enemy within JUMP_RANGE, up to JUMPS more times. Instant damage; the bolts
# are drawn for a moment. Empowered: +50% damage and 6 jumps instead of 4.

const DAMAGE = 5.0
const JUMPS = 4
const EMPOWERED_JUMPS = 6
const JUMP_RANGE = 300.0
const SHOW_TIME = 0.35
const COLOR = Color(1.0, 0.95, 0.4)

var origin: Vector2
var aim: Vector2
var damage = DAMAGE
var jumps = JUMPS
var path = PackedVector2Array()   # cat, then each target
var targets: Array = []
var time = 0.0


static func create(from: Vector2, toward: Vector2, empowered: bool) -> ChainLightning:
	var bolt = ChainLightning.new()
	bolt.origin = from
	bolt.aim = toward
	bolt.damage = DAMAGE * (1.5 if empowered else 1.0) * Game.spell_power
	bolt.jumps = EMPOWERED_JUMPS if empowered else JUMPS
	return bolt


func _ready():
	z_index = 20
	_strike()


func _strike():
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
		enemy.take_damage(damage)


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


func _draw():
	var fade = 1.0 - time / SHOW_TIME
	for i in range(1, path.size()):
		var a = path[i - 1]
		var b = path[i]
		var bolt = PackedVector2Array([a])
		var segments = 8
		for s in range(1, segments):
			var p = a.lerp(b, float(s) / segments)
			bolt.append(p + (b - a).orthogonal().normalized() * randf_range(-14, 14))
		bolt.append(b)
		draw_polyline(bolt, Color(COLOR, fade), 5.0)
		draw_polyline(bolt, Color(1, 1, 1, fade), 2.0)
