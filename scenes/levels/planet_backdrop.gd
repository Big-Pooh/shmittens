extends Node2D

class_name PlanetBackdrop

# Each planet's background (presentation pass, design review): the big planet turning in the
# corner + TWO PARALLAX LAYERS + an AMBIENT EFFECT, all drawn in code:
#   far layer  - nebula blobs and little moons drifting slowly
#   near layer - a silhouette skyline that tells you where you are, scrolling faster
#   ambient    - factory sparks / sewer drips / castle petals / Flexor embers
# Theme comes from Levels.LEVELS[level].theme ("factory", "sewer", "castle", "fortress").

const FAR_SPEED = 12.0
const NEAR_SPEED = 45.0
const PARTICLES = 40

var color = Color(1, 0.7, 0.55)
var theme = "factory"
var time = 0.0
var particles: Array = []   # [pos, vel, life]
var rng = RandomNumberGenerator.new()


func _ready():
	z_index = -50
	rng.seed = 7


func set_level(index: int):
	if index >= 0 and index < Levels.count():
		color = Levels.LEVELS[index].get("planet_color", color)
		theme = Levels.LEVELS[index].get("theme", "factory")
	particles.clear()
	queue_redraw()


func _process(delta):
	time += delta
	_update_particles(delta)
	queue_redraw()


func _spawn_particle() -> Array:
	match theme:
		"sewer":   # drips falling from the pipes
			return [Vector2(rng.randf_range(0, 1280), rng.randf_range(560, 600)), Vector2(0, 160), 1.0]
		"castle":  # petals drifting down and left
			return [Vector2(rng.randf_range(200, 1400), -10), Vector2(rng.randf_range(-60, -20), rng.randf_range(30, 60)), 8.0]
		"fortress":  # embers rising
			return [Vector2(rng.randf_range(0, 1280), 730), Vector2(rng.randf_range(-15, 15), rng.randf_range(-70, -40)), 6.0]
		"cheese":  # cheese crumbs drifting on the wind
			return [Vector2(1300, rng.randf_range(100, 640)), Vector2(rng.randf_range(-90, -50), rng.randf_range(-8, 8)), 16.0]
		"disco":  # confetti
			return [Vector2(rng.randf_range(0, 1280), -10), Vector2(rng.randf_range(-20, 20), rng.randf_range(40, 90)), 10.0]
		"ice":  # snow
			return [Vector2(rng.randf_range(0, 1400), -10), Vector2(rng.randf_range(-40, -10), rng.randf_range(30, 70)), 14.0]
		"summit":  # wind streaks
			return [Vector2(1300, rng.randf_range(60, 560)), Vector2(rng.randf_range(-320, -220), 0), 6.0]
		_:         # factory sparks popping from the chimney tops
			var chimney = int(rng.randf_range(0, 6))
			var x = fposmod(chimney * 240.0 + 75.0 - time * NEAR_SPEED, 1440.0) - 80.0
			return [Vector2(x, 540), Vector2(rng.randf_range(-40, 40), rng.randf_range(-120, -60)), 0.9]


func _update_particles(delta):
	while particles.size() < PARTICLES:
		particles.append(_spawn_particle())
	for p in particles:
		p[0] += p[1] * delta
		if theme == "factory":
			p[1].y += 140.0 * delta   # sparks arc back down
		p[2] -= delta
	particles = particles.filter(func(p): return p[2] > 0.0 and p[0].y < 760 and p[0].y > -40)


func _draw():
	# far layer: nebula blobs + small moons
	for i in 5:
		var x = fposmod(i * 330.0 - time * FAR_SPEED, 1600.0) - 160.0
		var y = 120.0 + (i * 97 % 300)
		draw_circle(Vector2(x, y), 90.0 + (i % 3) * 30.0, Color(color.lightened(0.2), 0.035))
		draw_circle(Vector2(x + 210, y + 60), 7.0 + (i % 2) * 5.0, Color(color.lightened(0.4), 0.25))
	# the big planet
	var center = Vector2(1180, 860)
	var r = 420.0
	draw_circle(center, r + 30.0, Color(color, 0.06))
	draw_circle(center, r, Color(color, 0.32))
	for i in 5:
		var y = center.y - r + 70.0 + i * 70.0 + fmod(time * 6.0, 70.0)
		var half = sqrt(max(r * r - pow(y - center.y, 2), 0.0))
		draw_line(Vector2(center.x - half, y), Vector2(center.x + half, y), Color(color.lightened(0.25), 0.16), 14.0)
	draw_arc(center, r, PI * 1.05, PI * 1.6, 48, Color(1, 1, 1, 0.18), 6.0)
	# near layer: the planet's skyline silhouette
	var sil = Color(color.darkened(0.65), 0.55)
	var offset = fmod(time * NEAR_SPEED, 240.0)
	for k in 8:
		var x = k * 240.0 - offset - 120.0
		match theme:
			"sewer":
				draw_rect(Rect2(x, 600, 240, 22), sil)
				draw_rect(Rect2(x + 60, 560, 26, 60), sil)
				draw_circle(Vector2(x + 73, 560), 20.0, sil)
			"castle":
				draw_rect(Rect2(x + 40, 520, 60, 200), sil)
				for b in 3:
					draw_rect(Rect2(x + 40 + b * 22, 506, 14, 16), sil)
				draw_rect(Rect2(x + 68, 470, 3, 40), sil)
				draw_colored_polygon(PackedVector2Array([Vector2(x + 71, 470), Vector2(x + 96, 478 + sin(time * 4 + k) * 4), Vector2(x + 71, 486)]), Color(color.lightened(0.2), 0.5))
				draw_rect(Rect2(x + 100, 600, 140, 120), sil)
			"cheese":
				draw_circle(Vector2(x + 120, 700), 140.0, sil)                 # dunes
				draw_circle(Vector2(x + 60, 640), 10.0, Color(color.darkened(0.4), 0.6))   # holes
			"disco":
				for b in 5:   # equalizer bars bouncing with the beat
					var hgt = 40.0 + 70.0 * absf(sin(time * 3.0 + k * 1.3 + b)) * (1.0 - Conductor.beat_phase() * 0.5)
					draw_rect(Rect2(x + 20 + b * 42, 720 - hgt, 30, hgt), Color(color.lightened(0.1 * b), 0.35))
			"ice":
				draw_colored_polygon(PackedVector2Array([Vector2(x, 720), Vector2(x + 60, 560), Vector2(x + 120, 720)]), sil)
				draw_colored_polygon(PackedVector2Array([Vector2(x + 140, 0), Vector2(x + 160, 70), Vector2(x + 180, 0)]), Color(0.8, 0.95, 1, 0.25))
			"summit":
				draw_colored_polygon(PackedVector2Array([Vector2(x - 40, 720), Vector2(x + 110, 470 + (k % 3) * 40), Vector2(x + 260, 720)]), sil)
				draw_colored_polygon(PackedVector2Array([Vector2(x + 85, 500 + (k % 3) * 40), Vector2(x + 110, 470 + (k % 3) * 40), Vector2(x + 135, 500 + (k % 3) * 40)]), Color(1, 1, 1, 0.35))
			"fortress":
				draw_rect(Rect2(x + 30, 540, 34, 180), sil)
				draw_rect(Rect2(x + 120, 590, 90, 14), sil)
				draw_circle(Vector2(x + 120, 597), 24.0, sil)
				draw_circle(Vector2(x + 210, 597), 24.0, sil)
			_:
				draw_rect(Rect2(x + 20, 600, 200, 120), sil)
				draw_rect(Rect2(x + 60, 540, 30, 70), sil)
				draw_rect(Rect2(x + 150, 570, 24, 40), sil)
	# ambient particles
	var pcol = {"sewer": Color(0.6, 1, 0.85, 0.7), "castle": Color(1, 0.7, 0.85, 0.8), "fortress": Color(1, 0.55, 0.35, 0.8),
		"cheese": Color(1, 0.88, 0.4, 0.8), "ice": Color(1, 1, 1, 0.85), "summit": Color(1, 1, 1, 0.25)}.get(theme, Color(1, 0.85, 0.4, 0.9))
	for idx in particles.size():
		var p = particles[idx]
		if theme == "summit":
			draw_line(p[0], p[0] + Vector2(60, 0), pcol, 2.0)
		elif theme == "disco":
			draw_rect(Rect2(p[0], Vector2(4, 6)), Color.from_hsv(fmod(idx * 0.13, 1.0), 0.6, 1.0, 0.8))
		else:
			draw_circle(p[0], 2.5 if theme != "castle" else 3.5, pcol)
