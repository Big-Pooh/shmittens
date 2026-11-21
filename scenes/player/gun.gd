extends Node2D

# Fires toward the mouse. A click shoots immediately; holding auto-fires.
# Gun level (1-5) = number of streams, fanned out by SPREAD_DEGREES.

const AUTO_FIRE_INTERVAL = 1.0 / 6.0
const SPREAD_DEGREES = 7.0

@onready var player: Shmitten = get_parent()

var cooldown = 0.0


func _unhandled_input(event):
	if event.is_action_pressed("shoot"):
		fire()


func _process(delta):
	cooldown -= delta
	if Input.is_action_pressed("shoot") and cooldown <= 0.0:
		fire()


func fire():
	if not player.can_shoot():
		return
	cooldown = AUTO_FIRE_INTERVAL
	var direction = get_global_mouse_position() - global_position
	if direction.length() < 1.0:
		direction = Vector2.RIGHT
	var base_angle = direction.angle()
	var streams = Game.gun_level
	for i in streams:
		var offset = deg_to_rad((i - (streams - 1) / 2.0) * SPREAD_DEGREES)
		var shot = PlayerShot.create(global_position, Vector2.from_angle(base_angle + offset))
		get_tree().current_scene.add_child(shot)
	Sfx.play("shoot", -8.0)
