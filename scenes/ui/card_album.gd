extends CanvasLayer

class_name CardAlbum

# SPELL CARD ALBUM: every boss and mid-boss spell card in the game. Captured cards show their
# art and capture count; the rest are locked "?" cards. Opened from the title screen.

signal closed


var inspect: Control   # the enlarged card being inspected (v0.12 playtest)


func _ready():
	layer = 60
	add_to_group("overlay_menus")
	var bg = ColorRect.new()
	bg.color = UiTheme.BG
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
		var entry = Game.card_album[c.name] if have else c
		var view = SpellCardView.make(entry, false, not have)
		view.mouse_filter = Control.MOUSE_FILTER_STOP
		view.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT: _inspect(entry, have))
		grid.add_child(view)
	var hint = Label.new()
	hint.text = "Click a card to inspect it.  Capture a boss's spell card (no hits, no bomb) to add it here.   %s - back" % Game.btn("Esc / right-click", "B")
	hint.position = Vector2(0, 680)
	hint.size = Vector2(1280, 24)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.85))
	add_child(hint)


func _inspect(entry: Dictionary, have: bool):
	if inspect:
		return
	inspect = Control.new()
	inspect.size = Game.SCREEN.size
	inspect.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(inspect)
	var dim = ColorRect.new()
	dim.color = Color(0.05, 0.02, 0.08, 0.85)
	dim.size = Game.SCREEN.size
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inspect.add_child(dim)
	var big = SpellCardView.make(entry, false, not have)
	big.scale = Vector2(2.6, 2.6)
	big.position = Vector2(300, 360 - SpellCardView.CARD_SIZE.y * 1.3)
	big.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inspect.add_child(big)
	var info = Label.new()
	info.position = Vector2(680, 210)
	info.size = Vector2(520, 320)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD
	info.add_theme_font_size_override("font_size", 22)
	if have:
		var weak = entry.get("weak", "")
		info.text = "%s\n\nBoss: %s\nWeak to: %s %s (double damage)\nCaptured: %d time%s\n\nCapture again for another bonus and a battery." % [
			entry.get("name", ""), str(entry.get("boss", "")).capitalize(), Game.SPELL_ICONS.get(weak, ""), Game.SPELL_TITLES.get(weak, "-"),
			entry.get("captures", 1), "" if entry.get("captures", 1) == 1 else "s"]
	else:
		info.text = "???\n\nBoss: %s\n\nNot captured yet. Clear this spell card without getting hit or bombing to win it." % str(entry.get("boss", "?")).capitalize()
	inspect.add_child(info)
	var hint = Label.new()
	hint.text = "click anywhere to go back"
	hint.position = Vector2(0, 640)
	hint.size = Vector2(1280, 24)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color(0.85, 0.7, 0.85))
	inspect.add_child(hint)
	inspect.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: _close_inspect())


func _close_inspect():
	if inspect:
		inspect.queue_free()
		inspect = null


func _input(event):
	var back = event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("focus") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT)
	if back:
		get_viewport().set_input_as_handled()
		if inspect:
			_close_inspect()
			return
		closed.emit()
		queue_free()
