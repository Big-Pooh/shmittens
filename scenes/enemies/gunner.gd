extends EnemyBase

class_name Gunner

# Gunner mouse: hovers at its slot and fires an aimed 3-shot spread at the cat on every downbeat
# (every 4 beats), flashing orange on the beat before as a warning. Drifts left each bar.

const SHOT_SPEED = 340.0
const DRIFT_PER_BAR = 10.0
const BOB_AMPLITUDE = 6.0

var bob_time = 0.0


func _ready():
	super()
	bob_time = randf() * TAU


func _behave(delta):
	bob_time += delta
	sprite.position.y = sin(bob_time * 2.0) * BOB_AMPLITUDE


func on_beat(n: int):
	match n % Conductor.BEATS_PER_BAR:
		3:
			telegraph()
		0:
			var player = get_tree().get_first_node_in_group("player") as Node2D
			var target = player.global_position if player else global_position + Vector2.LEFT
			var aim = (target - global_position).angle()
			for offset in [-0.18, 0.0, 0.18]:
				fire_shot(Vector2.from_angle(aim + offset), SHOT_SPEED)
			create_tween().tween_property(self, "position:x", position.x - DRIFT_PER_BAR, 0.1)
