extends Node2D

# Scrolling 3-layer starfield drawn with rectangles (no texture needed).

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
	for star in stars:
		var size = LAYER_SIZES[star[1]]
		draw_rect(Rect2(star[0], Vector2(size, size)), Color(1, 1, 1, LAYER_ALPHAS[star[1]]))
