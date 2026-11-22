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
	if not tutorial_exempt():
		max_health *= Game.rank_health(self is Boss)
		if not self is Boss:
			max_health *= 1.0 - 0.15 * min(Game.assist, 2)   # beginner care after a game over
	if not tutorial_exempt() and not self is Boss and Game.elite_every() > 0:
		Game.elite_counter += 1
		if Game.elite_counter % Game.elite_every() == 0:
			_make_elite()
	if (self is ShieldMouse or self is Turret) and not tutorial_exempt():
		Game.suggest_spread()
	health = max_health
	entering = slot_position != Vector2.INF
	Conductor.beat.connect(_on_conductor_beat)
	Conductor.beat.connect(_anim_beat)
	_load_anim_frames()


# SPRINT 2 animation: every character has a blink/bob frame (<sprite>_b.png); frames swap on
# every beat so the whole cast bobs to the music.
var _frame_a: Texture2D
var _frame_b: Texture2D

func _load_anim_frames():
	if sprite == null or sprite.texture == null:
		return
	_frame_a = sprite.texture
	var alt = _frame_a.resource_path.replace(".png", "_b.png")
	if alt != _frame_a.resource_path and ResourceLoader.exists(alt):
		_frame_b = load(alt)


var _base_scale = Vector2.ZERO

func _anim_beat(n: int):
	if is_dead or not is_inside_tree() or sprite == null:
		return
	if _frame_b != null:
		sprite.texture = _frame_b if n % 2 == 1 else _frame_a
	# v0.12 playtest: "it didn't look like they're dancing" -> squash & stretch + a side-to-side
	# sway on every beat (bosses get a gentler version)
	if _base_scale == Vector2.ZERO:
		_base_scale = sprite.scale
	var k = 0.06 if self is Boss else 0.16
	sprite.scale = _base_scale * Vector2(1.0 + k, 1.0 - k)
	sprite.rotation = (0.05 if self is Boss else 0.16) * (1 if n % 2 == 0 else -1)
	var tw = create_tween().set_parallel()
	tw.tween_property(sprite, "scale", _base_scale, Conductor.seconds_per_beat * 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(sprite, "rotation", 0.0, Conductor.seconds_per_beat * 0.9).set_trans(Tween.TRANS_SINE)


func tutorial_exempt() -> bool:
	return Game.tutorial_mode


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
# spell: "shockwave" (circle), "laser" (line), "lightning" (zigzag), "" (bomb / other)
func take_skill_damage(amount: float, _spell: String = ""):
	Game.track("spell_hits")
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
	if is_elite:
		Game.track("elites")
		_elite_burst.call_deferred()
	_explode()
	_drop()
	died.emit(self)
	set_deferred("monitorable", false)
	var tween = create_tween().set_parallel()
	tween.tween_property(sprite, "scale", sprite.scale * 1.6, 0.18)
	tween.tween_property(sprite, "modulate", Color(1.6, 0.9, 1.4, 0.0), 0.18)
	tween.chain().tween_callback(queue_free)


var is_elite = false
const CROWN = preload("res://Art/Generated/hat_crown.png")

func _make_elite():
	is_elite = true
	max_health *= 2.0
	score_value *= 3
	if sprite:
		sprite.self_modulate = Color(1.25, 0.92, 1.2)
		var crown = Sprite2D.new()
		crown.texture = CROWN
		crown.position = Vector2(0, -sprite.texture.get_height() / 2.0 - 2)
		sprite.add_child(crown)


func _elite_burst():
	if not is_inside_tree() or Game.assist >= 2 or Game.safe_phase:
		return
	for i in 6:
		var shot = EnemyShot.create(global_position, Vector2.from_angle(TAU * i / 6.0 + 0.3), 120.0 * Game.shot_speed_factor(), EnemyShot.Kind.RICE)
		get_tree().current_scene.add_child(shot)


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
	# v0.12 playtest: a big PINK POOF cloud (puffs + sparkles) instead of debris
	var ramp = Gradient.new()
	ramp.set_color(0, Color(1, 0.85, 0.95))
	ramp.add_point(0.5, Color(1, 0.55, 0.8, 0.9))
	ramp.set_color(1, Color(1, 0.7, 0.9, 0))
	particles.color_ramp = ramp
	particles.emitting = true
	get_tree().current_scene.add_child.call_deferred(particles)
	get_tree().current_scene.add_child.call_deferred(PinkPoof.create(global_position, 1.0 + explosion_amount / 40.0))
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


func fire_shot(direction: Vector2, speed: float = 320.0, kind: int = 0) -> EnemyShot:
	var shot = EnemyShot.create(global_position + direction.normalized() * 24, direction, speed * Game.shot_speed_factor(), kind)
	shot.volley = "%d:%d" % [get_instance_id(), Engine.get_physics_frames()]
	get_tree().current_scene.add_child(shot)
	Sfx.play("enemy_shoot", -10.0)
	return shot


func is_off_screen_left() -> bool:
	return global_position.x < Game.SCREEN.position.x - 80
