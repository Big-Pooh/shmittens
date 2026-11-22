extends Area2D

class_name Pickup

# Enemy drops. Drift left, wobble, and get pulled toward the cat when it's close.
#   CHEESE:  every Game.CHEESE_PER_CHARGE gives a skill charge
#   BATTERY: +1 skill charge
#   YARN:    +1 gun level

enum Type { CHEESE, BATTERY, YARN, MECH_CORE }

const TEXTURES = {
	Type.CHEESE: preload("res://Art/Generated/cheese.png"),
	Type.BATTERY: preload("res://Art/Generated/battery.png"),
	Type.YARN: preload("res://Art/Generated/yarn.png"),
	Type.MECH_CORE: preload("res://Art/Generated/mech_core.png"),
}
const SPRITE_SCALE = 3.0
const DRIFT_SPEED = 70.0
# playtest 2: "a more potent magnet for cheese" (was radius 160, speed 700)
const MAGNET_RADIUS = 340.0
const MAGNET_SPEED = 1100.0
# During a dance break (between waves) every pickup on screen flies to the cat.

var type: Type = Type.CHEESE
var velocity: Vector2
var collected = false
var time = 0.0


static func create(pickup_type: Type, at: Vector2) -> Pickup:
	var pickup = Pickup.new()
	pickup.type = pickup_type
	pickup.position = at
	return pickup


func _ready():
	add_to_group("pickups")
	collision_layer = Game.LAYER_PICKUP
	collision_mask = 0
	var sprite = Sprite2D.new()
	sprite.texture = TEXTURES[type]
	sprite.scale = Vector2.ONE * SPRITE_SCALE
	add_child(sprite)
	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 14.0
	shape.shape = circle
	add_child(shape)
	# pop out of the enemy a little before drifting
	velocity = Vector2(randf_range(-60, 60), randf_range(-120, 40))
	time = randf() * TAU


func _physics_process(delta):
	time += delta
	var player = get_tree().get_first_node_in_group("player") as Shmitten
	if player and not player.is_dead and (Game.dancing or player.global_position.distance_to(global_position) < MAGNET_RADIUS):
		# accelerate in, so pickups near the edge of the magnet don't overshoot or orbit
		var want = global_position.direction_to(player.global_position) * MAGNET_SPEED
		velocity = velocity.lerp(want, min(10.0 * delta, 1.0))
	else:
		velocity = velocity.lerp(Vector2(-DRIFT_SPEED, sin(time * 2.0) * 30.0), 2.0 * delta)
	position += velocity * delta
	rotation = sin(time * 3.0) * 0.2
	if position.x < Game.SCREEN.position.x - 40:
		queue_free()


func collect():
	if collected:
		return
	collected = true
	match type:
		Type.CHEESE:
			Game.add_cheese(1)
			Sfx.play("pickup", -6.0)
		Type.BATTERY:
			Game.add_charge(1)
			Sfx.play("power_up")
		Type.MECH_CORE:
			var player = Game.player_ref
			if player and is_instance_valid(player):
				player.start_mech()
		Type.YARN:
			Game.add_gun_level(1)
			Sfx.play("power_up")
	queue_free()
