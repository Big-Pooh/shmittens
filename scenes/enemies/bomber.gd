extends EnemyBase

class_name Bomber

# Beat-Bomber mouse (content pass): floats along under a balloon and, every other bar, drops a
# slow cartoon bomb. The bomb BURSTS on the next downbeat into a ring of rice - you hear it
# coming, so get clear before the "one".

const DRIFT = 20.0
const RING = 8


func _behave(delta):
	position.x -= DRIFT * delta


func on_beat(n: int):
	if n % 8 != 0:
		return
	if Game.assist > 0 and (n / 8) % 2 == 1:
		return
	var bomb = EnemyShot.create(global_position + Vector2(-10, 20), Vector2(-0.6, 1.0), 70.0 * Game.shot_speed_factor(), EnemyShot.Kind.ORB)
	bomb.burst_ring = Boss.dense(RING)
	get_tree().current_scene.add_child(bomb)
	Sfx.play("enemy_shoot", -8.0)
