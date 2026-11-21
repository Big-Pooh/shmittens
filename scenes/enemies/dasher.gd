extends EnemyBase

class_name Dasher

# Dasher mouse: waits at the right, sliding on each beat to line up with the cat's height.
# After at least one full bar it flashes on beat 4 and charges left on the next downbeat.

const DASH_SPEED = 900.0
const MAX_ALIGN_PER_BEAT = 90.0

var dashing = false


func _behave(delta):
	if dashing:
		position.x -= DASH_SPEED * delta


func on_beat(n: int):
	if dashing:
		return
	var phase = n % Conductor.BEATS_PER_BAR
	if beats_alive >= Conductor.BEATS_PER_BAR and phase == 0:
		dashing = true
		return
	var target_y = position.y
	var player = get_tree().get_first_node_in_group("player") as Node2D
	if player:
		var dy = clamp(player.global_position.y - position.y, -MAX_ALIGN_PER_BEAT, MAX_ALIGN_PER_BEAT)
		target_y = position.y + dy
		create_tween().tween_property(self, "position:y", target_y, 0.12)
	if beats_alive >= Conductor.BEATS_PER_BAR - 1 and phase == 3:
		telegraph()
		# warning-only line along the charge path (active_time 0 = never deadly)
		get_tree().current_scene.add_child(EnemyBeam.create(position.x - 40, target_y, Conductor.seconds_per_beat, 0.0))
