extends Area2D

class_name PlayerShot

const TEXTURE = preload("res://Art/Generated/player_shot.png")
const SPEED = 900.0
const SPRITE_SCALE = 3.0

var velocity: Vector2
var damage = 1.0
var judgement = -1   # Conductor.Judgement for clicked shots, -1 for auto-fire
var spent = false


static func create(at: Vector2, direction: Vector2, dmg: float = 1.0, judged: int = -1) -> PlayerShot:
	var shot = PlayerShot.new()
	shot.position = at
	shot.velocity = direction.normalized() * SPEED
	shot.rotation = direction.angle()
	shot.damage = dmg
	shot.judgement = judged
	return shot


func _ready():
	collision_layer = Game.LAYER_PLAYER_SHOT
	collision_mask = Game.LAYER_ENEMY
	var sprite = Sprite2D.new()
	sprite.texture = TEXTURE
	sprite.scale = Vector2.ONE * SPRITE_SCALE
	# on-beat shots are bigger and glow gold
	if judgement == Conductor.Judgement.PERFECT:
		sprite.scale *= 1.7
		sprite.modulate = Color(1.6, 1.3, 0.4)
	elif judgement == Conductor.Judgement.GOOD:
		sprite.scale *= 1.3
		sprite.modulate = Color(1.3, 1.3, 0.8)
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
		area.take_hit(damage, velocity, judgement)
		queue_free()
