extends Control

# Title screen: game name, the flying cat, Start / Quit. Plays the level 1 drums in the background.

const MAIN_SCENE = "res://scenes/main.tscn"
const CAT_SHEET = preload("res://Art/Popo-AnimationSheet.png")
const GOLD = Color(1, 0.82, 0.25)

var cat: Sprite2D
var time = 0.0


func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Engine.time_scale = 1.0
	Conductor.play("level1", 1)
	var stars = Node2D.new()
	stars.set_script(preload("res://scenes/levels/starfield.gd"))
	add_child(stars)

	var title = _label("SHMITTENS! ✰", 84, GOLD)
	title.position = Vector2(0, 110)
	add_child(title)
	var subtitle = _label("The Rat King has kidnapped the Queen.\nOnly one cat can save her.", 24, Color(0.85, 0.85, 1))
	subtitle.position = Vector2(0, 230)
	add_child(subtitle)

	cat = Sprite2D.new()
	cat.texture = CAT_SHEET
	cat.hframes = 10
	cat.vframes = 5
	cat.scale = Vector2(3, 3)
	cat.position = Vector2(640, 380)
	add_child(cat)

	var buttons = VBoxContainer.new()
	buttons.position = Vector2(540, 470)
	buttons.custom_minimum_size = Vector2(200, 0)
	buttons.add_theme_constant_override("separation", 12)
	add_child(buttons)
	var start = Button.new()
	start.name = "Start"
	start.text = "START"
	start.custom_minimum_size = Vector2(200, 50)
	start.pressed.connect(start_game)
	buttons.add_child(start)
	var quit = Button.new()
	quit.text = "QUIT"
	quit.custom_minimum_size = Vector2(200, 44)
	quit.pressed.connect(func(): get_tree().quit())
	buttons.add_child(quit)
	start.grab_focus()

	var controls = _label("WASD move  ·  click on the beat to shoot  ·  hold right-click and draw to cast skills  ·  Esc pause", 16, Color(0.7, 0.7, 0.8))
	controls.position = Vector2(0, 670)
	add_child(controls)


func _label(text: String, size: int, color: Color) -> Label:
	var label = Label.new()
	label.text = text
	label.size = Vector2(1280, 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 8)
	return label


func _process(delta):
	time += delta
	cat.frame = int(time * 12.0) % 10
	cat.position.y = 380 + sin(time * 2.0) * 10.0


func start_game():
	Game.start_level = 0
	get_tree().change_scene_to_file(MAIN_SCENE)
