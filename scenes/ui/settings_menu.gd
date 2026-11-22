extends CanvasLayer

class_name SettingsMenu

# Settings panel used by the title screen and the pause menu. Changes apply immediately and are
# saved to user://settings.cfg (via Game). Works while the game is paused.

signal closed

var panel: PanelContainer
var music: HSlider
var sfx: HSlider
var fullscreen: CheckButton
var reduce: CheckButton
var relaxed: CheckButton


func _ready():
	layer = 95
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel = PanelContainer.new()
	panel.position = Vector2(420, 150)
	panel.custom_minimum_size = Vector2(440, 0)
	add_child(panel)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var title = Label.new()
	title.text = "SETTINGS"
	title.add_theme_font_size_override("font_size", 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	music = _slider(box, "Music volume", Game.music_volume, func(v): Game.music_volume = v; _changed())
	sfx = _slider(box, "Sound effects volume", Game.sfx_volume, func(v): Game.sfx_volume = v; _changed())
	fullscreen = _check(box, "Fullscreen", Game.fullscreen, func(on): Game.fullscreen = on; _changed())
	reduce = _check(box, "Reduce effects (no screen shake, softer flashes)", Game.reduce_effects, func(on): Game.reduce_effects = on; _changed())
	relaxed = _check(box, "Relaxed mode (slower shots, +1 life, guardian bubble)", Game.relaxed_mode, func(on): _set_relaxed(on))
	var back = Button.new()
	back.text = "Back"
	back.pressed.connect(close)
	box.add_child(back)
	panel.hide()


func _slider(box: VBoxContainer, text: String, value: float, on_change: Callable) -> HSlider:
	var label = Label.new()
	label.text = text
	box.add_child(label)
	var slider = HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	slider.value_changed.connect(on_change)
	box.add_child(slider)
	return slider


func _check(box: VBoxContainer, text: String, value: bool, on_toggle: Callable) -> CheckButton:
	var check = CheckButton.new()
	check.text = text
	check.button_pressed = value
	check.toggled.connect(on_toggle)
	box.add_child(check)
	return check


func _set_relaxed(on: bool):
	Game.relaxed_mode = on
	if on:
		Game.assist = max(Game.assist, 1)
	_changed()


func _changed():
	Game.apply_settings()
	Game.save_settings()


func is_open() -> bool:
	return panel.visible


func open():
	music.set_value_no_signal(Game.music_volume)
	sfx.set_value_no_signal(Game.sfx_volume)
	fullscreen.set_pressed_no_signal(Game.fullscreen)
	reduce.set_pressed_no_signal(Game.reduce_effects)
	relaxed.set_pressed_no_signal(Game.relaxed_mode)
	panel.show()


func close():
	panel.hide()
	closed.emit()
