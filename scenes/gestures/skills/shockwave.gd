extends Node2D

class_name Shockwave

# Circle gesture: a ring expands from the centre of the circle you DREW (playtest 3: from the cat
# it couldn't reach the mice), damaging each enemy once and erasing enemy shots it passes.
# Its size follows the size of your circle. Empowered: +50% radius and damage.

const RADIUS = 420.0          # largest ring (unempowered)
const MIN_RADIUS = 150.0
const DRAWN_SCALE = 1.5       # ring radius = drawn circle radius x this
const DAMAGE = 6.0
const DURATION = 0.5
const ENEMY_RADIUS = 24.0
const COLOR = Color(0.5, 0.9, 1.0)

var max_radius = RADIUS
var damage = DAMAGE
var radius = 0.0
var time = 0.0
var already_hit = {}


# drawn_radius < 0: full size (used when no stroke is available)
static func create(at: Vector2, empowered: bool, drawn_radius: float = -1.0) -> Shockwave:
	var wave = Shockwave.new()
	wave.position = at
	var boost = 1.5 if empowered else 1.0
	var r = RADIUS if drawn_radius < 0.0 else clamp(drawn_radius * DRAWN_SCALE, MIN_RADIUS, RADIUS)
	wave.max_radius = r * boost
	wave.damage = DAMAGE * boost * Game.spell_power
	return wave


func _ready():
	z_index = 20


func _process(delta):
	time += delta
	var t = clamp(time / DURATION, 0.0, 1.0)
	radius = max_radius * (1.0 - pow(1.0 - t, 3.0))   # fast start, slows at the edge
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.is_dead or already_hit.has(enemy):
			continue
		if enemy.global_position.distance_to(global_position) <= radius + ENEMY_RADIUS:
			already_hit[enemy] = true
			enemy.take_skill_damage(damage, "shockwave")
	for shot in get_tree().get_nodes_in_group("enemy_shots"):
		if shot.global_position.distance_to(global_position) <= radius:
			shot.queue_free()
	queue_redraw()
	if t >= 1.0:
		queue_free()


func _draw():
	var fade = 1.0 - clamp(time / DURATION, 0.0, 1.0)
	draw_arc(Vector2.ZERO, radius, 0, TAU, 72, Color(COLOR, fade), 12.0)
	draw_arc(Vector2.ZERO, radius * 0.92, 0, TAU, 72, Color(1, 1, 1, fade * 0.6), 4.0)
