extends EnemyBase

class_name Boss

# Shared boss behaviour:
# - Armour (Revision 1): off-beat and held shots do OFFBEAT_ARMOR (50%); on-beat clicks and
#   skills do full damage. Rhythm is the key way through, not the only one.
# - Phase 2 below half health (on_phase_2 hook).
# - Guaranteed reward on death: 5 cheese + a battery + a yarn.
# - Attack helpers: fan (aimed spread), ring (all directions).
# Subclasses call build() in _init and script their attacks in on_beat(n).

signal health_changed(health: float, max_health: float)
signal phase_changed(phase: int)

const OFFBEAT_ARMOR = 0.5

var boss_name = "BOSS"
var phase = 1


func build(texture: Texture2D, sprite_scale: float, hit_radius: float, health: float):
	var s = Sprite2D.new()
	s.name = "Sprite2D"
	s.texture = texture
	s.scale = Vector2.ONE * sprite_scale
	add_child(s)
	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = hit_radius
	shape.shape = circle
	add_child(shape)
	max_health = health
	score_value = 5000


func _ready():
	super()
	add_to_group("bosses")
	health_changed.emit(health, max_health)


func take_hit(amount: float, _direction: Vector2, judgement: int = -1):
	var on_beat = judgement == Conductor.Judgement.GOOD or judgement == Conductor.Judgement.PERFECT
	take_damage(amount * (1.0 if on_beat else OFFBEAT_ARMOR), judgement)


func take_damage(amount: float, judgement: int = -1):
	if is_dead:
		return
	super(amount, judgement)
	health_changed.emit(max(health, 0.0), max_health)
	if phase == 1 and not is_dead and health <= max_health * 0.5:
		phase = 2
		phase_changed.emit(phase)
		_flash(Color(3, 1, 1))
		on_phase_2()


# Override for a phase-2 entrance (summons etc.).
func on_phase_2():
	pass


func is_off_screen_left() -> bool:
	return false


func _drop():
	var rewards = [Pickup.Type.YARN, Pickup.Type.BATTERY]
	for i in 5:
		rewards.append(Pickup.Type.CHEESE)
	for i in rewards.size():
		var offset = Vector2.from_angle(TAU * i / rewards.size()) * 50.0
		get_tree().current_scene.add_child.call_deferred(Pickup.create(rewards[i], global_position + offset))


func player_position() -> Vector2:
	var player = get_tree().get_first_node_in_group("player") as Node2D
	return player.global_position if player else global_position + Vector2.LEFT * 500


# `count` shots spread over `spread_degrees` between each, centred on the cat.
func fan(count: int, spread_degrees: float, speed: float):
	var base = (player_position() - global_position).angle()
	for i in count:
		var angle = base + deg_to_rad((i - (count - 1) / 2.0) * spread_degrees)
		fire_shot(Vector2.from_angle(angle), speed)


func ring(count: int, speed: float, offset_angle: float = 0.0):
	for i in count:
		fire_shot(Vector2.from_angle(offset_angle + TAU * i / count), speed)


func move_to_y(y: float, seconds: float = 0.3):
	create_tween().tween_property(self, "position:y", clamp(y, 120.0, 600.0), seconds).set_trans(Tween.TRANS_SINE)


# Spawns helper enemies that fly in from the boss.
func summon(scene: PackedScene, slots: Array, health: float):
	for i in slots.size():
		var add = scene.instantiate()
		add.position = global_position
		add.slot_position = slots[i]
		add.max_health = health
		if add is Grunt:
			add.fire_slot = i
			add.fire_slots = 4
		get_tree().current_scene.add_child.call_deferred(add)
