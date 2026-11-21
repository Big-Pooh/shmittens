extends Node2D

# Scrolling 3-layer starfield drawn with rectangles (no texture needed).
# Stars brighten and grow briefly on every beat (more on the downbeat) as a rhythm hint.

const STAR_COUNT = 140
const LAYER_SPEEDS = [30.0, 70.0, 140.0]
const LAYER_SIZES = [2.0, 3.0, 4.0]
const LAYER_ALPHAS = [0.35, 0.6, 0.9]

var stars = []   # [position, layer]


func _ready():
	z_index = -10
	for i in STAR_COUNT:
		stars.append([Vector2(randf() * Game.SCREEN.size.x, randf() * Game.SCREEN.size.y), randi() % 3])


func _process(delta):
	for star in stars:
		star[0].x -= LAYER_SPEEDS[star[1]] * delta
		if star[0].x < 0:
			star[0] = Vector2(Game.SCREEN.size.x, randf() * Game.SCREEN.size.y)
	queue_redraw()


func _draw():
	# pulse: 1 on the beat, fading over the first ~third of the beat
	var phase = Conductor.beat_phase() if Conductor.playing else 1.0
	var pulse = pow(max(1.0 - phase * 3.0, 0.0), 2.0)
	if Conductor.playing and int(floor(Conductor.beat_position())) % Conductor.BEATS_PER_BAR == 0:
		pulse *= 1.5
	for star in stars:
		var size = LAYER_SIZES[star[1]] * (1.0 + pulse * 0.6)
		var alpha = min(LAYER_ALPHAS[star[1]] * (1.0 + pulse * 1.2), 1.0)
		draw_rect(Rect2(star[0], Vector2(size, size)), Color(1, 1, 1, alpha))
