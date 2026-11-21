extends CanvasLayer

# Replaces the mouse cursor with a crosshair sprite (Day 2 makes it pulse on the beat).

const TEXTURE = preload("res://Art/Generated/crosshair.png")

var sprite: Sprite2D


func _ready():
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	sprite = Sprite2D.new()
	sprite.texture = TEXTURE
	sprite.scale = Vector2(3, 3)
	add_child(sprite)
	set_captured(true)


func _process(_delta):
	sprite.position = get_viewport().get_mouse_position()


# While playing, hide the system cursor and keep it inside the window.
func set_captured(captured: bool):
	sprite.visible = captured
	Input.mouse_mode = Input.MOUSE_MODE_CONFINED_HIDDEN if captured else Input.MOUSE_MODE_VISIBLE


func _exit_tree():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
