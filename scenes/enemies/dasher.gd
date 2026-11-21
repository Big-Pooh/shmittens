extends EnemyBase

class_name Dasher

# Dasher mouse: waits at the right, sliding on each beat to line up with the cat's height.
# After about a bar it flashes on beat 3, shows its line for 2 beats, then charges on the downbeat.

const DASH_SPEED = 900.0
const MAX_ALIGN_PER_BEAT = 90.0

var dashing = false
var locked = false   # warned + line fixed; charges on the next downbeat


func _behave(delta):
	if dashing:
		position.x -= DASH_SPEED * delta


func on_beat(n: int):
	if dashing:
		return
	var phase = n % Conductor.BEATS_PER_BAR
	if locked and phase == 0:
		dashing = true
		return
	if locked:
		return
	var target_y = position.y
	var player = get_tree().get_first_node_in_group("player") as Node2D
	if player:
		var dy = clamp(player.global_position.y - position.y, -MAX_ALIGN_PER_BEAT, MAX_ALIGN_PER_BEAT)
		target_y = position.y + dy
		create_tween().tween_property(self, "position:y", target_y, 0.12)
	# after at least ~a bar: warn on beat 3, lock the line, charge on the next downbeat (2 beats)
	if beats_alive >= Conductor.BEATS_PER_BAR - 2 and phase == 2:
		locked = true
		telegraph()
		get_tree().current_scene.add_child(EnemyBeam.create(position.x - 40, target_y, Conductor.seconds_per_beat * 2.0, 0.0))
