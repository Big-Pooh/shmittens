extends Node2D

class_name QueenCage

# The captured Queen during the final boss fight: her sprite inside cage bars drawn in code.
# release() opens the cage and flies her to the cat.

const QUEEN = preload("res://Art/Generated/queen.png")
const SIZE = Vector2(90, 100)

var bars_alpha = 1.0
var sprite: Sprite2D
var time = 0.0


func _ready():
	z_index = -1
	sprite = Sprite2D.new()
	sprite.texture = QUEEN
	sprite.scale = Vector2(4, 4)
	sprite.flip_h = true   # looking toward the cat
	add_child(sprite)


func _process(delta):
	time += delta
	sprite.position.y = sin(time * 2.0) * 3.0
	queue_redraw()


func _draw():
	if bars_alpha <= 0.0:
		return
	var color = Color(0.75, 0.75, 0.85, bars_alpha)
	var half = SIZE / 2.0
	draw_rect(Rect2(-half, SIZE), color, false, 4.0)
	for i in range(1, 6):
		var x = -half.x + SIZE.x * i / 6.0
		draw_line(Vector2(x, -half.y), Vector2(x, half.y), color, 3.0)
	draw_line(Vector2(0, -half.y - 30), Vector2(0, -half.y), color, 3.0)   # chain


func release(to: Vector2):
	var tween = create_tween()
	tween.tween_property(self, "bars_alpha", 0.0, 0.6)
	tween.tween_property(self, "global_position", to + Vector2(70, -10), 1.5).set_trans(Tween.TRANS_SINE)
