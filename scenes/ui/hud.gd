extends CanvasLayer

class_name Hud

# Top: lives, score + combo, wave. Bottom: skill charges + cheese meter, beat bar, gun level.
# Built in code to keep the scene file small; positions are in 1280x720 screen units.

const BATTERY = preload("res://Art/Generated/battery.png")
const CHEESE = preload("res://Art/Generated/cheese.png")
const YARN = preload("res://Art/Generated/yarn.png")
const CAT_SHEET = preload("res://Art/Popo-AnimationSheet.png")
const GOLD = Color(1, 0.82, 0.25)

var lives_box: HBoxContainer
var score_label: Label
var wave_label: Label
var charge_icons: Array[TextureRect] = []
var cheese_bar: ProgressBar
var gun_label: Label
var message: Label
var combo_label: Label


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	Game.lives_changed.connect(_on_lives)
	Game.score_changed.connect(func(s): score_label.text = "SCORE  %06d" % s)
	Game.wave_changed.connect(func(_w): _update_wave_label())
	Game.level_changed.connect(func(_l): _update_wave_label())
	Game.charges_changed.connect(_on_charges)
	Game.gun_level_changed.connect(func(l): gun_label.text = "GUN Lv %d" % l)
	Game.combo_changed.connect(_on_combo)
	_on_combo(Game.combo, Game.multiplier())
	_on_lives(Game.lives)
	score_label.text = "SCORE  %06d" % Game.score
	_update_wave_label()
	_on_charges(Game.charges, Game.cheese)
	gun_label.text = "GUN Lv %d" % Game.gun_level


func _label(text: String, size: int, color := Color.WHITE) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	return label


func _icon(texture: Texture2D, size: Vector2) -> TextureRect:
	var rect = TextureRect.new()
	rect.texture = texture
	rect.custom_minimum_size = size
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return rect


func _build():
	lives_box = HBoxContainer.new()
	lives_box.position = Vector2(20, 12)
	lives_box.add_theme_constant_override("separation", 4)
	add_child(lives_box)

	score_label = _label("", 30, GOLD)
	score_label.position = Vector2(490, 10)
	score_label.size = Vector2(300, 40)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(score_label)

	wave_label = _label("", 24)
	wave_label.position = Vector2(960, 14)
	wave_label.size = Vector2(300, 40)
	wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(wave_label)

	var bottom = HBoxContainer.new()
	bottom.position = Vector2(20, 664)
	bottom.add_theme_constant_override("separation", 8)
	add_child(bottom)
	bottom.add_child(_label("SKILLS", 22))
	for i in Game.MAX_CHARGES:
		var icon = _icon(BATTERY, Vector2(26, 40))
		charge_icons.append(icon)
		bottom.add_child(icon)
	bottom.add_child(_icon(CHEESE, Vector2(36, 28)))
	cheese_bar = ProgressBar.new()
	cheese_bar.custom_minimum_size = Vector2(140, 18)
	cheese_bar.max_value = Game.CHEESE_PER_CHARGE
	cheese_bar.show_percentage = false
	cheese_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fill = StyleBoxFlat.new()
	fill.bg_color = GOLD
	cheese_bar.add_theme_stylebox_override("fill", fill)
	bottom.add_child(cheese_bar)

	var gun_box = HBoxContainer.new()
	gun_box.position = Vector2(1080, 664)
	gun_box.add_theme_constant_override("separation", 8)
	add_child(gun_box)
	gun_box.add_child(_icon(YARN, Vector2(36, 36)))
	gun_label = _label("", 24)
	gun_box.add_child(gun_label)

	combo_label = _label("", 22, Color(0.6, 1, 0.7))
	combo_label.position = Vector2(490, 46)
	combo_label.size = Vector2(300, 30)
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(combo_label)

	var beat_bar = BeatBar.new()
	beat_bar.position = Vector2(640 - 220, 664)
	add_child(beat_bar)

	message = _label("", 48, GOLD)
	message.position = Vector2(0, 280)
	message.size = Vector2(1280, 160)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.hide()
	add_child(message)


func _update_wave_label():
	wave_label.text = "LEVEL %d   WAVE %d/%d" % [Game.level + 1, Game.wave, Game.wave_total]


func _on_lives(lives: int):
	for child in lives_box.get_children():
		child.queue_free()
	for i in lives:
		var atlas = AtlasTexture.new()
		atlas.atlas = CAT_SHEET
		atlas.region = Rect2(0, 0, 64, 48)
		lives_box.add_child(_icon(atlas, Vector2(48, 36)))


func _on_charges(charges: int, cheese: int):
	for i in charge_icons.size():
		charge_icons[i].modulate = Color.WHITE if i < charges else Color(1, 1, 1, 0.2)
	cheese_bar.value = cheese


func _on_combo(combo: int, multiplier: int):
	combo_label.visible = combo > 0
	combo_label.text = "COMBO %d   x%d" % [combo, multiplier]
	if combo > 0:
		combo_label.pivot_offset = combo_label.size / 2
		combo_label.scale = Vector2.ONE * 1.25
		create_tween().tween_property(combo_label, "scale", Vector2.ONE, 0.12)


func show_message(text: String):
	message.text = text
	message.show()


func hide_message():
	message.hide()
