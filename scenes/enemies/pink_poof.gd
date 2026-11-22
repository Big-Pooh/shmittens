extends Node2D

class_name PinkPoof

# A cartoon "poof": pink cloud puffs that swell and fade, plus a few twinkling sparkles.
# (v0.12 playtest: "I want mice to go in a pink poof when they die")

const LIFE = 0.45
var t = 0.0
var size = 1.0
var puffs: Array = []


static func create(at: Vector2, scale_k: float = 1.0) -> PinkPoof:
	var p = PinkPoof.new()
	p.position = at
	p.size = scale_k
	return p


func _ready():
	z_index = 20
	for i in 7:
		var a = TAU * i / 7.0 + randf() * 0.4
		puffs.append([Vector2.from_angle(a) * randf_range(10, 18), randf_range(9, 14)])
	puffs.append([Vector2.ZERO, 16.0])


func _process(delta):
	t += delta
	if t >= LIFE:
		queue_free()
		return
	queue_redraw()


func _draw():
	var f = t / LIFE
	var grow = (1.0 + f * 1.4) * size
	var a = 1.0 - f * f
	for p in puffs:
		draw_circle(p[0] * grow, p[1] * grow * (1.0 - 0.3 * f), Color(1, 0.62, 0.84, 0.85 * a))
	for p in puffs:
		draw_circle(p[0] * grow + Vector2(-3, -3), p[1] * grow * 0.55, Color(1, 0.88, 0.96, 0.8 * a))
	for i in 4:
		var s = Vector2.from_angle(TAU * i / 4.0 + 0.6) * (26.0 + 30.0 * f) * size
		var r = 4.0 * (1.0 - f)
		draw_line(s - Vector2(r, 0), s + Vector2(r, 0), Color(1, 1, 1, a), 2.0)
		draw_line(s - Vector2(0, r), s + Vector2(0, r), Color(1, 1, 1, a), 2.0)
