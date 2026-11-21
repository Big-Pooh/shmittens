extends EnemyBase

class_name Grunt

# Robot mouse grunt: flies in from the right to its slot in the formation, then marches left
# in steps while bobbing, and sometimes fires straight ahead.
# Day 2: steps get driven by the music beat instead of STEP_INTERVAL.

const ENTRY_SPEED = 420.0
const STEP_INTERVAL = 0.5
const STEP_DISTANCE = 14.0
const BOB_AMPLITUDE = 8.0
const FIRE_CHANCE_PER_STEP = 0.04

var slot_position: Vector2   # where it settles before marching
var entering = true
var step_timer = 0.0
var bob_time = 0.0


func _ready():
	super()
	bob_time = randf() * TAU


func _physics_process(delta):
	if is_dead:
		return
	bob_time += delta
	if entering:
		position = position.move_toward(slot_position, ENTRY_SPEED * delta)
		if position.is_equal_approx(slot_position):
			entering = false
		return

	step_timer += delta
	if step_timer >= STEP_INTERVAL:
		step_timer -= STEP_INTERVAL
		step()
	sprite.position.y = sin(bob_time * 3.0) * BOB_AMPLITUDE
	if is_off_screen_left():
		queue_free()


func step():
	var tween = create_tween()
	tween.tween_property(self, "position:x", position.x - STEP_DISTANCE, 0.08)
	if randf() < FIRE_CHANCE_PER_STEP:
		fire_shot(Vector2.LEFT)
