extends Area2D

class_name EnemyShot

const TEXTURE = preload("res://Art/Generated/enemy_shot.png")
const SPRITE_SCALE = 3.0

var velocity: Vector2


static func create(at: Vector2, direction: Vector2, speed: float) -> EnemyShot:
	var shot = EnemyShot.new()
	shot.position = at
	shot.velocity = direction.normalized() * speed
	return shot


func _ready():
	add_to_group("enemy_shots")
	collision_layer = Game.LAYER_ENEMY_SHOT
	collision_mask = 0
	var sprite = Sprite2D.new()
	sprite.texture = TEXTURE
	sprite.scale = Vector2.ONE * SPRITE_SCALE
	add_child(sprite)
	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 7.0
	shape.shape = circle
	add_child(shape)


func _physics_process(delta):
	position += velocity * delta
	if not Game.SCREEN.grow(40).has_point(position):
		queue_free()
