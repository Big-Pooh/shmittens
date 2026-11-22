extends CanvasLayer

class_name Wardrobe

# SPRINT 4: WARDROBE & TROPHIES. Left: Shmitten's hats (locked ones say how to earn them),
# click to wear. Right: achievements with their descriptions (earned ones in gold).

signal closed


func _ready():
	layer = 60
	add_to_group("overlay_menus")
	var bg = ColorRect.new()
	bg.color = UiTheme.BG
	bg.size = Game.SCREEN.size
	add_child(bg)
	var title = Label.new()
	title.text = "WARDROBE & TROPHIES"
	title.position = Vector2(0, 16)
	title.size = Vector2(1280, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(1, 0.82, 0.35))
	add_child(title)
	var hats = GridContainer.new()
	hats.columns = 2
	hats.position = Vector2(60, 80)
	hats.add_theme_constant_override("h_separation", 10)
	hats.add_theme_constant_override("v_separation", 10)
	add_child(hats)
	for h in Progression.HATS:
		var b = Button.new()
		var ok = Progression.hat_unlocked(Game, h[0])
		b.text = ("> " if Game.hat == h[0] else "") + h[1] + ("" if ok else "\n(" + h[4] + ")")
		b.custom_minimum_size = Vector2(250, 64)
		b.disabled = not ok
		if h[0] != "none" and ResourceLoader.exists("res://Art/Generated/%s.png" % h[0]):
			b.icon = load("res://Art/Generated/%s.png" % h[0])
			b.expand_icon = false
		b.pressed.connect(func(): Game.set_hat(h[0]); _refresh())
		hats.add_child(b)
	var list = VBoxContainer.new()
	list.position = Vector2(640, 80)
	list.add_theme_constant_override("separation", 2)
	add_child(list)
	var got = 0
	for a in Progression.ACHIEVEMENTS:
		var have = Game.achievements.has(a[0])
		got += 1 if have else 0
		var l = Label.new()
		l.text = ("★ " if have else "☆ ") + a[1] + "  -  " + a[2]
		l.add_theme_font_size_override("font_size", 15)
		l.add_theme_color_override("font_color", Color(1, 0.85, 0.45) if have else Color(0.65, 0.62, 0.78))
		list.add_child(l)
	var count = Label.new()
	count.text = "%d / %d achievements" % [got, Progression.ACHIEVEMENTS.size()]
	count.add_theme_color_override("font_color", Color(0.6, 0.95, 1))
	list.add_child(count)
	var back = Button.new()
	back.text = "BACK"
	back.position = Vector2(590, 660)
	back.custom_minimum_size = Vector2(100, 40)
	back.pressed.connect(_close)
	add_child(back)


func _refresh():
	queue_free()
	var again = Wardrobe.new()
	get_parent().add_child.call_deferred(again)


func _close():
	closed.emit()
	queue_free()


func _input(event):
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()
