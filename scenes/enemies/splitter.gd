extends EnemyBase

class_name Splitter

# Splitter mouse (content pass): bobs in place and fires one aimed shot every other bar. When it
# pops it splits into MINIS smaller, quicker mice that zip diagonally across the screen - shoot
# them or dodge them. Minis don't split again.

const SPLIT_SCENE = preload("res://scenes/enemies/splitter.tscn")
const MINIS = 2
const MINI_SPEED = 140.0

var is_mini = false
var mini_velocity = Vector2.ZERO
var bob = 0.0


func _behave(delta):
	if is_mini:
		position += mini_velocity * delta
		return
	bob += delta
	position.y += sin(bob * 2.5) * 0.4


func on_beat(n: int):
	if is_mini:
		return
	if n % 8 == 2 and Game.assist == 0 or n % 16 == 2:
		var player = Game.player_ref
		if player and is_instance_valid(player):
			fire_shot(player.global_position - global_position, 220.0)


func die():
	if not is_dead and not is_mini:
		for i in (1 if Game.assist > 0 else MINIS):   # beginner care: one mini when assisted
			var m = SPLIT_SCENE.instantiate()
			m.is_mini = true
			m.drops = false
			m.max_health = 1
			m.score_value = 50
			m.position = global_position + Vector2(0, -20 + 40 * i)
			m.mini_velocity = Vector2(-1.0, -0.6 + 1.2 * i).normalized() * MINI_SPEED
			m.scale = Vector2(0.6, 0.6)
			get_tree().current_scene.add_child.call_deferred(m)
	super()


func is_off_screen_left() -> bool:
	return global_position.x < -80 or global_position.y < -80 or global_position.y > 800
