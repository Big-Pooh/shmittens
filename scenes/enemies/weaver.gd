extends EnemyBase

class_name Weaver

# Weaver mouse (playtest 7 content): weaves up and down in a sine wave while drifting slowly
# left, and fires one small rice bullet on every off-beat hi-hat - a moving, rhythmic target
# that rewards aiming (or Fish). Each weaver's wave is phase-shifted so a group forms a ribbon.

const WEAVE_AMPLITUDE = 70.0
const WEAVE_BEATS = 4.0          # one full weave every 4 beats
const DRIFT_SPEED = 14.0
const SHOT_SPEED = 230.0

var base_y = 0.0
var phase_offset = 0.0
var hat_count = 0


func _ready():
	super()
	Conductor.eighth.connect(_on_eighth)


func _behave(delta):
	if base_y == 0.0:
		base_y = position.y
		phase_offset = position.x * 0.01
	var t = Conductor.beat_position() / WEAVE_BEATS * TAU + phase_offset
	position.y = base_y + sin(t) * WEAVE_AMPLITUDE
	position.x -= DRIFT_SPEED * delta


func _on_eighth(n: int):
	if entering or is_dead or not is_inside_tree() or n % 2 == 0:
		return
	hat_count += 1
	# beginner care: only every other hat while assisted
	if Game.assist > 0 and hat_count % 2 == 0:
		return
	if hat_count % 2 == 0:
		fire_shot(Vector2.LEFT.rotated(randf_range(-0.15, 0.15)), SHOT_SPEED, EnemyShot.Kind.RICE)
