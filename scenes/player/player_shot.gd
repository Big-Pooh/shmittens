extends Area2D

class_name PlayerShot

const TEXTURE = preload("res://Art/Generated/player_shot.png")
const SPEED = 900.0
const SPRITE_SCALE = 3.0

var velocity: Vector2
var damage = 1
var spent = false


static func create(at: Vector2, direction: Vector2, dmg: int = 1) -> PlayerShot:
	var shot = PlayerShot.new()
	shot.position = at
	shot.velocity = direction.normalized() * SPEED
	shot.rotation = direction.angle()
	shot.damage = dmg
	return shot


func _ready():
	collision_layer = Game.LAYER_PLAYER_SHOT
	collision_mask = Game.LAYER_ENEMY
	var sprite = Sprite2D.new()
	sprite.texture = TEXTURE
	sprite.scale = Vector2.ONE * SPRITE_SCALE
	add_child(sprite)
	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(10, 4) * SPRITE_SCALE
	shape.shape = rect
	add_child(shape)
	area_entered.connect(_on_area_entered)


func _physics_process(delta):
	position += velocity * delta
	if not Game.SCREEN.grow(60).has_point(position):
		queue_free()


func _on_area_entered(area):
	if spent:
		return
	if area is EnemyBase and not area.is_dead:
		spent = true
		area.take_damage(damage)
		queue_free()
