extends Control

# Rescue ending: the cat and the Queen together, final score. Click or any key -> title.

const TITLE_SCENE = "res://scenes/ui/title.tscn"
const CAT_SHEET = preload("res://Art/Popo-AnimationSheet.png")
const QUEEN = preload("res://Art/Generated/queen.png")
const GOLD = Color(1, 0.82, 0.25)

var cat: Sprite2D
var queen: Sprite2D
var time = 0.0
var can_leave = false


func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Engine.time_scale = 1.0
	Conductor.play("level1", 4)
	var stars = Node2D.new()
	stars.set_script(preload("res://scenes/levels/starfield.gd"))
	add_child(stars)
	add_child(_label("THE PRINCESS IS FREE!", 72, GOLD, 120))
	add_child(_label("Shmitten, Pip, Nori and Kiwi defeated Sho and brought the Princess home to Pisitania.", 24, Color(0.9, 0.9, 1), 220))
	add_child(_label("Sho has been sentenced to 1000 hours of cardio.", 20, Color(1, 0.75, 0.85), 470))
	add_child(_label("FINAL SCORE  %06d" % Game.score, 34, GOLD, 520))
	if not Game.ranks.is_empty():
		add_child(_label("RANKS   " + "  ".join(Game.ranks.map(func(r): return r)), 26, Color(0.9, 0.9, 1), 570))
	if Game.is_demo():
		add_child(_label("Thanks for playing the DEMO! Sho will be back - wishlist Shmittens! to follow the full journey.", 20, Color(1, 0.85, 0.6), 600))
		var row = HBoxContainer.new()
		row.position = Vector2(470, 640)
		row.add_theme_constant_override("separation", 16)
		add_child(row)
		for b in [["WISHLIST", func(): OS.shell_open(Game.STEAM_URL)], ["FEEDBACK", func(): Game.open_feedback()]]:
			var btn = Button.new()
			btn.text = b[0]
			btn.custom_minimum_size = Vector2(160, 40)
			btn.pressed.connect(b[1])
			row.add_child(btn)
	else:
		add_child(_label("Thanks for playing!  -  click to return to the title", 18, Color(0.7, 0.7, 0.8), 640))
	cat = Sprite2D.new()
	cat.texture = CAT_SHEET
	cat.hframes = 10
	cat.vframes = 5
	cat.scale = Vector2(3, 3)
	cat.position = Vector2(560, 390)
	add_child(cat)
	queen = Sprite2D.new()
	queen.texture = QUEEN
	queen.scale = Vector2(6, 6)
	queen.flip_h = true
	queen.position = Vector2(730, 390)
	add_child(queen)
	await get_tree().create_timer(1.0).timeout
	can_leave = true


func _label(text: String, size: int, color: Color, y: float) -> Label:
	var label = Label.new()
	label.text = text
	label.position = Vector2(0, y)
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
	cat.position.y = 390 + sin(time * 2.0) * 8.0
	queen.position.y = 390 + sin(time * 2.0 + 1.0) * 8.0


func _unhandled_input(event):
	if can_leave and ((event is InputEventMouseButton and event.pressed) or (event is InputEventKey and event.pressed)):
		get_tree().change_scene_to_file(TITLE_SCENE)
