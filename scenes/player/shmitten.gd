extends CharacterBody2D

class_name Shmitten

signal died

@export var max_speed = 600
@export var acceleration = 2000
@export var friction = 2000

const INVULNERABLE_TIME = 2.0
const RESPAWN_DELAY = 1.0
const FLY_FRAMES = 10        # row 0 of the sprite sheet
const FLY_FPS = 12.0
const SCREEN_MARGIN = Vector2(40, 36)

@onready var axis = Vector2.ZERO
@onready var sprite: Sprite2D = $Sprite2D
@onready var hitbox: Area2D = $Hitbox
@onready var pickup_area: Area2D = $PickupArea

var spawn_position: Vector2
var is_dead = false
var is_invulnerable = false
var anim_time = 0.0
var blink_tween: Tween


func _ready():
	add_to_group("player")
	spawn_position = position
	hitbox.area_entered.connect(_on_hitbox_area_entered)
	pickup_area.area_entered.connect(_on_pickup_area_entered)


func _process(delta):
	anim_time += delta
	sprite.frame = int(anim_time * FLY_FPS) % FLY_FRAMES


func _physics_process(delta):
	if is_dead:
		return
	move(delta)
	# keep the cat on screen
	position = position.clamp(Game.SCREEN.position + SCREEN_MARGIN, Game.SCREEN.end - SCREEN_MARGIN)


func get_input_axis():
	axis.x = int(Input.is_action_pressed("move_right")) - int(Input.is_action_pressed("move_left"))
	axis.y = int(Input.is_action_pressed("move_down")) - int(Input.is_action_pressed("move_up"))
	return axis.normalized()


func move(delta):
	axis = get_input_axis()

	if axis == Vector2.ZERO:
		apply_friction(friction * delta)
	else:
		apply_movement(axis * acceleration * delta)

	move_and_slide()


func apply_friction(amount):
	if velocity.length() > amount:
		velocity -= velocity.normalized() * amount
	else:
		velocity = Vector2.ZERO


func apply_movement(accel):
	velocity += accel
	velocity = velocity.limit_length(max_speed)


func can_shoot() -> bool:
	return not is_dead and not Game.is_game_over and not Game.drawing


func has_shield() -> bool:
	for child in get_children():
		if child is Shield and child.is_active():
			return true
	return false


func _on_hitbox_area_entered(area):
	if area is EnemyShot:
		if hit("shot"):
			area.queue_free()
	elif area is EnemyBase:
		if hit("ram"):
			area.die()


func _on_pickup_area_entered(area):
	if area is Pickup and not is_dead:
		area.collect()


# Returns true if the hit counted.
func hit(cause: String = "") -> bool:
	if is_dead or is_invulnerable or has_shield():
		return false
	is_dead = true
	velocity = Vector2.ZERO
	sprite.hide()
	Sfx.play("player_hit")
	Game.player_hit.emit(cause)
	Game.shake(12.0)
	died.emit()
	if Game.lose_life() > 0:
		_respawn_later()
	return true


func _respawn_later():
	await get_tree().create_timer(RESPAWN_DELAY, false).timeout
	respawn()


func respawn():
	position = spawn_position
	velocity = Vector2.ZERO
	is_dead = false
	sprite.show()
	is_invulnerable = true
	if blink_tween:
		blink_tween.kill()
	blink_tween = create_tween().set_loops(int(INVULNERABLE_TIME / 0.2))
	blink_tween.tween_property(sprite, "modulate:a", 0.25, 0.1)
	blink_tween.tween_property(sprite, "modulate:a", 1.0, 0.1)
	blink_tween.finished.connect(_end_invulnerability)


func _end_invulnerability():
	sprite.modulate.a = 1.0
	is_invulnerable = false
