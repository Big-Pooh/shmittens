extends Area2D

class_name EnemyBase

# Shared enemy behaviour: health, hit flash, score, drops, death.
# Enemy scenes put a Sprite2D named "Sprite2D" and a CollisionShape2D under the root.

signal died(enemy: EnemyBase)

@export var max_health = 3
@export var score_value = 100
# Drop chances on death (rolled in this order; at most one drop).
@export var yarn_chance = 0.03
@export var battery_chance = 0.04
@export var cheese_chance = 0.6

@onready var sprite: Sprite2D = $Sprite2D

var health: float
var is_dead = false


func _ready():
	add_to_group("enemies")
	collision_layer = Game.LAYER_ENEMY
	collision_mask = 0
	health = max_health


func take_damage(amount: float):
	if is_dead:
		return
	health -= amount
	if health <= 0:
		die()
	else:
		Sfx.play("hit", -6.0)
		_flash()


func die():
	if is_dead:
		return
	is_dead = true
	Game.add_score(score_value)
	Sfx.play("explode", -4.0)
	_drop()
	died.emit(self)
	set_deferred("monitorable", false)
	var tween = create_tween().set_parallel()
	tween.tween_property(sprite, "scale", sprite.scale * 1.6, 0.18)
	tween.tween_property(sprite, "modulate", Color(1.5, 1.2, 0.6, 0.0), 0.18)
	tween.chain().tween_callback(queue_free)


func _flash():
	sprite.modulate = Color(3, 3, 3)
	create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.12)


func _drop():
	var roll = randf()
	var type = -1
	if roll < yarn_chance:
		type = Pickup.Type.YARN
	elif roll < yarn_chance + battery_chance:
		type = Pickup.Type.BATTERY
	elif roll < yarn_chance + battery_chance + cheese_chance:
		type = Pickup.Type.CHEESE
	if type != -1:
		# deferred: we may be inside a physics callback here
		get_tree().current_scene.add_child.call_deferred(Pickup.create(type, global_position))


func fire_shot(direction: Vector2, speed: float = 320.0):
	var shot = EnemyShot.create(global_position + direction.normalized() * 24, direction, speed)
	get_tree().current_scene.add_child(shot)
	Sfx.play("enemy_shoot", -10.0)


func is_off_screen_left() -> bool:
	return global_position.x < Game.SCREEN.position.x - 80
