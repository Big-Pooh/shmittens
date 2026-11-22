extends EnemyBase

class_name Boss

# Shared boss behaviour (playtest 2: closer to bullet hell - you dodge readable patterns while
# keeping a steady aim; bosses drift slowly instead of jumping to your height).
#
# Phase 1 - armour: off-beat and held shots do OFFBEAT_ARMOR (50%); on-beat clicks and skills
#   do full damage.
# Phase 2 (below half health) - BEAT ARMOUR: ARMOR_PIPS pips around the boss. While any pip is
#   left, only PERFECT shots hurt (full damage); everything else just pings off. Each hit chips
#   the armour by CRACK[judgement] (PERFECT a whole pip; GOOD half - a whole one when assisted;
#   off-beat/held a little, so the beat is the key way through, not the only one). When the last
#   pip breaks the boss is STUNNED for STUN_BEATS beats: it stops firing and takes STUN_DAMAGE x
#   damage from everything. Then the armour comes back.
# Guaranteed reward on death: 5 cheese + a battery + a yarn.
# Patterns (all fixed geometry, no aiming randomness):
#   staff_note - the lead melody as bullets: each note flies straight left at a height set by
#                its pitch, like notes on a stave. You can hear where the gap will be.
#   arc        - an evenly spaced fan pointing left (not aimed).
#   spiral     - rotating arms; the angle advances every call.
#   wall       - a column of bullets across the screen with a gap that moves predictably.
#   ring       - all directions.
# Subclasses call build() in _init and script their attacks in on_beat(n) / on_lead_note().

signal health_changed(health: float, max_health: float)
signal phase_changed(phase: int)
signal armor_changed(pips: float, stunned: bool)

const OFFBEAT_ARMOR = 0.5
const ASSIST_OFFBEAT_ARMOR = 0.75   # beginner care: with any assist, off-beat shots do 75%
const ASSIST_HEALTH_CUT = 0.15      # beginner care: boss health -15% per assist level
const ARMOR_PIPS = 5.0
const CRACK = {
	Conductor.Judgement.PERFECT: 1.0,
	Conductor.Judgement.GOOD: 0.5,
	Conductor.Judgement.MISS: 0.15,
	-1: 0.1,   # held fire
}
const SKILL_CRACK = 1.0
const STUN_BEATS = 8
const STUN_DAMAGE = 1.5
const STAFF_SPACING = 30.0   # pixels per scale step for staff notes
const DRIFT_RANGE = Vector2(170.0, 550.0)

var boss_name = "BOSS"
var phase = 1
var armor = 0.0          # pips left (phase 2)
var stunned_beats = 0
var spiral_angle = 0.0
var _note_count = 0
var hit_radius = 80.0


func build(texture: Texture2D, sprite_scale: float, radius: float, health: float):
	var s = Sprite2D.new()
	s.name = "Sprite2D"
	s.texture = texture
	s.scale = Vector2.ONE * sprite_scale
	add_child(s)
	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = radius
	hit_radius = radius
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


func _process(_delta):
	if phase == 2:
		queue_redraw()


func is_armored() -> bool:
	return phase == 2 and armor > 0.0 and stunned_beats == 0


func is_stunned() -> bool:
	return stunned_beats > 0


func _crack_for(judgement: int) -> float:
	var crack = CRACK.get(judgement, 0.1)
	if Game.assist > 0:
		# beginner care: GOOD cracks a whole pip, off-beat/held shots crack twice as fast
		crack = 1.0 if judgement == Conductor.Judgement.GOOD else crack * 2.0
	return crack


func take_hit(amount: float, _direction: Vector2, judgement: int = -1):
	if is_armored():
		_crack(_crack_for(judgement))
		if judgement == Conductor.Judgement.PERFECT:
			take_damage(amount, judgement)
		else:
			_ping()
		return
	var on_beat = judgement == Conductor.Judgement.GOOD or judgement == Conductor.Judgement.PERFECT
	var factor = 1.0 if on_beat else (ASSIST_OFFBEAT_ARMOR if Game.assist > 0 else OFFBEAT_ARMOR)
	if is_stunned():
		factor = STUN_DAMAGE
	take_damage(amount * factor, judgement)


# Skills: full damage in phase 1; in phase 2 they crack a whole pip (half damage) while
# armoured, and do STUN_DAMAGE x while stunned.
func take_skill_damage(amount: float):
	if is_armored():
		_crack(SKILL_CRACK)
		take_damage(amount * 0.5)
		return
	take_damage(amount * (STUN_DAMAGE if is_stunned() else 1.0))


func take_damage(amount: float, judgement: int = -1):
	if is_dead:
		return
	super(amount, judgement)
	health_changed.emit(max(health, 0.0), max_health)
	if phase == 1 and not is_dead and health <= max_health * 0.5:
		phase = 2
		armor = ARMOR_PIPS
		phase_changed.emit(phase)
		armor_changed.emit(armor, false)
		_flash(Color(3, 1, 1))
		Game.shake(10.0)
		on_phase_2()


func _crack(amount: float):
	var before = ceil(armor)
	armor = max(armor - amount, 0.0)
	if armor <= 0.0:
		stunned_beats = STUN_BEATS
		Sfx.play("armor_break")
		Game.shake(14.0)
		_flash(Color(1, 3, 3))
		armor_changed.emit(0.0, true)
	elif ceil(armor) < before:
		Sfx.play("armor_crack", -4.0)
		armor_changed.emit(armor, false)


var _last_ping_msec = 0

func _ping():
	if Time.get_ticks_msec() - _last_ping_msec > 90:
		_last_ping_msec = Time.get_ticks_msec()
		Sfx.play("armor_ping", -12.0)


func _on_conductor_beat(n: int):
	if entering or is_dead or not is_inside_tree():
		return
	if stunned_beats > 0:
		stunned_beats -= 1
		beats_alive += 1
		if stunned_beats == 0:
			armor = ARMOR_PIPS
			armor_changed.emit(armor, false)
		return
	super(n)


func _on_lead_note(pitch: int, length: int):
	if entering or is_dead or stunned_beats > 0 or not is_inside_tree():
		return
	_note_count += 1
	if Game.assist >= 1 and _note_count % 2 == 0:
		return   # beginner care: only every other melody note after a game over
	on_lead_note(pitch, length)


# Override: what to fire on each lead-melody note (default: one staff note).
func on_lead_note(pitch: int, _length: int):
	staff_note(pitch, 200.0)


# The melody as a stave: a note flies straight left at a height set by its pitch
# (higher note = higher on screen). `count` > 1 stacks a chord (tight vertical pair/triple).
func staff_note(pitch: int, speed: float, count: int = 1):
	var y = global_position.y - (pitch - (MusicPatterns.SCALE_STEPS - 1) / 2.0) * STAFF_SPACING
	for i in count:
		var at = Vector2(global_position.x - hit_radius * 0.6, y + (i - (count - 1) / 2.0) * 16.0)
		_spawn_shot(at, Vector2.LEFT, speed)


# Evenly spaced fan around `center_degrees` (180 = straight left). Not aimed.
func arc(count: int, spread_degrees: float, speed: float, center_degrees: float = 180.0):
	if Game.assist >= 1:
		count = max(count - Game.assist, 3)
		spread_degrees *= 1.2
	for i in count:
		var angle = deg_to_rad(center_degrees + (i - (count - 1) / 2.0) * spread_degrees)
		fire_shot(Vector2.from_angle(angle), speed)


# Rotating arms: each call fires one shot per arm and turns the spiral by step_degrees.
func spiral(arms: int, speed: float, step_degrees: float):
	if Game.assist >= 2 and arms > 1:
		arms -= 1
	for i in arms:
		fire_shot(Vector2.from_angle(spiral_angle + TAU * i / arms), speed)
	spiral_angle += deg_to_rad(step_degrees)


# A column of bullets across the screen at the boss's front, leaving a gap of gap_size pixels
# centred on gap_y. Bullets travel straight left.
func wall(gap_y: float, gap_size: float, speed: float, spacing: float = 46.0):
	if Game.assist > 0:
		gap_size *= 1.25
	var x = global_position.x - hit_radius
	var y = 70.0
	while y < 660.0:
		if absf(y - gap_y) > gap_size / 2.0:
			_spawn_shot(Vector2(x, y), Vector2.LEFT, speed)
		y += spacing


# Aimed spread (only used by endless-mode extras now).
func fan(count: int, spread_degrees: float, speed: float):
	if Game.assist >= 2:
		count = max(count - 2, 3)
	var base = (player_position() - global_position).angle()
	for i in count:
		var angle = base + deg_to_rad((i - (count - 1) / 2.0) * spread_degrees)
		fire_shot(Vector2.from_angle(angle), speed)


func ring(count: int, speed: float, offset_angle: float = 0.0):
	if Game.assist >= 2:
		count = max(count - 4, 6)
	for i in count:
		fire_shot(Vector2.from_angle(offset_angle + TAU * i / count), speed)


func _spawn_shot(at: Vector2, direction: Vector2, speed: float):
	var shot = EnemyShot.create(at, direction, speed * Game.shot_speed_factor())
	shot.volley = "%d:%d" % [get_instance_id(), Engine.get_physics_frames()]
	get_tree().current_scene.add_child(shot)


# Slow, predictable vertical drift (keeps the boss easy to aim at).
func drift_to(y: float, seconds: float):
	create_tween().tween_property(self, "position:y", clamp(y, DRIFT_RANGE.x, DRIFT_RANGE.y), seconds).set_trans(Tween.TRANS_SINE)


# Override for a phase-2 entrance.
func on_phase_2():
	pass


func _draw():
	if phase != 2 or is_dead:
		return
	if stunned_beats > 0:
		# dizzy stars while stunned
		var t = Time.get_ticks_msec() / 1000.0
		for i in 3:
			var p = Vector2.from_angle(t * 4.0 + TAU * i / 3.0) * Vector2(50, 16) + Vector2(0, -hit_radius - 10)
			draw_circle(p, 6.0, Color(1, 0.9, 0.3))
		return
	# beat armour: one glowing pip per remaining point, around the boss, pulsing on the beat
	var pips = int(ceil(armor))
	var pulse = 0.6 + 0.4 * (1.0 - Conductor.beat_phase())
	for i in int(ARMOR_PIPS):
		var a = -PI / 2.0 + TAU * i / ARMOR_PIPS
		var p = Vector2.from_angle(a) * (hit_radius + 18.0)
		if i < pips:
			draw_circle(p, 11.0, Color(1, 0.85, 0.3, pulse))
			draw_circle(p, 6.0, Color(1, 1, 1, pulse))
		else:
			draw_arc(p, 9.0, 0, TAU, 12, Color(1, 1, 1, 0.25), 2.0)
	draw_arc(Vector2.ZERO, hit_radius + 18.0, 0, TAU, 48, Color(1, 0.85, 0.3, 0.35 * pulse), 3.0)


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
