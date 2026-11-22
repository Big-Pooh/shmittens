extends Area2D

class_name EnemyShot

# Enemy bullets. Playtest 3 ("Touhou-like"): three readable kinds and bullets that change
# mid-flight.
#   CANDY - the standard round bullet.
#   RICE  - a small grain that points where it flies; tight streams and spirals.
#   ORB   - a big, slow bubble (bigger hitbox, easy to see).
# Freeze-and-scatter: stop after `stop_after` seconds, hold for `stop_for`, then fly off at
# `then_speed` - aimed at the cat (then_aim) or turned by `then_turn` radians.
# GRAZE: passing within GRAZE_RADIUS of the cat's core without hitting it counts once per bullet
# (Game.graze: points, and cheese when it happens on the beat).

enum Kind { CANDY, RICE, ORB }
const TEXTURES = {
	Kind.CANDY: preload("res://Art/Generated/enemy_shot.png"),
	Kind.RICE: preload("res://Art/Generated/shot_rice.png"),
	Kind.ORB: preload("res://Art/Generated/shot_orb.png"),
}
const TEXTURE = preload("res://Art/Generated/enemy_shot.png")
const SPRITE_SCALE = 3.0
const HIT_RADIUS = {Kind.CANDY: 5.0, Kind.RICE: 4.0, Kind.ORB: 9.0}
const GRAZE_RADIUS = 30.0

var velocity: Vector2
var volley = ""   # shots fired together share this (simulated players read a volley as one pattern)
var kind = Kind.CANDY
var stop_after = -1.0
var stop_for = 0.0
var then_speed = 0.0
var then_aim = false
var then_turn = 0.0
var age = 0.0
var grazed = false
var sprite: Sprite2D


static func create(at: Vector2, direction: Vector2, speed: float, shot_kind: Kind = Kind.CANDY) -> EnemyShot:
	var shot = EnemyShot.new()
	shot.position = at
	shot.velocity = direction.normalized() * speed
	shot.kind = shot_kind
	return shot


# Freeze-and-scatter setup (returns self for chaining).
func freeze(after: float, hold: float, speed: float, aim: bool = true, turn: float = 0.0) -> EnemyShot:
	stop_after = after
	stop_for = hold
	then_speed = speed
	then_aim = aim
	then_turn = turn
	return self


func _ready():
	add_to_group("enemy_shots")
	collision_layer = Game.LAYER_ENEMY_SHOT
	collision_mask = 0
	sprite = Sprite2D.new()
	sprite.texture = TEXTURES[kind]
	sprite.scale = Vector2.ONE * SPRITE_SCALE
	add_child(sprite)
	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = HIT_RADIUS[kind]   # smaller than the sprite: near-misses that look like misses are misses
	shape.shape = circle
	add_child(shape)
	_face()


func _face():
	if kind == Kind.RICE and velocity.length() > 1.0:
		rotation = velocity.angle()


func _physics_process(delta):
	age += delta
	if stop_after >= 0.0 and age >= stop_after:
		if age < stop_after + stop_for:
			# frozen: shiver a little so it reads as "about to go"
			sprite.position = Vector2(randf_range(-1, 1), randf_range(-1, 1))
			_check_graze()
			return
		sprite.position = Vector2.ZERO
		var dir = velocity.normalized() if velocity.length() > 1.0 else Vector2.LEFT
		if then_aim:
			var player = Game.player_ref
			if player and is_instance_valid(player):
				dir = (player.global_position - global_position).normalized()
		velocity = dir.rotated(then_turn) * then_speed * Game.shot_speed_factor()
		stop_after = -1.0
		_face()
	position += velocity * delta
	_check_graze()
	if not Game.SCREEN.grow(40).has_point(position):
		queue_free()


func _check_graze():
	if grazed:
		return
	var player = Game.player_ref
	if player == null or not is_instance_valid(player) or player.is_dead:
		return
	if global_position.distance_to(player.global_position + player.hitbox.position) < GRAZE_RADIUS:
		grazed = true
		Game.graze(global_position)
