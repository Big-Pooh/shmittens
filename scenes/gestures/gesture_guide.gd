extends Node2D

class_name GestureGuide

# Faded "how to draw it" outlines of the four spell shapes (playtest 2 request).
#   show_panel(true)  - while drawing in slow motion: all four shapes in a row at the top, each
#                       with its start dot and direction arrow and the skill name; the shape the
#                       current stroke looks most like lights up (set_match()).
#   show_focus(shape, at, size) - the tutorial: one big faded outline to trace.
# Shapes are in unit coordinates (-1..1), drawn in the same direction the recogniser likes
# (any direction works, the arrow is just a suggestion).

const SHAPES = ["circle", "line", "zigzag", "triangle"]
const SKILL = {"circle": "CIRCLE BURST", "line": "LINE SLASH", "zigzag": "ZIGZAG BOLT", "triangle": "TRIANGLE SHIELD"}
const COLORS = {
	"circle": Color(0.5, 0.9, 1.0),
	"line": Color(1.0, 0.4, 0.9),
	"zigzag": Color(1.0, 0.95, 0.4),
	"triangle": Color(0.4, 1.0, 0.6),
}
const PANEL_Y_TOP = 150.0
const PANEL_Y_BOTTOM = 480.0   # during boss fights, so it never covers the boss bar
var PANEL_Y = PANEL_Y_TOP
# during boss fights the guide is a small half-transparent strip at the bottom, so it never
# covers the boss bar or the space you dodge in
var compact = false
const STRIP_Y = 552.0   # (the nag line shares this row but is hidden while drawing)
const STRIP_SIZE = 14.0
const STRIP_X = [560.0, 613.0, 667.0, 720.0]
const PANEL_SIZE = 46.0
const PANEL_X = [380.0, 553.0, 727.0, 900.0]

var panel = false
var focus_shape = ""
var focus_at = Vector2.ZERO
var focus_size = 120.0
var matched = ""
var time = 0.0
var font: Font


static func points_for(shape: String) -> PackedVector2Array:
	var pts = PackedVector2Array()
	match shape:
		"circle":
			for i in 41:
				pts.append(Vector2.from_angle(-PI / 2.0 + TAU * i / 40.0))
		"line":
			pts = PackedVector2Array([Vector2(-1, 0), Vector2(1, 0)])
		"zigzag":
			pts = PackedVector2Array([Vector2(-1, -0.5), Vector2(-0.33, 0.5), Vector2(0.33, -0.5), Vector2(1, 0.5)])
		"triangle":
			pts = PackedVector2Array([Vector2(0, -1), Vector2(0.87, 0.5), Vector2(-0.87, 0.5), Vector2(0, -1)])
	return pts


func _ready():
	z_index = 60
	font = ThemeDB.fallback_font


func show_panel(on: bool):
	panel = on
	compact = on and not get_tree().get_nodes_in_group("bosses").is_empty()
	PANEL_Y = PANEL_Y_TOP
	if not on:
		matched = ""
	queue_redraw()


func set_match(shape: String):
	if shape != matched:
		matched = shape
		queue_redraw()


func show_focus(shape: String, at: Vector2 = Vector2(640, 380), size: float = 120.0):
	focus_shape = shape
	focus_at = at
	focus_size = size
	queue_redraw()


func _process(delta):
	if panel or focus_shape != "":
		time += delta
		queue_redraw()


func _draw():
	if panel and compact:
		draw_rect(Rect2(530, STRIP_Y - 22, 220, 44), Color(0, 0, 0, 0.25))
		for i in SHAPES.size():
			var shape = SHAPES[i]
			var lit = shape == matched
			draw_shape(self, shape, Vector2(STRIP_X[i], STRIP_Y), STRIP_SIZE, Color(COLORS[shape], 0.95 if lit else 0.5), 3.0 if lit else 2.0, time)
	elif panel:
		draw_rect(Rect2(300, PANEL_Y - 78, 680, 172), Color(0, 0, 0, 0.35))
		for i in SHAPES.size():
			var shape = SHAPES[i]
			var lit = shape == matched
			var alpha = 0.95 if lit else (0.35 if matched != "" else 0.6)
			draw_shape(self, shape, Vector2(PANEL_X[i], PANEL_Y), PANEL_SIZE, Color(COLORS[shape], alpha), 5.0 if lit else 3.0, time)
			var label = SKILL[shape]
			var w = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
			draw_string(font, Vector2(PANEL_X[i] - w / 2.0, PANEL_Y + PANEL_SIZE + 34), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, alpha))
	if focus_shape != "":
		draw_shape(self, focus_shape, focus_at, focus_size, Color(COLORS[focus_shape], 0.35), 10.0, time)


# Draws one shape: faded outline, start dot, an arrow along the first stretch, and a bright
# "pen" dot that traces the shape over and over so you can see how to draw it.
static func draw_shape(canvas: CanvasItem, shape: String, center: Vector2, size: float, color: Color, width: float, t: float):
	var unit = points_for(shape)
	var pts = PackedVector2Array()
	for p in unit:
		pts.append(center + p * size)
	canvas.draw_polyline(pts, color, width, true)
	canvas.draw_circle(pts[0], width * 1.6, Color(1, 1, 1, color.a))
	# arrow a quarter of the way along
	var a = _along(pts, 0.18)
	var b = _along(pts, 0.24)
	var dir = (b - a).normalized()
	if dir != Vector2.ZERO:
		var tip = b
		canvas.draw_colored_polygon(PackedVector2Array([tip + dir * width * 2.2, tip + dir.orthogonal() * width * 1.8, tip - dir.orthogonal() * width * 1.8]), Color(1, 1, 1, color.a))
	# tracing pen
	var pen = _along(pts, fmod(t * 0.6, 1.0))
	canvas.draw_circle(pen, width * 1.2, Color(1, 1, 1, min(color.a + 0.3, 1.0)))


# Point at fraction f (0..1) of the polyline's length.
static func _along(pts: PackedVector2Array, f: float) -> Vector2:
	var total = 0.0
	for i in pts.size() - 1:
		total += pts[i].distance_to(pts[i + 1])
	var want = total * clamp(f, 0.0, 1.0)
	for i in pts.size() - 1:
		var d = pts[i].distance_to(pts[i + 1])
		if want <= d and d > 0.0:
			return pts[i].lerp(pts[i + 1], want / d)
		want -= d
	return pts[pts.size() - 1]
