extends Node2D

class_name LaserBeam

# Line gesture: a piercing beam from the cat in the direction the line was drawn.
# Follows the cat while it lasts; damages each enemy once and erases enemy shots on the beam.
# Empowered: +50% width, damage and duration.

const LENGTH = 1600.0
const WIDTH = 30.0
const DAMAGE = 8.0
const DURATION = 0.45
const ENEMY_RADIUS = 24.0
const COLOR = Color(1.0, 0.4, 0.9)

var source: Node2D
var direction = Vector2.RIGHT
var width = WIDTH
var damage = DAMAGE
var duration = DURATION
var time = 0.0
var already_hit = {}


static func create(from: Node2D, dir: Vector2, empowered: bool) -> LaserBeam:
	var beam = LaserBeam.new()
	beam.source = from
	beam.direction = dir.normalized() if dir.length() > 0.01 else Vector2.RIGHT
	var boost = 1.5 if empowered else 1.0
	beam.width = WIDTH * boost
	beam.damage = DAMAGE * boost * Game.spell_power
	beam.duration = DURATION * boost
	beam.global_position = from.global_position
	return beam


func _ready():
	z_index = 20
	rotation = direction.angle()


# Distance from point p to the beam's centre line (only in front of the cat).
func distance_to_beam(p: Vector2) -> float:
	var local = p - global_position
	var along = local.dot(direction)
	if along < 0.0 or along > LENGTH:
		return INF
	return absf(local.dot(direction.orthogonal()))


func _process(delta):
	time += delta
	if is_instance_valid(source):
		global_position = source.global_position
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.is_dead or already_hit.has(enemy):
			continue
		if distance_to_beam(enemy.global_position) <= width / 2.0 + ENEMY_RADIUS:
			already_hit[enemy] = true
			enemy.take_damage(damage)
	for shot in get_tree().get_nodes_in_group("enemy_shots"):
		if distance_to_beam(shot.global_position) <= width / 2.0:
			shot.queue_free()
	queue_redraw()
	if time >= duration:
		queue_free()


func _draw():
	var fade = 1.0 - clamp(time / duration, 0.0, 1.0)
	var flicker = 0.85 + 0.15 * sin(time * 80.0)
	draw_rect(Rect2(0, -width / 2.0, LENGTH, width), Color(COLOR, 0.5 * fade))
	draw_rect(Rect2(0, -width * 0.22 * flicker, LENGTH, width * 0.44 * flicker), Color(1, 1, 1, fade))
