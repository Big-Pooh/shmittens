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
	# the space scene: nebulae, stars, shooting stars, the moon (title redesign)
	add_child(TitleSpace.new())

	var title = _label("SHMITTENS!", 84, GOLD)
	title.position = Vector2(-30, 70)
	add_child(title)
	# ...followed by a glowing star
	var star = TitleStar.new()
	var font = title.get_theme_font("font")
	var w = font.get_string_size("SHMITTENS!", HORIZONTAL_ALIGNMENT_LEFT, -1, 84).x
	star.position = Vector2(640 - 30 + w / 2.0 + 52, 70 + 60)
	add_child(star)
	title.add_theme_color_override("font_outline_color", Color(0.85, 0.3, 0.6))
	title.add_theme_constant_override("outline_size", 14)
	var subtitle = _label("Sho, the buff demon lord of the mice, has kidnapped the Princess of Pisitania.\nOnly one cat - and her friends - can bring her home.", 22, UiTheme.PINK_LIGHT)
	subtitle.position = Vector2(0, 185)
	add_child(subtitle)

	cat = Sprite2D.new()
	cat.texture = CAT_SHEET
	cat.hframes = 10
	cat.vframes = 5
	cat.scale = Vector2(3, 3)
	cat.position = Vector2(640, 340)
	add_child(cat)
	var hat = Sprite2D.new()
	hat.position = Vector2(14, -17)
	var hat_path = "res://Art/Generated/%s.png" % Game.hat
	hat.texture = load(hat_path) if Game.hat != "none" and ResourceLoader.exists(hat_path) else null
	cat.add_child(hat)
	Game.hat_changed.connect(func(id):
		if not is_instance_valid(hat):
			return
		var p = "res://Art/Generated/%s.png" % id
		hat.texture = load(p) if id != "none" and ResourceLoader.exists(p) else null)

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
		# v0.12 playtest: the planet list moved to its own PLANETS screen
		var planets = Button.new()
		planets.name = "Planets"
		planets.text = "PLANETS"
		planets.custom_minimum_size = Vector2(200, 44)
		planets.pressed.connect(open_planets)
		buttons.add_child(planets)
	if Game.story_complete:
		var endless = Button.new()
		endless.text = "ENDLESS (best %d)" % Game.best_scores.get("endless", 0)
		endless.custom_minimum_size = Vector2(200, 44)
		endless.pressed.connect(start_endless)
		buttons.add_child(endless)
	var wardrobe = Button.new()
	wardrobe.text = "WARDROBE & TROPHIES"
	wardrobe.custom_minimum_size = Vector2(200, 40)
	wardrobe.pressed.connect(func():
		get_viewport().gui_release_focus()
		add_child(Wardrobe.new()))
	buttons.add_child(wardrobe)
	var album = Button.new()
	album.text = "CARD ALBUM (%d)" % Game.card_album.size()
	album.custom_minimum_size = Vector2(200, 40)
	album.pressed.connect(open_album)
	buttons.add_child(album)
	var feedback = Button.new()
	feedback.text = "FEEDBACK"
	feedback.custom_minimum_size = Vector2(200, 40)
	feedback.pressed.connect(func(): Game.open_feedback())
	buttons.add_child(feedback)
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
	_relayout(buttons)
	start.grab_focus()
	settings = SettingsMenu.new()
	add_child(settings)

	var version = _label("v" + str(ProjectSettings.get_setting("application/config/version", "dev")) + (" DEMO" if Game.is_demo() else ""), 14, Color(0.6, 0.6, 0.75))
	version.position = Vector2(1100, 690)
	version.size = Vector2(170, 20)
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(version)
	var controls = _label("WASD move  ·  mouse aims  ·  SPACE on the beat to shoot  ·  hold a mouse button and draw to cast spells  ·  Esc pause", 16, Color(0.7, 0.7, 0.8))
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


func open_album() -> CardAlbum:
	for child in get_children():
		if child is CardAlbum:
			return child
	get_viewport().gui_release_focus()
	var a = CardAlbum.new()
	add_child(a)
	return a


# Sprint 3 layout: NEW GAME + CONTINUE on top, level select below, the rest in a 3-column grid,
# all centred and clear of the controls line at the bottom.
func _relayout(grid: GridContainer):
	var items = grid.get_children()
	var layout = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	add_child(layout)
	var top = HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", 10)
	layout.add_child(top)
	var middle: Array = []
	var rest = GridContainer.new()
	rest.columns = 3
	rest.add_theme_constant_override("h_separation", 10)
	rest.add_theme_constant_override("v_separation", 8)
	for item in items:
		grid.remove_child(item)
		if item is HBoxContainer:
			middle.append(item)
			item.alignment = BoxContainer.ALIGNMENT_CENTER
			item.add_theme_constant_override("separation", 8)
		elif item.name == "Start" or (item is Button and item.text.begins_with("CONTINUE")):
			item.custom_minimum_size = Vector2(300, 48)
			top.add_child(item)
		else:
			item.custom_minimum_size = Vector2(220, 38)
			rest.add_child(item)
	for m in middle:
		layout.add_child(m)
	var center = HBoxContainer.new()
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(rest)
	layout.add_child(center)
	grid.queue_free()
	layout.custom_minimum_size = Vector2(760, 0)
	layout.position = Vector2(640 - 380, 412 - 24 * max(middle.size() - 1, 0))


func open_planets():
	get_viewport().gui_release_focus()
	var ls = LevelSelect.new()
	ls.chosen.connect(start_level)
	add_child(ls)


# Easter egg: click the cat on the title screen to pet her.
# (v0.12 playtest: it didn't work - the menu layout swallowed the click; now checked in _input
# unless a button is under the mouse)
func _input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and cat and event.position.distance_to(cat.position) < 80.0:
		if get_viewport().gui_get_hovered_control() is BaseButton:
			return
		if get_tree().get_nodes_in_group("overlay_menus").is_empty() and not (settings and settings.is_open()):
			pet_cat()


var pets = 0

func pet_cat():
	pets += 1
	Game.track("pets")
	if not Sfx.meow("pet"):
		Sfx.play("dance", -4.0)
	cat.scale = Vector2(3.4, 2.7)   # squish!
	create_tween().tween_property(cat, "scale", Vector2(3, 3), 0.25).set_trans(Tween.TRANS_BACK)
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
