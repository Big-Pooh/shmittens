extends Node2D

class_name EnemyBeam

# Horizontal enemy laser from x=0 to `right_x` at a fixed height.
# Shows a thin warning line for `warn_time`, then is deadly for `active_time`.
# The cat is hit if its centre is within half the beam width. A shield blocks it (via hit()).

const WIDTH = 38.0
const COLOR = Color(1.0, 0.3, 0.3)

var right_x = 1280.0
var warn_time = 0.5
var active_time = 0.4
var time = 0.0


static func create(from_right_x: float, y: float, warning: float, active: float) -> EnemyBeam:
	var beam = EnemyBeam.new()
	beam.right_x = from_right_x
	beam.position = Vector2(0, y)
	beam.warn_time = warning
	beam.active_time = active
	return beam


func _ready():
	z_index = 15


func is_active() -> bool:
	return time >= warn_time and time < warn_time + active_time


func hits(point: Vector2) -> bool:
	return point.x <= right_x and absf(point.y - global_position.y) <= WIDTH / 2.0


func _process(delta):
	time += delta
	if is_active():
		var player = get_tree().get_first_node_in_group("player")
		if player and hits(player.global_position):
			player.hit("beam")
	queue_redraw()
	if time >= warn_time + active_time:
		queue_free()


func _draw():
	if time < warn_time:
		# blinking warning line
		var alpha = 0.7 if int(time * 12.0) % 2 == 0 else 0.25
		draw_line(Vector2(0, 0), Vector2(right_x, 0), Color(COLOR, alpha), 3.0)
	else:
		var fade = 1.0 - (time - warn_time) / active_time
		draw_rect(Rect2(0, -WIDTH / 2.0, right_x, WIDTH), Color(COLOR, 0.6 * fade))
		draw_rect(Rect2(0, -WIDTH * 0.2, right_x, WIDTH * 0.4), Color(1, 1, 1, fade))
