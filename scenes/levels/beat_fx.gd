extends Node2D

class_name BeatFX

# Background rhythm hints so the beat can be felt anywhere on screen (not just the beat bar):
# - sparkles burst across the background on every beat (more, and gold, on the downbeat)
# - a soft glow pulses in from the screen edges on every beat (stronger + gold on the downbeat)
# The starfield also brightens on each beat (see starfield.gd).

const SPARKLES_PER_BEAT = 7
const SPARKLES_PER_DOWNBEAT = 16
const SPARKLE_LIFE = 0.45
const GOLD = Color(1, 0.85, 0.35)
const SOFT = Color(0.7, 0.85, 1.0)
const EDGE_BANDS = 6
const EDGE_WIDTH = 46.0

var sparkles = []   # [position, velocity, age, color, size]
var edge_glow = 0.0
var edge_color = SOFT
var edge_layer: Node2D


func _ready():
	z_index = -9   # just above the starfield, behind everything else
	Conductor.beat.connect(_on_beat)
	# edge glow sits on a canvas layer above the game, but below the HUD
	var layer = CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	edge_layer = Node2D.new()
	edge_layer.draw.connect(_draw_edges)
	layer.add_child(edge_layer)


func _on_beat(n: int):
	var downbeat = n % Conductor.BEATS_PER_BAR == 0
	var count = SPARKLES_PER_DOWNBEAT if downbeat else SPARKLES_PER_BEAT
	var color = GOLD if downbeat else SOFT
	for i in count:
		var at = Vector2(randf_range(0, Game.SCREEN.size.x), randf_range(0, Game.SCREEN.size.y))
		var velocity = Vector2.from_angle(randf() * TAU) * randf_range(20, 70)
		sparkles.append([at, velocity, 0.0, color, randf_range(2.0, 4.0) * (1.4 if downbeat else 1.0)])
	edge_glow = 1.0 if downbeat else 0.55
	edge_color = color


func _process(delta):
	# real time: hints stay in sync with the music even during slow motion
	var real_delta = delta / max(Engine.time_scale, 0.01)
	for s in sparkles:
		s[0] += s[1] * real_delta
		s[2] += real_delta
	sparkles = sparkles.filter(func(s): return s[2] < SPARKLE_LIFE)
	edge_glow = max(edge_glow - real_delta * 4.0, 0.0)
	queue_redraw()
	edge_layer.queue_redraw()


func _draw():
	for s in sparkles:
		var t = s[2] / SPARKLE_LIFE
		var size = s[4] * (1.0 - t * 0.6)
		var color = Color(s[3], (1.0 - t) * 0.9)
		# a small 4-point star
		draw_rect(Rect2(s[0] - Vector2(size, size * 0.25), Vector2(size * 2, size * 0.5)), color)
		draw_rect(Rect2(s[0] - Vector2(size * 0.25, size), Vector2(size * 0.5, size * 2)), color)


func _draw_edges():
	if edge_glow <= 0.0:
		return
	var screen = Game.SCREEN.size
	for i in EDGE_BANDS:
		var w = EDGE_WIDTH * (i + 1) / EDGE_BANDS
		var alpha = edge_glow * 0.10 * (1.0 - float(i) / EDGE_BANDS)
		var c = Color(edge_color, alpha)
		edge_layer.draw_rect(Rect2(0, 0, screen.x, w), c)
		edge_layer.draw_rect(Rect2(0, screen.y - w, screen.x, w), c)
		edge_layer.draw_rect(Rect2(0, 0, w, screen.y), c)
		edge_layer.draw_rect(Rect2(screen.x - w, 0, w, screen.y), c)
