extends Area2D

class_name EnemyBase

# Shared enemy behaviour: health, hit flash, score, drops, death, and the common movement frame:
#   - if slot_position is set, the enemy first flies there (entry), then
#   - _behave(delta) runs every physics frame and on_beat(n) on every music beat.
# Subclasses override _behave / on_beat. Enemy scenes put a Sprite2D named "Sprite2D" and a
# CollisionShape2D under the root.

signal died(enemy: EnemyBase)

@export var max_health = 3
@export var score_value = 100
# Drops are decided by the shot that kills (no randomness):
#   PERFECT click -> 2 cheese, GOOD click -> 1 cheese,
#   anything else (off-beat, held fire, skills) -> every Nth such kill drops 1 cheese (Game).
@export var drops = true

const ENTRY_SPEED = 420.0

@onready var sprite: Sprite2D = $Sprite2D

var slot_position = Vector2.INF   # where to fly in to; INF = no entry phase
var entering = false
var beats_alive = 0               # beats since the entry finished
var last_hit_judgement = -1       # Conductor.Judgement of the latest hit, -1 = not a judged click

var health: float
var is_dead = false


func _ready():
	add_to_group("enemies")
	collision_layer = Game.LAYER_ENEMY
	collision_mask = 0
	health = max_health
	entering = slot_position != Vector2.INF
	Conductor.beat.connect(_on_conductor_beat)


func _physics_process(delta):
	if is_dead:
		return
	if entering:
		position = position.move_toward(slot_position, ENTRY_SPEED * delta)
		if position.is_equal_approx(slot_position):
			entering = false
		return
	_behave(delta)
	if is_off_screen_left():
		queue_free()


func _on_conductor_beat(n: int):
	if entering or is_dead or not is_inside_tree():
		return
	beats_alive += 1
	on_beat(n)


# Override: per-frame movement after the entry.
func _behave(_delta: float):
	pass


# Override: what to do on each beat (n = beat number since the track started).
func on_beat(_n: int):
	pass


# Called by player shots with the shot's travel direction and timing judgement
# (shield mice use both; -1 = held/auto shot).
func take_hit(amount: float, _direction: Vector2, judgement: int = -1):
	take_damage(amount, judgement)


# Skills call this (bosses override it for beat armour).
func take_skill_damage(amount: float):
	take_damage(amount)


func take_damage(amount: float, judgement: int = -1):
	if is_dead:
		return
	last_hit_judgement = judgement
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
	_explode()
	_drop()
	died.emit(self)
	set_deferred("monitorable", false)
	var tween = create_tween().set_parallel()
	tween.tween_property(sprite, "scale", sprite.scale * 1.6, 0.18)
	tween.tween_property(sprite, "modulate", Color(1.5, 1.2, 0.6, 0.0), 0.18)
	tween.chain().tween_callback(queue_free)


# Debris burst; bosses raise explosion_amount.
var explosion_amount = 14

func _explode():
	var particles = CPUParticles2D.new()
	particles.position = global_position
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = explosion_amount
	particles.lifetime = 0.5
	particles.spread = 180.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 80.0
	particles.initial_velocity_max = 260.0 + explosion_amount * 2.0
	particles.scale_amount_min = 3.0
	particles.scale_amount_max = 6.0
	var ramp = Gradient.new()
	ramp.set_color(0, Color(1, 0.85, 0.4))
	ramp.set_color(1, Color(1, 0.3, 0.2, 0))
	particles.color_ramp = ramp
	particles.emitting = true
	get_tree().current_scene.add_child.call_deferred(particles)
	get_tree().create_timer(1.0).timeout.connect(particles.queue_free)


func _flash(color := Color(3, 3, 3)):
	if Game.reduce_effects:
		color = Color(1.5, 1.5, 1.5)
	sprite.modulate = color
	create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.12)


# Visual warning one beat before an attack.
func telegraph():
	_flash(Color(2.5, 1.2, 0.4))


func _drop():
	if not drops:
		return
	var cheese = 0
	match last_hit_judgement:
		Conductor.Judgement.PERFECT:
			cheese = 2
		Conductor.Judgement.GOOD:
			cheese = 1
		_:
			cheese = 1 if Game.register_plain_kill() else 0
	for i in cheese:
		# deferred: we may be inside a physics callback here
		var pickup = Pickup.create(Pickup.Type.CHEESE, global_position + Vector2(i * 18, i * -14))
		get_tree().current_scene.add_child.call_deferred(pickup)


func fire_shot(direction: Vector2, speed: float = 320.0):
	var shot = EnemyShot.create(global_position + direction.normalized() * 24, direction, speed * Game.shot_speed_factor())
	get_tree().current_scene.add_child(shot)
	Sfx.play("enemy_shoot", -10.0)


func is_off_screen_left() -> bool:
	return global_position.x < Game.SCREEN.position.x - 80
