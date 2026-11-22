extends Control

# Title screen: game name, the flying cat, Start / Quit. Plays the level 1 drums in the background.

const MAIN_SCENE = "res://scenes/main.tscn"
const INTRO_SCENE = "res://scenes/ui/intro_story.tscn"
const CAT_SHEET = preload("res://Art/Popo-AnimationSheet.png")
const GOLD = Color(1, 0.82, 0.25)

var cat: Sprite2D
var settings: SettingsMenu
var time = 0.0


func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Engine.time_scale = 1.0
	Conductor.play("level1", 1)
	var stars = Node2D.new()
	stars.set_script(preload("res://scenes/levels/starfield.gd"))
	add_child(stars)

	var title = _label("SHMITTENS! ✰", 84, GOLD)
	title.position = Vector2(0, 70)
	add_child(title)
	var subtitle = _label("Sho, the buff demon lord of the mice, has kidnapped the Princess of Pisitania.\nOnly one cat - and her friends - can bring her home.", 22, Color(0.85, 0.85, 1))
	subtitle.position = Vector2(0, 185)
	add_child(subtitle)

	cat = Sprite2D.new()
	cat.texture = CAT_SHEET
	cat.hframes = 10
	cat.vframes = 5
	cat.scale = Vector2(3, 3)
	cat.position = Vector2(640, 340)
	add_child(cat)

	# two columns so every button fits on screen (playtest 4 added STORY + more levels)
	var buttons = GridContainer.new()
	buttons.columns = 2
	buttons.position = Vector2(425, 450)
	buttons.add_theme_constant_override("h_separation", 20)
	buttons.add_theme_constant_override("v_separation", 10)
	add_child(buttons)
	var start = Button.new()
	start.name = "Start"
	start.text = "NEW GAME" if Game.unlocked_level > 0 else "START"
	start.custom_minimum_size = Vector2(200, 50)
	start.pressed.connect(start_game)
	buttons.add_child(start)
	if Game.unlocked_level > 0:
		# saved progress: continue at the furthest level, or pick any unlocked level
		var cont = Button.new()
		cont.text = "CONTINUE (%s)" % Levels.LEVELS[Game.unlocked_level].title
		cont.custom_minimum_size = Vector2(200, 44)
		cont.pressed.connect(func(): start_level(Game.unlocked_level))
		buttons.add_child(cont)
		var row = HBoxContainer.new()
		for i in Game.unlocked_level + 1:
			var b = Button.new()
			b.text = Levels.LEVELS[i].title.substr(0, 5)
			b.tooltip_text = "%s - best %d" % [Levels.LEVELS[i].planet, Game.best_scores.get("level%d" % (i + 1), 0)]
			b.pressed.connect(start_level.bind(i))
			row.add_child(b)
		buttons.add_child(row)
	if Game.story_complete:
		var endless = Button.new()
		endless.text = "ENDLESS (best %d)" % Game.best_scores.get("endless", 0)
		endless.custom_minimum_size = Vector2(200, 44)
		endless.pressed.connect(start_endless)
		buttons.add_child(endless)
	var settings_button = Button.new()
	settings_button.text = "SETTINGS"
	settings_button.custom_minimum_size = Vector2(200, 44)
	settings_button.pressed.connect(func(): settings.open())
	buttons.add_child(settings_button)
	var tutorial = Button.new()
	tutorial.text = "TUTORIAL"
	tutorial.custom_minimum_size = Vector2(200, 44)
	tutorial.pressed.connect(start_tutorial)
	buttons.add_child(tutorial)
	var quit = Button.new()
	quit.text = "QUIT"
	quit.custom_minimum_size = Vector2(200, 44)
	quit.pressed.connect(func(): get_tree().quit())
	buttons.add_child(quit)
	start.grab_focus()
	settings = SettingsMenu.new()
	add_child(settings)

	var controls = _label("WASD move  ·  mouse aims  ·  SPACE on the beat to shoot  ·  hold right-click and draw to cast skills  ·  Esc pause", 16, Color(0.7, 0.7, 0.8))
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


# Easter egg: click the cat on the title screen to pet her.
func _unhandled_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and cat and event.position.distance_to(cat.position) < 80.0:
		pet_cat()


var pets = 0

func pet_cat():
	pets += 1
	if not Sfx.meow("pet"):
		Sfx.play("dance", -4.0)
	var heart = Label.new()
	heart.text = "♥" if pets % 10 != 0 else "♥ purrrrrr x%d ♥" % pets
	heart.add_theme_font_size_override("font_size", 30)
	heart.add_theme_color_override("font_color", Color(1, 0.5, 0.7))
	heart.position = cat.position + Vector2(randf_range(-40, 30), -70)
	add_child(heart)
	var tween = heart.create_tween()
	tween.tween_property(heart, "position:y", heart.position.y - 60, 0.9)
	tween.parallel().tween_property(heart, "modulate:a", 0.0, 0.9)
	tween.tween_callback(heart.queue_free)


func _process(delta):
	time += delta
	cat.frame = int(time * 12.0) % 10
	cat.position.y = 340 + sin(time * 2.0) * 8.0


# First time: the tutorial runs before Level 1 (it can be skipped with Tab).
func start_game():
	if not Game.difficulty_chosen:
		_ask_difficulty()
		return
	_begin_new_game()


# First START: let new players pick their challenge (changeable later in Settings).
func _ask_difficulty():
	var panel = PanelContainer.new()
	panel.name = "DifficultyChoice"
	panel.position = Vector2(390, 250)
	panel.custom_minimum_size = Vector2(500, 0)
	add_child(panel)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var q = Label.new()
	q.text = "How do you like your challenge?\n(you can change this any time in Settings)"
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(q)
	var options = [
		["RELAXED  -  slower shots, extra life, a guardian bubble", "relaxed"],
		["NORMAL  -  the intended challenge", "normal"],
		["HARD  -  faster, denser patterns, no help", "hard"],
	]
	if Game.hard_cleared:
		options.append(["BULLET HELL  -  twice the bullets, graze x3, a bomb per life", "touhou"])
	for option in options:
		var b = Button.new()
		b.text = option[0]
		b.custom_minimum_size = Vector2(0, 48)
		b.pressed.connect(choose_difficulty.bind(option[1]))
		box.add_child(b)


# difficulty: "relaxed" | "normal" | "hard" | "touhou" (old callers may pass a bool: true = relaxed)
func choose_difficulty(difficulty):
	if typeof(difficulty) == TYPE_BOOL:
		difficulty = "relaxed" if difficulty else "normal"
	Game.set_difficulty(difficulty)
	Game.difficulty_chosen = true
	Game.save_settings()
	_begin_new_game()


func _begin_new_game():
	Game.endless_mode = false
	Game.ranks.clear()
	Game.start_level = 0
	Game.start_wave = 0
	Game.clear_assist()
	Game.tutorial_mode = not Tutorial.is_done()
	# playtest 5: every NEW GAME opens with the story (Esc skips it)
	get_tree().change_scene_to_file(INTRO_SCENE if not Game.skip_intro else MAIN_SCENE)


func play_story():
	Game.endless_mode = false
	Game.tutorial_mode = false
	Game.start_level = 0
	Game.start_wave = 0
	get_tree().change_scene_to_file(INTRO_SCENE)


func start_level(index: int):
	Game.endless_mode = false
	Game.tutorial_mode = false
	Game.ranks.clear()
	Game.start_level = index
	Game.start_wave = 0
	Game.clear_assist()
	get_tree().change_scene_to_file(MAIN_SCENE)


func start_endless():
	Game.endless_mode = true
	Game.tutorial_mode = false
	Game.start_wave = 0
	Game.clear_assist()
	get_tree().change_scene_to_file(MAIN_SCENE)


func start_tutorial():
	Game.endless_mode = false
	Game.start_wave = 0
	Game.clear_assist()
	Game.tutorial_mode = true
	get_tree().change_scene_to_file(MAIN_SCENE)
