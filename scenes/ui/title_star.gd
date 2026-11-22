extends Node2D

class_name TitleStar

# The glowing gold star after "SHMITTENS!" - spins gently, pulses on the beat, twinkles.

var time = 0.0
var radius = 34.0


func _process(delta):
	time += delta
	queue_redraw()


static func star_points(r_out: float, r_in: float, rot: float) -> PackedVector2Array:
	var pts = PackedVector2Array()
	for i in 10:
		var r = r_out if i % 2 == 0 else r_in
		pts.append(Vector2.from_angle(-PI / 2.0 + rot + i * PI / 5.0) * r)
	return pts


func _draw():
	var beat = 1.0 - Conductor.beat_phase() if Conductor.playing else 0.0
	var r = radius * (1.0 + beat * 0.08)
	var rot = sin(time * 0.8) * 0.25
	for k in 6:
		draw_circle(Vector2.ZERO, r * (1.1 + k * 0.22), Color(1, 0.8, 0.4, 0.05))
	draw_colored_polygon(star_points(r + 7, (r + 7) * 0.47, rot), Color(0.85, 0.3, 0.6))     # pink outline
	draw_colored_polygon(star_points(r, r * 0.47, rot), Color(1, 0.82, 0.3))
	draw_colored_polygon(star_points(r * 0.62, r * 0.29, rot), Color(1, 0.93, 0.6))
	draw_circle(Vector2(-r * 0.18, -r * 0.25), r * 0.12, Color(1, 1, 1, 0.9))                 # shine
	# twinkle
	var tw = maxf(0.0, sin(time * 2.2)) 
	if tw > 0.3:
		var p = Vector2(r * 0.75, -r * 0.8)
		var s = 10.0 * tw
		draw_line(p - Vector2(s, 0), p + Vector2(s, 0), Color(1, 1, 1, tw), 2.0)
		draw_line(p - Vector2(0, s), p + Vector2(0, s), Color(1, 1, 1, tw), 2.0)
