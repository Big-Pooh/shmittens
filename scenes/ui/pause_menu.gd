extends CanvasLayer

class_name PauseMenu

# Esc pauses the game: Resume, a beat-offset slider (latency calibration, saved by the
# Conductor) and Quit to title. Runs while the tree is paused.

const TITLE_SCENE = "res://scenes/ui/title.tscn"

var panel: PanelContainer
var offset_label: Label
var offset_slider: HSlider
var settings: SettingsMenu


func _ready():
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	panel.hide()
	settings = SettingsMenu.new()
	add_child(settings)


func _build():
	panel = PanelContainer.new()
	panel.position = Vector2(440, 210)
	panel.custom_minimum_size = Vector2(400, 0)
	add_child(panel)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	var title = Label.new()
	title.text = "PAUSED"
	title.add_theme_font_size_override("font_size", 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var resume = Button.new()
	resume.text = "Resume (Esc)"
	resume.pressed.connect(toggle)
	box.add_child(resume)
	offset_label = Label.new()
	offset_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(offset_label)
	offset_slider = HSlider.new()
	offset_slider.min_value = -200
	offset_slider.max_value = 200
	offset_slider.step = 5
	offset_slider.value_changed.connect(set_beat_offset)
	box.add_child(offset_slider)
	var hint = Label.new()
	hint.text = "If on-beat shots feel early, move right; if late, move left."
	hint.add_theme_font_size_override("font_size", 14)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)
	var settings_button = Button.new()
	settings_button.text = "Settings"
	settings_button.pressed.connect(func(): settings.open())
	box.add_child(settings_button)
	var quit = Button.new()
	quit.text = "Quit to title"
	quit.pressed.connect(quit_to_title)
	box.add_child(quit)


func _unhandled_input(event):
	if event.is_action_pressed("pause") and not Game.is_game_over:
		toggle()
		get_viewport().set_input_as_handled()


func is_open() -> bool:
	return panel.visible


func toggle():
	var paused = not get_tree().paused
	get_tree().paused = paused
	panel.visible = paused
	if not paused:
		settings.close()
	if paused:
		offset_slider.set_value_no_signal(Conductor.offset_ms)
		_update_label()
	var crosshair = get_tree().current_scene.get_node_or_null("Crosshair")
	if crosshair:
		crosshair.set_captured(not paused)


func set_beat_offset(value: float):
	Conductor.set_offset_ms(value)
	_update_label()


func _update_label():
	offset_label.text = "Beat offset: %+d ms" % int(Conductor.offset_ms)


func quit_to_title():
	get_tree().paused = false
	get_tree().change_scene_to_file(TITLE_SCENE)
