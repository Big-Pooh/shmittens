extends Node2D

class_name Shockwave

# Circle gesture: a ring expands from where the cat was, damaging each enemy once and
# erasing enemy shots it passes. Empowered: +50% radius and damage.

const RADIUS = 420.0
const DAMAGE = 6.0
const DURATION = 0.5
const ENEMY_RADIUS = 24.0
const COLOR = Color(0.5, 0.9, 1.0)

var max_radius = RADIUS
var damage = DAMAGE
var radius = 0.0
var time = 0.0
var already_hit = {}


static func create(at: Vector2, empowered: bool) -> Shockwave:
	var wave = Shockwave.new()
	wave.position = at
	var boost = 1.5 if empowered else 1.0
	wave.max_radius = RADIUS * boost
	wave.damage = DAMAGE * boost
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
			enemy.take_damage(damage)
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
