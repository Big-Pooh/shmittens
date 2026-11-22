extends Node2D

class_name TitleSpace

# The title screen's space scene (owner request: "a well done moon with effects, it can still be
# pink but it should be reflective of space"). All drawn in code:
#   - a deep-space gradient with drifting pink/violet nebula clouds
#   - three twinkling star layers + deterministic shooting stars
#   - THE MOON: a slowly turning sphere (craters rotate across the face and squash at the limb),
#     a soft terminator shadow, rim light, a halo that breathes with the music, orbiting sparkles
#   - a small ringed pink planet in the far corner

const MOON_C = Vector2(1090, 290)
const MOON_R = 140.0
const MOON_LIT = Color(1.0, 0.86, 0.93)
const MOON_MID = Color(0.93, 0.7, 0.84)
const MOON_DARK = Color(0.36, 0.2, 0.42)
const CRATERS = [   # [longitude, latitude, radius (fraction of R)]
	[0.2, 0.35, 0.16], [1.1, -0.2, 0.12], [2.0, 0.5, 0.1], [2.8, -0.45, 0.17], [3.6, 0.1, 0.13],
	[4.4, -0.6, 0.09], [5.2, 0.3, 0.14], [5.9, -0.15, 0.08], [0.7, -0.65, 0.07], [3.1, 0.7, 0.08],
]

var time = 0.0
var stars: Array = []   # [pos, size, layer, phase]
var nebulae: Array = []


func _ready():
	z_index = -10
	var rng = RandomNumberGenerator.new()
	rng.seed = 11
	for i in 260:
		var layer = i % 3
		stars.append([Vector2(rng.randf() * 1280, rng.randf() * 720), [0.8, 1.3, 2.0][layer], layer, rng.randf() * TAU])
	for i in 7:
		nebulae.append([Vector2(rng.randf_range(0, 1280), rng.randf_range(0, 720)), rng.randf_range(160, 320),
			[Color(1, 0.4, 0.75), Color(0.6, 0.35, 1), Color(1, 0.55, 0.6)][i % 3], rng.randf() * TAU])


func _process(delta):
	time += delta
	queue_redraw()


func _draw():
	# deep space gradient (top: inky violet, bottom: raspberry)
	for i in 24:
		var y = i * 30.0
		draw_rect(Rect2(0, y, 1280, 31), Color(0.05, 0.02, 0.1).lerp(Color(0.2, 0.05, 0.17), float(i) / 23.0))
	# nebula clouds, drifting slowly
	for n in nebulae:
		var p = n[0] + Vector2(sin(time * 0.05 + n[3]) * 40.0, cos(time * 0.04 + n[3]) * 25.0)
		for k in 7:
			draw_circle(p + Vector2(k * 9, -k * 6), n[1] * (1.0 - k * 0.12), Color(n[2], 0.022))
	# stars: far ones twinkle slowly, near ones drift
	for s in stars:
		var p: Vector2 = s[0]
		p.x = fposmod(p.x - time * (2.0 + s[2] * 5.0), 1280.0)
		var tw = 0.55 + 0.45 * sin(time * (1.2 + s[2]) + s[3])
		var c = Color(1, 0.92, 0.98, tw * (0.5 + s[2] * 0.25))
		draw_circle(p, s[1], c)
		if s[2] == 2 and tw > 0.92:   # glints on the bright ones
			draw_line(p - Vector2(5, 0), p + Vector2(5, 0), Color(1, 1, 1, 0.5), 1.0)
			draw_line(p - Vector2(0, 5), p + Vector2(0, 5), Color(1, 1, 1, 0.5), 1.0)
	_shooting_stars()
	_ringed_planet(Vector2(150, 600), 46.0)
	_moon()


func _shooting_stars():
	# one every 3.5 s, deterministic paths, 0.7 s long
	var slot = int(time / 3.5)
	var f = fmod(time, 3.5) / 0.7
	if f > 1.0:
		return
	var start = Vector2(200 + (slot * 337) % 800, 30 + (slot * 113) % 180)
	var dir = Vector2(1, 0.45).normalized()
	var head = start + dir * f * 420.0
	for k in 10:
		var a = (1.0 - k / 10.0) * (1.0 - f * 0.6)
		draw_line(head - dir * k * 9.0, head - dir * (k + 1) * 9.0, Color(1, 0.85, 0.95, a), 3.0 - k * 0.25)
	draw_circle(head, 3.0, Color(1, 1, 1, 1.0 - f * 0.5))


func _ringed_planet(c: Vector2, r: float):
	draw_circle(c, r * 1.6, Color(0.8, 0.5, 1, 0.05))
	_ellipse_arc(c, r * 2.0, r * 0.5, PI, TAU, Color(1, 0.75, 0.9, 0.55), 4.0)       # ring, back half
	draw_circle(c, r, Color(0.62, 0.42, 0.85))
	draw_circle(c + Vector2(-r * 0.25, -r * 0.25), r * 0.72, Color(0.75, 0.55, 0.95))
	for b in 3:
		draw_line(c + Vector2(-r * 0.9, -r * 0.3 + b * r * 0.3), c + Vector2(r * 0.9, -r * 0.3 + b * r * 0.3), Color(0.9, 0.7, 1, 0.25), 5.0)
	_ellipse_arc(c, r * 2.0, r * 0.5, 0.0, PI, Color(1, 0.8, 0.92, 0.8), 4.0)         # ring, front half


func _ellipse_arc(c: Vector2, rx: float, ry: float, a0: float, a1: float, col: Color, w: float):
	var pts = PackedVector2Array()
	for i in 41:
		var a = lerp(a0, a1, i / 40.0)
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(-0.25))
	draw_polyline(pts, col, w, true)


func _moon():
	var beat = 1.0 - Conductor.beat_phase() if Conductor.playing else 0.0
	# halo that breathes with the music
	for k in 10:
		draw_circle(MOON_C, MOON_R * (1.08 + k * 0.07 + beat * 0.015), Color(1, 0.6, 0.85, 0.045 - k * 0.004))
	# body + soft shading towards the dark side (light comes from the upper left)
	draw_circle(MOON_C, MOON_R, MOON_MID)
	for k in 8:
		var off = Vector2(-1, -0.8).normalized() * MOON_R * 0.06 * k
		draw_circle(MOON_C + off, MOON_R * (1.0 - k * 0.09), MOON_MID.lerp(MOON_LIT, k / 7.0))
	# rotating craters (on a sphere: x = sin(lon) cos(lat); hidden behind the limb)
	var spin = time * 0.08
	for cr in CRATERS:
		var lon = cr[0] + spin
		var lat = cr[1]
		var depth = cos(lon) * cos(lat)
		if depth <= 0.05:
			continue
		var p = MOON_C + Vector2(sin(lon) * cos(lat), sin(lat)) * MOON_R
		var rr = cr[2] * MOON_R
		var squash = Vector2(max(depth, 0.15), cos(lat) * 0.9 + 0.1)
		draw_set_transform(p, 0.0, squash)
		draw_circle(Vector2.ZERO, rr, Color(0.8, 0.55, 0.74, 0.85))
		draw_circle(Vector2(rr * 0.15, rr * 0.15), rr * 0.78, Color(0.72, 0.46, 0.68, 0.9))
		draw_arc(Vector2.ZERO, rr, PI * 1.0, PI * 1.6, 12, Color(1, 0.95, 0.98, 0.7), 2.0)   # lit rim
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# terminator: the night side on the lower right, a soft crescent of shadow
	for k in 6:
		var pts = PackedVector2Array()
		var lean = 0.35 + k * 0.08
		for i in 33:
			var a = lerp(-PI / 2.0, PI / 2.0, i / 32.0)
			pts.append(MOON_C + Vector2(cos(a), sin(a)) * MOON_R)           # right limb
		for i in 33:
			var a = lerp(PI / 2.0, -PI / 2.0, i / 32.0)
			pts.append(MOON_C + Vector2(cos(a) * MOON_R * lean, sin(a) * MOON_R))   # terminator curve
		var rot = PackedVector2Array()
		for q in pts:
			rot.append(MOON_C + (q - MOON_C).rotated(0.6))
		draw_colored_polygon(rot, Color(MOON_DARK, 0.16))
	# rim light on the lit edge + a thin glow outline
	draw_arc(MOON_C, MOON_R - 1.5, PI * 0.95, PI * 1.75, 48, Color(1, 1, 1, 0.75), 3.0, true)
	draw_arc(MOON_C, MOON_R + 2.0, 0, TAU, 96, Color(1, 0.75, 0.9, 0.35 + beat * 0.25), 2.0, true)
	# sparkles orbiting the moon
	for i in 6:
		var a = time * 0.35 + TAU * i / 6.0
		var p = MOON_C + Vector2(cos(a) * MOON_R * 1.45, sin(a) * MOON_R * 0.42).rotated(-0.3)
		if sin(a) < 0 and p.distance_to(MOON_C) < MOON_R:
			continue   # behind the moon
		var s = 3.0 + 2.0 * sin(time * 3.0 + i)
		draw_line(p - Vector2(s * 1.6, 0), p + Vector2(s * 1.6, 0), Color(1, 0.9, 0.97, 0.9), 2.0)
		draw_line(p - Vector2(0, s * 1.6), p + Vector2(0, s * 1.6), Color(1, 0.9, 0.97, 0.9), 2.0)
		draw_circle(p, s * 0.6, Color(1, 1, 1, 0.9))
