extends Node2D

class_name PlanetBackdrop

# A big planet slowly turning in the background of each level (playtest 4: a journey across
# planets). Colour comes from Levels.LEVELS[level].planet_color; drawn behind everything.

var color = Color(1, 0.7, 0.55)
var time = 0.0


func _ready():
	z_index = -50


func set_level(index: int):
	if index >= 0 and index < Levels.count():
		color = Levels.LEVELS[index].get("planet_color", color)
	queue_redraw()


func _process(delta):
	time += delta
	queue_redraw()


func _draw():
	var center = Vector2(1180, 860)
	var r = 420.0
	var dim = Color(color, 0.35)
	draw_circle(center, r + 30.0, Color(color, 0.06))
	draw_circle(center, r, dim)
	# drifting bands
	for i in 5:
		var y = center.y - r + 70.0 + i * 70.0 + fmod(time * 6.0, 70.0)
		var half = sqrt(max(r * r - pow(y - center.y, 2), 0.0))
		draw_line(Vector2(center.x - half, y), Vector2(center.x + half, y), Color(color.lightened(0.25), 0.18), 14.0)
	draw_arc(center, r, PI * 1.05, PI * 1.6, 48, Color(1, 1, 1, 0.18), 6.0)
