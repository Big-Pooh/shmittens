extends Control

class_name BeatBar

# Rhythm guide at the bottom centre: markers slide in from both sides and meet the centre
# ring exactly on each beat. The ring flashes on the beat. Drawn with _draw (no textures).

const LOOKAHEAD_BEATS = 3.0
const GOLD = Color(1, 0.82, 0.25)

var flash = 0.0


func _ready():
	custom_minimum_size = Vector2(440, 44)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Conductor.beat.connect(func(_n): flash = 1.0)


func _process(delta):
	flash = max(flash - delta * 5.0, 0.0)
	queue_redraw()


func _draw():
	var center = size / 2.0
	var half = size.x / 2.0 - 10.0
	draw_line(Vector2(10, center.y), Vector2(size.x - 10, center.y), Color(1, 1, 1, 0.15), 2.0)
	var position_beats = Conductor.beat_position()
	var next = ceil(position_beats)
	for i in int(LOOKAHEAD_BEATS) + 1:
		var beats_away = next + i - position_beats
		if beats_away > LOOKAHEAD_BEATS:
			continue
		var x = half * beats_away / LOOKAHEAD_BEATS
		var alpha = 1.0 - beats_away / LOOKAHEAD_BEATS
		var downbeat = int(next + i) % Conductor.BEATS_PER_BAR == 0
		var height = 26.0 if downbeat else 18.0
		var color = Color(GOLD, alpha) if downbeat else Color(1, 1, 1, alpha)
		for side in [-1, 1]:
			draw_rect(Rect2(center.x + side * x - 3, center.y - height / 2, 6, height), color)
	var ring_color = GOLD.lerp(Color.WHITE, flash)
	draw_arc(center, 14.0 + flash * 6.0, 0, TAU, 32, ring_color, 3.0)
