extends Node2D

class_name Shield

# Triangle gesture: a bubble around the cat that blocks every hit and erases enemy shots
# that touch it. Lasts DURATION seconds (empowered: +50%). Recasting refreshes it.

const DURATION = 4.0
const RADIUS = 64.0
const COLOR = Color(0.4, 1.0, 0.6)

var duration = DURATION
var time = 0.0


static func create(empowered: bool) -> Shield:
	var shield = Shield.new()
	shield.duration = DURATION * (1.5 if empowered else 1.0) * Game.spell_power
	shield.name = "Shield"
	return shield


func _ready():
	z_index = 5
	# only one shield at a time: a new one replaces the old
	for sibling in get_parent().get_children():
		if sibling is Shield and sibling != self:
			sibling.queue_free()


func is_active() -> bool:
	return time < duration


func _process(delta):
	time += delta
	for shot in get_tree().get_nodes_in_group("enemy_shots"):
		if shot.global_position.distance_to(global_position) <= RADIUS:
			shot.queue_free()
	queue_redraw()
	if time >= duration:
		queue_free()


func _draw():
	var remaining = duration - time
	# blink during the last second as a warning
	var alpha = 0.35 if remaining > 1.0 or int(remaining * 10) % 2 == 0 else 0.1
	draw_circle(Vector2.ZERO, RADIUS, Color(COLOR, alpha * 0.5))
	draw_arc(Vector2.ZERO, RADIUS, 0, TAU, 48, Color(COLOR, alpha * 2.0), 3.0)
