extends CanvasLayer

class_name LevelSelect

# PLANETS (v0.12 playtest: "all the levels on the main page is not a good look"): a separate
# screen with one row per world - each planet a big button with its stars, rank and best score.

signal chosen(index: int)
signal closed


func _ready():
	layer = 60
	add_to_group("overlay_menus")
	var bg = ColorRect.new()
	bg.color = UiTheme.BG
	bg.size = Game.SCREEN.size
	add_child(bg)
	var title = Label.new()
	title.text = "CHOOSE A PLANET"
	title.position = Vector2(0, 30)
	title.size = Vector2(1280, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", UiTheme.GOLD)
	add_child(title)
	var first: Button
	for world in 2:
		var label = Label.new()
		label.text = ["WORLD 1 ~ rescue the Princess", "WORLD 2 ~ the Star of Pisitania"][world]
		label.position = Vector2(0, 110 + world * 260)
		label.size = Vector2(1280, 30)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 22)
		label.add_theme_color_override("font_color", UiTheme.PINK_LIGHT)
		add_child(label)
		var row = HBoxContainer.new()
		row.position = Vector2(110, 150 + world * 260)
		row.add_theme_constant_override("separation", 20)
		add_child(row)
		for k in 4:
			var i = world * 4 + k
			if i >= Levels.count():
				break
			var b = Button.new()
			b.custom_minimum_size = Vector2(245, 170)
			var open = i <= Game.unlocked_level and not (Game.is_demo() and i >= 4)
			if open:
				var st = Game.stars(i)
				b.text = "%d. %s\n%s\nrank %s\nbest %d" % [i + 1, Levels.LEVELS[i].title, "★".repeat(st) + "☆".repeat(3 - st),
					Game.planet_records.get("level%d" % (i + 1), {}).get("rank", "-"), Game.best_scores.get("level%d" % (i + 1), 0)]
				b.pressed.connect(func(): chosen.emit(i); queue_free())
				if first == null:
					first = b
			else:
				b.text = "%d. ???\n\n%s" % [i + 1, "full game" if Game.is_demo() and i >= 4 else "locked"]
				b.disabled = true
			row.add_child(b)
	var back = Button.new()
	back.text = "BACK"
	back.custom_minimum_size = Vector2(200, 44)
	back.position = Vector2(540, 640)
	back.pressed.connect(_close)
	add_child(back)
	if first:
		first.grab_focus()


func _close():
	closed.emit()
	queue_free()


func _input(event):
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()
