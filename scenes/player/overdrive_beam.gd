extends Node2D

class_name OverdriveBeam

# CATNIP OVERDRIVE (F, after a 50 on-beat combo): Game.OVERDRIVE_SECONDS of a giant rainbow
# beam from the cat toward the aim. On every 8th note it hits everything in the beam for
# TICK_DAMAGE as a PERFECT hit (so it also cracks boss beat armour); it erases enemy bullets
# it touches the whole time. Full music while it lasts.

const LENGTH = 1600.0
# playtest 4: "underpowered - it should hit hard": 3 -> 8 per 8th note, wider, and bosses
# also lose BOSS_TICK_FRACTION of their health per tick (about a fifth of a boss over 5 s).
const WIDTH = 130.0
const TICK_DAMAGE = 8.0
const BOSS_TICK_FRACTION = 0.012
const RAINBOW = [Color(1, 0.4, 0.5), Color(1, 0.7, 0.3), Color(1, 0.95, 0.4), Color(0.5, 1, 0.6), Color(0.4, 0.8, 1), Color(0.75, 0.5, 1)]

var source: Node2D
var direction = Vector2.RIGHT
var time = 0.0
var last_half = -1


static func create(from: Node2D) -> OverdriveBeam:
	var beam = OverdriveBeam.new()
	beam.source = from
	return beam


func _ready():
	z_index = 18
	Game.set_overdrive(2)
	Game.track("overdrives_used")
	Conductor.set_layers(4)
	Sfx.play("laser")
	Game.shake(8.0)


func _aim() -> Vector2:
	return Game.aim_override if Game.aim_override != null else get_global_mouse_position()


func _physics_process(delta):
	time += delta
	if not is_instance_valid(source) or source.is_dead:
		_end()
		return
	global_position = source.global_position
	var to = _aim() - global_position
	if to.length() > 1.0:
		direction = direction.lerp(to.normalized(), min(8.0 * delta, 1.0)).normalized()
	rotation = direction.angle()
	for shot in get_tree().get_nodes_in_group("enemy_shots"):
		if _in_beam(shot.global_position, 0.0):
			shot.queue_free()
	var half = int(floor(Conductor.beat_position() * 2.0))
	if half != last_half:
		last_half = half
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if not enemy.is_dead and _in_beam(enemy.global_position, 30.0):
				var dmg = TICK_DAMAGE
				if enemy is Boss:
					dmg += enemy.max_health * BOSS_TICK_FRACTION
				enemy.take_hit(dmg, direction, Conductor.Judgement.PERFECT)
		Game.shake(3.0)
		Sfx.play("hit", -2.0)
	queue_redraw()
	if time >= Game.OVERDRIVE_SECONDS:
		_end()


func _in_beam(p: Vector2, margin: float) -> bool:
	var local = p - global_position
	var along = local.dot(direction)
	return along >= 0.0 and along <= LENGTH and absf(local.dot(direction.orthogonal())) <= WIDTH / 2.0 + margin


func _end():
	if Game.overdrive == 2:
		Game.set_overdrive(0)
	Conductor.set_layers(Game.multiplier() + 1)
	queue_free()


func _draw():
	var fade = 1.0 if time < Game.OVERDRIVE_SECONDS - 0.4 else (Game.OVERDRIVE_SECONDS - time) / 0.4
	var band = WIDTH / RAINBOW.size()
	var wobble = sin(time * 30.0) * 3.0
	for i in RAINBOW.size():
		draw_rect(Rect2(0, -WIDTH / 2.0 + i * band + wobble, LENGTH, band), Color(RAINBOW[i], 0.75 * fade))
	draw_rect(Rect2(0, -WIDTH * 0.12, LENGTH, WIDTH * 0.24), Color(1, 1, 1, fade))
