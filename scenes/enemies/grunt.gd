extends EnemyBase

class_name Grunt

# Robot mouse grunt: flies in to its formation slot, then marches left one step on every
# music beat while bobbing. Firing is a fixed rotation (no randomness): on beat 3 of each bar,
# the grunts whose fire_slot matches (bar % fire_slots) shoot AT THE CAT - in a grid that's
# one column per bar, sweeping across the formation.

const STEP_DISTANCE = 14.0
const BOB_AMPLITUDE = 8.0
const FIRE_BEAT = 2   # 0-based beat in the bar (beat 3)

var bob_time = 0.0
var fire_slot = 0
var marching = true   # tutorial practice mice stay put
var fire_slots = 1


func _ready():
	super()
	bob_time = randf() * TAU


func _behave(delta):
	bob_time += delta
	sprite.position.y = sin(bob_time * 3.0) * BOB_AMPLITUDE


func on_beat(n: int):
	if marching:
		step()
	if should_fire(n):
		fire_shot(_aim_at_cat())
	elif should_fire(n + 1):
		telegraph()   # warning one beat before the volley


# Aimed volleys (playtest 1: straight-left shots were trivially dodged by changing rows).
# Never aims backwards: at worst straight left.
func _aim_at_cat() -> Vector2:
	var player = get_tree().get_first_node_in_group("player") as Node2D
	if player == null or player.global_position.x >= global_position.x:
		return Vector2.LEFT
	return player.global_position - global_position


func should_fire(n: int) -> bool:
	var bar = n / Conductor.BEATS_PER_BAR
	return n % Conductor.BEATS_PER_BAR == FIRE_BEAT and bar % fire_slots == fire_slot


func step():
	create_tween().tween_property(self, "position:x", position.x - STEP_DISTANCE, 0.08)
