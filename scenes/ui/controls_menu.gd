extends CanvasLayer

class_name ControlsMenu

# SPRINT 5: key rebinding. Click an action, press a key; saved in settings.cfg [controls] and
# re-applied at startup (Game.apply_bindings). Gamepad and mouse bindings are kept as they are.

const ACTIONS = [
	["move_up", "Move up"], ["move_down", "Move down"], ["move_left", "Move left"], ["move_right", "Move right"],
	["shoot", "Shoot"], ["focus", "Focus (slow)"], ["bomb", "Bomb"], ["overdrive", "Overdrive"],
	["weapon_prev", "Previous weapon"], ["weapon_next", "Next weapon"],
]

var waiting = ""
var buttons = {}


func _ready():
	layer = 97
	var bg = ColorRect.new()
	bg.color = Color(0.04, 0.03, 0.1, 1.0)
	bg.size = Game.SCREEN.size
	add_child(bg)
	var title = Label.new()
	title.text = "CONTROLS  -  click an action, then press a key"
	title.position = Vector2(0, 30)
	title.size = Vector2(1280, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1, 0.82, 0.35))
	add_child(title)
	var grid = GridContainer.new()
	grid.columns = 2
	grid.position = Vector2(390, 100)
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 8)
	add_child(grid)
	for a in ACTIONS:
		var l = Label.new()
		l.text = a[1]
		l.custom_minimum_size = Vector2(220, 40)
		grid.add_child(l)
		var b = Button.new()
		b.custom_minimum_size = Vector2(240, 40)
		b.pressed.connect(func(): waiting = a[0]; b.text = "press a key..."; get_viewport().gui_release_focus())
		grid.add_child(b)
		buttons[a[0]] = b
	var row = HBoxContainer.new()
	row.position = Vector2(470, 630)
	row.add_theme_constant_override("separation", 20)
	add_child(row)
	var reset = Button.new()
	reset.text = "RESET DEFAULTS"
	reset.pressed.connect(func(): Game.reset_bindings(); _refresh())
	row.add_child(reset)
	var back = Button.new()
	back.text = "BACK"
	back.custom_minimum_size = Vector2(120, 0)
	back.pressed.connect(queue_free)
	row.add_child(back)
	_refresh()


func _refresh():
	for a in ACTIONS:
		buttons[a[0]].text = Game.key_name(a[0])


func _input(event):
	if waiting != "" and event is InputEventKey and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		if event.physical_keycode != KEY_ESCAPE:
			Game.rebind(waiting, event.physical_keycode)
		waiting = ""
		_refresh()
	elif waiting == "" and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		queue_free()
