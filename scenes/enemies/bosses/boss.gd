extends EnemyBase

class_name Boss

# Shared boss behaviour:
# - Armour (Revision 1): off-beat and held shots do OFFBEAT_ARMOR (50%); on-beat clicks and
#   skills do full damage. Rhythm is the key way through, not the only one.
# - Phase 2 below half health (on_phase_2 hook).
# - Guaranteed reward on death: 5 cheese + a battery + a yarn.
# - Attack helpers: fan (aimed spread), ring (all directions), melody_shot (follows the lead melody).
# - Bosses "play" the music: on_lead_note() fires on each note of the lead melody
#   (Conductor.lead_note); the drums (beats/bars) drive the big attacks in on_beat().
# Subclasses call build() in _init and script their attacks in on_beat(n).

signal health_changed(health: float, max_health: float)
signal phase_changed(phase: int)

const OFFBEAT_ARMOR = 0.5
const ASSIST_OFFBEAT_ARMOR = 0.75   # beginner care: with any assist, off-beat shots do 75%
const ASSIST_HEALTH_CUT = 0.15      # beginner care: boss health -15% per assist level

var boss_name = "BOSS"
var phase = 1
var _note_count = 0


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
	explosion_amount = 80


func _ready():
	max_health *= 1.0 - ASSIST_HEALTH_CUT * Game.assist
	super()
	add_to_group("bosses")
	health_changed.emit(health, max_health)
	Conductor.lead_note.connect(_on_lead_note)


func take_hit(amount: float, _direction: Vector2, judgement: int = -1):
	var on_beat = judgement == Conductor.Judgement.GOOD or judgement == Conductor.Judgement.PERFECT
	var armor = ASSIST_OFFBEAT_ARMOR if Game.assist > 0 else OFFBEAT_ARMOR
	take_damage(amount * (1.0 if on_beat else armor), judgement)


func take_damage(amount: float, judgement: int = -1):
	if is_dead:
		return
	super(amount, judgement)
	health_changed.emit(max(health, 0.0), max_health)
	if phase == 1 and not is_dead and health <= max_health * 0.5:
		phase = 2
		phase_changed.emit(phase)
		_flash(Color(3, 1, 1))
		Game.shake(10.0)
		on_phase_2()


func _on_lead_note(pitch: int, length: int):
	if entering or is_dead or not is_inside_tree():
		return
	_note_count += 1
	if Game.assist >= 2 and _note_count % 2 == 0:
		return   # beginner care: only every other note when heavily assisted
	on_lead_note(pitch, length)


# Override: what to fire on each lead-melody note (default: one melody shot).
func on_lead_note(pitch: int, _length: int):
	melody_shot(pitch, 280.0)


# Aimed at the cat, tilted by the note's pitch: higher notes aim higher.
func melody_shot(pitch: int, speed: float, count: int = 1, spread_degrees: float = 5.0):
	var aim = (player_position() - global_position).angle()
	# tilt toward the top of the screen for higher notes, whichever way the boss is aiming
	var up_sign = 1.0 if cos(aim) < 0.0 else -1.0
	var tilt = (pitch - (MusicPatterns.SCALE_STEPS - 1) / 2.0) * 6.0 * up_sign
	var base = aim + deg_to_rad(tilt)
	for i in count:
		fire_shot(Vector2.from_angle(base + deg_to_rad((i - (count - 1) / 2.0) * spread_degrees)), speed)


# Override for a phase-2 entrance (summons etc.).
func on_phase_2():
	pass


func die():
	if not is_dead:
		Game.shake(18.0)
	super()


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
	if Game.assist >= 2:
		count = max(count - 2, 3)   # beginner care: thinner fans after repeated game overs
	var base = (player_position() - global_position).angle()
	for i in count:
		var angle = base + deg_to_rad((i - (count - 1) / 2.0) * spread_degrees)
		fire_shot(Vector2.from_angle(angle), speed)


func ring(count: int, speed: float, offset_angle: float = 0.0):
	if Game.assist >= 2:
		count = max(count - 4, 6)   # beginner care: thinner rings after repeated game overs
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
			# beginner care: boss-launched grunts don't shoot while assisted
			add.fire_slots = 1_000_000 if Game.assist > 0 else 4
			add.marching = Game.assist == 0   # ...and don't march into the cat
		get_tree().current_scene.add_child.call_deferred(add)
