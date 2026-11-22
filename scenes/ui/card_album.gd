extends CanvasLayer

class_name CardAlbum

# SPELL CARD ALBUM: every boss and mid-boss spell card in the game. Captured cards show their
# art and capture count; the rest are locked "?" cards. Opened from the title screen.

signal closed


func _ready():
	layer = 60
	var bg = ColorRect.new()
	bg.color = Color(0.04, 0.03, 0.1, 1.0)
	bg.size = Game.SCREEN.size
	add_child(bg)
	var all = Game.all_cards()
	var got = all.filter(func(c): return Game.card_album.has(c.name)).size()
	var title = Label.new()
	title.text = "SPELL CARD ALBUM   %d / %d" % [got, all.size()]
	title.position = Vector2(0, 18)
	title.size = Vector2(1280, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(1, 0.82, 0.35))
	add_child(title)
	var grid = GridContainer.new()
	grid.columns = 10
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.position = Vector2(640 - (10 * 118 + 9 * 8) / 2.0 * 0.82, 64)
	grid.scale = Vector2(0.82, 0.82)
	add_child(grid)
	for c in all:
		var have = Game.card_album.has(c.name)
		grid.add_child(SpellCardView.make(Game.card_album[c.name] if have else c, false, not have))
	var hint = Label.new()
	hint.text = "Capture a boss's spell card (no hits, no bomb) to add it here.   %s - back" % Game.btn("Esc / click", "B")
	hint.position = Vector2(0, 680)
	hint.size = Vector2(1280, 24)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.85))
	add_child(hint)


func _input(event):
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel") or (event is InputEventMouseButton and event.pressed) or event.is_action_pressed("focus"):
		get_viewport().set_input_as_handled()
		closed.emit()
		queue_free()
