extends EnemyBase

class_name Turret

# Turret mouse (playtest 7 content): a sturdy dome that parks at the edge and never moves.
# On every downbeat it fires a 3-orb fan at the cat (5 when not assisted on HARD+ density):
# slow, big bullets that teach you to read and weave through orbs.

const SHOT_SPEED = 170.0


func on_beat(n: int):
	if n % Conductor.BEATS_PER_BAR == 3:
		telegraph()
	if n % Conductor.BEATS_PER_BAR != 0:
		return
	if Game.assist > 0 and (n / Conductor.BEATS_PER_BAR) % 2 == 1:
		return   # beginner care: every other bar after a game over / in Relaxed
	var player = Game.player_ref
	var aim = (player.global_position - global_position).angle() if player and is_instance_valid(player) else PI
	var count = Boss.dense(3)
	for i in count:
		fire_shot(Vector2.from_angle(aim + deg_to_rad((i - (count - 1) / 2.0) * 14.0)), SHOT_SPEED, EnemyShot.Kind.ORB)


func is_off_screen_left() -> bool:
	return false
