extends Area2D

class_name PlayerShot

# Kinds (one per weapon, see gun.gd): BOLT (yarn spread), LASER (fast, pierces), FISH (homes).
enum Kind { BOLT, LASER, FISH }
const TEXTURES = {
	Kind.BOLT: preload("res://Art/Generated/player_shot.png"),
	Kind.LASER: preload("res://Art/Generated/shot_laser.png"),
	Kind.FISH: preload("res://Art/Generated/shot_fish.png"),
}
const SPEEDS = {Kind.BOLT: 900.0, Kind.LASER: 1500.0, Kind.FISH: 640.0}
const SPEED = 900.0
const SPRITE_SCALE = 3.0
const FISH_TURN_RATE = 7.0     # radians per second
const FISH_SEEK_RANGE = 900.0

var kind = Kind.BOLT
# Spread pellets (BOLT): full damage within FALLOFF_START px of where they were fired, down to
# FALLOFF_MIN at FALLOFF_END; they vanish at BOLT_RANGE and erase enemy bullets they touch.
const FALLOFF_START = 200.0
const FALLOFF_END = 700.0
const FALLOFF_MIN = 0.3
const BOLT_RANGE = 760.0
var origin: Vector2
var crit = false   # PERFECT laser bolt: shows "CRIT!" on hit

var velocity: Vector2
var damage = 1.0
var judgement = -1   # Conductor.Judgement for clicked shots, -1 for auto-fire
var spent = false
var pierce = false          # FEVER shots go through enemies (each enemy hit once)
var already_hit = {}


static func create(at: Vector2, direction: Vector2, dmg: float = 1.0, judged: int = -1, shot_kind: Kind = Kind.BOLT) -> PlayerShot:
	var shot = PlayerShot.new()
	shot.kind = shot_kind
	shot.position = at
	shot.origin = at
	shot.velocity = direction.normalized() * SPEEDS[shot_kind]
	shot.pierce = shot_kind == Kind.LASER
	shot.rotation = direction.angle()
	shot.damage = dmg
	shot.judgement = judged
	if Game.is_fever():
		shot.pierce = true
		shot.damage *= Game.FEVER_DAMAGE
	return shot


func _ready():
	collision_layer = Game.LAYER_PLAYER_SHOT
	collision_mask = Game.LAYER_ENEMY | (Game.LAYER_ENEMY_SHOT if kind == Kind.BOLT else 0)
	var sprite = Sprite2D.new()
	sprite.texture = TEXTURES[kind]
	sprite.scale = Vector2.ONE * SPRITE_SCALE
	# on-beat shots are bigger and glow gold
	if Game.is_fever():
		sprite.scale *= 1.5
		sprite.modulate = Color(2.0, 1.4, 0.3)
	elif judgement == Conductor.Judgement.PERFECT:
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
	if kind == Kind.FISH:
		_home(delta)
	position += velocity * delta
	if kind == Kind.BOLT and position.distance_to(origin) > BOLT_RANGE:
		queue_free()
	if not Game.SCREEN.grow(60).has_point(position):
		queue_free()


# Damage after distance falloff (spread pellets only).
func damage_now() -> float:
	if kind != Kind.BOLT:
		return damage
	var d = position.distance_to(origin)
	var t = clamp((d - FALLOFF_START) / (FALLOFF_END - FALLOFF_START), 0.0, 1.0)
	return damage * lerp(1.0, FALLOFF_MIN, t)


func _crit_popup(at: Vector2):
	var label = Label.new()
	label.text = "CRIT!"
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 5)
	label.position = at + Vector2(-24, -40)
	label.z_index = 45
	get_tree().current_scene.add_child(label)
	var tween = label.create_tween()
	tween.tween_property(label, "position:y", label.position.y - 26, 0.4)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.4)
	tween.tween_callback(label.queue_free)
	Game.track("crits")


func _on_area_entered(area):
	if area is EnemyBase and crit and not area.is_dead and not already_hit.has(area):
		_crit_popup(area.global_position)
	if area is EnemyShot:
		area.queue_free()   # spread pellets erase bullets and keep going
		return
	if spent:
		return
	if area is EnemyBase and not area.is_dead and pierce:
		if not already_hit.has(area):
			already_hit[area] = true
			area.take_hit(damage_now(), velocity, judgement)
		return
	if area is EnemyBase and not area.is_dead:
		spent = true
		area.take_hit(damage_now(), velocity, judgement)
		queue_free()


# Fish turn toward the nearest living enemy in front of them.
func _home(delta: float):
	var best: Node2D = null
	var best_d = FISH_SEEK_RANGE
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.is_dead:
			continue
		var d = enemy.global_position.distance_to(global_position)
		if d < best_d:
			best_d = d
			best = enemy
	if best == null:
		return
	var want = (best.global_position - global_position).angle()
	var now = velocity.angle()
	var turn = clamp(angle_difference(now, want), -FISH_TURN_RATE * delta, FISH_TURN_RATE * delta)
	velocity = velocity.rotated(turn)
	rotation = velocity.angle()
