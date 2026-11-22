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
var message: VBoxContainer
var message_title: Label
var message_body: Label
var weapon_icons: Array[Label] = []
var weapon_hint: Label
var dance_label: Label
var armor_label: Label
var card_label: Label
var overdrive_label: Label
var current_boss: Boss
var mech_label: Label
var combo_label: Label
var fever_label: Label
var wind_label: Label
var boss_box: VBoxContainer
var boss_label: Label
var boss_bar: ProgressBar


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	Game.lives_changed.connect(_on_lives)
	Game.score_changed.connect(func(s): score_label.text = "SCORE  %06d" % s)
	Game.wave_changed.connect(func(_w): _update_wave_label())
	Game.level_changed.connect(func(_l): _update_wave_label())
	Game.charges_changed.connect(_on_charges)
	Game.gun_level_changed.connect(func(l): gun_label.text = "Lv %d" % l)
	Game.combo_changed.connect(_on_combo)
	Game.fever_changed.connect(_on_fever)
	Game.second_wind_changed.connect(func(on): wind_label.visible = on)
	_on_combo(Game.combo, Game.multiplier())
	_on_lives(Game.lives)
	score_label.text = "SCORE  %06d" % Game.score
	_update_wave_label()
	_on_charges(Game.charges, Game.cheese)
	gun_label.text = "Lv %d" % Game.gun_level
	_on_weapon(Game.weapon)
	Game.weapon_changed.connect(_on_weapon)
	Game.dance_changed.connect(_on_dance)
	boss_box.add_child(card_label)
	boss_box.add_child(armor_label)
	Game.overdrive_changed.connect(func(state):
		overdrive_label.visible = state == 1
		if state == 1 and Game.first_time("overdrive"):
			show_tip("CATNIP OVERDRIVE READY!\n50 on-beat hits in a row. Press F for 5 seconds of a giant rainbow beam - save it for a boss!"))
	Game.combo_changed.connect(func(combo, _m):
		if combo >= 10 and Game.level >= 1 and Game.first_time("companions"):
			show_tip("FRIENDS JOIN YOUR COMBO!\nEvery 10 on-beat hits in a row a companion flies in: PIP zaps, NORI shields you, KIWI shockwaves.\nThey leave if your combo breaks - keep the beat!"))
	Game.mech_parts_changed.connect(func(parts):
		if parts > 0 and Game.first_time("mech"):
			show_tip("MECH PART!\nCollect 4 mech parts (capture a spell card you hit with a spell, or reach a 75 combo)\nto pilot the PAWFRAME MK-IX: beam rifle, beam saber, armour. One per planet."))
	Game.charges_changed.connect(func(charges, _cheese):
		if charges >= 2 and Game.first_time("bomb"):
			show_tip("You have spell charges!\nDraw a spell with RIGHT-CLICK over the mice - or press X for an emergency CATNIP BOMB (uses all charges)."))
	overdrive_label.visible = Game.overdrive == 1


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

	# weapons: 1 2 3 slots (equipped one highlighted) + gun level
	var gun_box = HBoxContainer.new()
	gun_box.position = Vector2(905, 664)
	gun_box.add_theme_constant_override("separation", 6)
	add_child(gun_box)
	for i in Game.WEAPON_NAMES.size():
		var slot = _label("%d %s" % [i + 1, ["SPREAD", "LASER", "FISH"][i]], 16)
		slot.custom_minimum_size = Vector2(74, 0)
		gun_box.add_child(slot)
		weapon_icons.append(slot)
	gun_box.add_child(_icon(YARN, Vector2(28, 28)))
	gun_label = _label("", 20)
	gun_box.add_child(gun_label)
	weapon_hint = _label("", 15, Color(0.8, 0.85, 1))
	weapon_hint.position = Vector2(905, 640)
	add_child(weapon_hint)

	combo_label = _label("", 22, Color(0.6, 1, 0.7))
	combo_label.position = Vector2(490, 46)
	combo_label.size = Vector2(300, 30)
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(combo_label)

	fever_label = _label("FEVER!", 40, Color(1, 0.75, 0.2))
	fever_label.position = Vector2(0, 600)
	fever_label.size = Vector2(1280, 50)
	fever_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fever_label.hide()
	add_child(fever_label)

	wind_label = _label("SECOND WIND - enemy shots slowed", 18, Color(0.6, 0.9, 1))
	wind_label.position = Vector2(20, 630)
	wind_label.hide()
	add_child(wind_label)

	var beat_bar = BeatBar.new()
	beat_bar.position = Vector2(640 - 220, 664)
	add_child(beat_bar)

	boss_box = VBoxContainer.new()
	boss_box.position = Vector2(390, 78)
	boss_box.custom_minimum_size = Vector2(500, 0)
	boss_box.hide()
	add_child(boss_box)
	boss_label = _label("", 20, Color(1, 0.5, 0.5))
	boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_box.add_child(boss_label)
	boss_bar = ProgressBar.new()
	boss_bar.custom_minimum_size = Vector2(500, 14)
	boss_bar.show_percentage = false
	var boss_fill = StyleBoxFlat.new()
	boss_fill.bg_color = Color(0.9, 0.2, 0.3)
	boss_bar.add_theme_stylebox_override("fill", boss_fill)
	boss_box.add_child(boss_bar)

	# centre message: a big first line + smaller wrapped lines, so long text never leaves
	# the screen (playtest 2: a long message ran off the edges in fullscreen)
	message = VBoxContainer.new()
	message.position = Vector2(80, 250)
	message.size = Vector2(1120, 0)
	message.alignment = BoxContainer.ALIGNMENT_CENTER
	message.add_theme_constant_override("separation", 6)
	message.hide()
	add_child(message)
	message_title = _label("", 46, GOLD)
	message_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_title.custom_minimum_size = Vector2(1120, 0)
	message.add_child(message_title)
	message_body = _label("", 24, Color(0.92, 0.92, 1))
	message_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_body.custom_minimum_size = Vector2(1120, 0)
	message.add_child(message_body)

	dance_label = _label("DANCE BREAK!  tap SPACE on the beat", 26, Color(1, 0.6, 0.85))
	dance_label.position = Vector2(0, 560)
	dance_label.size = Vector2(1280, 40)
	dance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dance_label.hide()
	add_child(dance_label)

	armor_label = _label("", 18, Color(1, 0.85, 0.3))
	armor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_label = _label("", 20, Color(1, 0.75, 0.95))
	card_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	overdrive_label = _label("OVERDRIVE READY - press F!", 22, Color(1, 0.6, 0.9))
	overdrive_label.position = Vector2(0, 600)
	overdrive_label.size = Vector2(1280, 30)
	overdrive_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overdrive_label.hide()
	add_child(overdrive_label)

	# MECH PARTS meter (rare power-up goal), bottom-left above the skills
	mech_label = _label("", 16, Color(1, 0.85, 0.4))
	mech_label.position = Vector2(20, 606)
	mech_label.size = Vector2(420, 24)
	add_child(mech_label)
	_on_mech_parts(Game.mech_parts)
	Game.mech_parts_changed.connect(_on_mech_parts)


func _update_wave_label():
	if Game.tutorial_mode:
		wave_label.text = "TUTORIAL"
	elif Game.endless_mode:
		wave_label.text = "ENDLESS   WAVE %d" % Game.wave
	elif Game.wave < 0:
		wave_label.text = "%s   BOSS" % _planet()
	else:
		wave_label.text = "%s   WAVE %d/%d" % [_planet(), Game.wave, Game.wave_total]
	if Game.challenge != Game.Challenge.NORMAL and not Game.tutorial_mode:
		wave_label.text = Game.CHALLENGE_NAMES[Game.challenge] + "   " + wave_label.text


func _on_mech_parts(parts: int):
	var gears = ""
	for i in Game.MECH_PARTS_NEEDED:
		gears += "⚙" if i < parts else "·"
	mech_label.text = "MECH PARTS %s   (capture a card using a spell, 75-combos)" % gears
	if parts > 0:
		mech_label.pivot_offset = Vector2(0, 12)
		mech_label.scale = Vector2.ONE * 1.3
		create_tween().tween_property(mech_label, "scale", Vector2.ONE, 0.2)


func _planet() -> String:
	return Levels.LEVELS[clamp(Game.level, 0, Levels.count() - 1)].title


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


func show_boss(boss: Boss):
	boss_label.text = boss.boss_name
	boss_bar.max_value = boss.max_health
	boss_bar.value = boss.max_health
	boss_box.show()
	boss.health_changed.connect(func(health, _max): boss_bar.value = health)
	armor_label.text = ""
	card_label.text = ""
	current_boss = boss
	boss.armor_changed.connect(_on_armor)
	boss.card_started.connect(_on_card_started.bind(boss))
	boss.card_ended.connect(_on_card_ended)
	boss.died.connect(func(_b): boss_box.hide(); current_boss = null)


func _on_card_started(index: int, card_name: String, _seconds: float, boss: Boss):
	if not boss.cards[index].armored:
		armor_label.text = ""
	if card_name != "":
		_flash_text("SPELL CARD  -  " + card_name.to_upper(), Color(1, 0.75, 0.95))
	if boss.weak_spell() != "" and not Game.tips_seen.has("weakness") and Game.tips_seen.has("spell_cards"):
		Game.first_time("weakness")
		show_tip("WEAK TO %s!\nEvery spell card shows the spell it's weak to (under the health bar): that spell does DOUBLE damage.\nZIGZAG lightning also shatters beat armour." % Boss.SPELL_NAMES.get(boss.weak_spell(), ""))
	if index == 0 and Game.first_time("spell_cards"):
		show_tip("BOSS SPELL CARDS\nEvery boss attacks in named SPELL CARDS. Each one owns a slice of its health bar and has a timer.\nEmpty the slice (or outlast the timer) to move on. Do it WITHOUT getting hit or bombing\nto CAPTURE the card: big bonus + a battery. Drawn spells hit bosses hard and SHATTER beat armour -\ncapture a card you hit with a spell to earn a MECH PART.")


func _on_card_ended(_index: int, captured: bool):
	_flash_text("SPELL CARD CAPTURED!  +BONUS" if captured else "CARD FAILED", GOLD if captured else Color(0.7, 0.7, 0.8))


func flash_text(text: String, color: Color):
	_flash_text(text, color)


# A big line across the middle that fades (spell card names, captures).
func _flash_text(text: String, color: Color):
	var label = _label(text, 32, color)
	label.position = Vector2(0, 230)
	label.size = Vector2(1280, 50)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)
	var tween = label.create_tween()
	tween.tween_interval(1.2)
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(label.queue_free)


# Playtest 6: spells got forgotten -> while your charges sit full, a reminder pulses.
const FULL_CHARGE_NAG = 6.0
var full_time = 0.0
var spell_nag: Label


func _nag(delta: float):
	if spell_nag == null:
		spell_nag = _label("CHARGES FULL!  HOLD RIGHT-CLICK and draw a spell over the mice  (spells SHATTER boss armour)", 18, Color(0.6, 0.95, 1))
		spell_nag.position = Vector2(0, 574)
		spell_nag.size = Vector2(1280, 24)
		spell_nag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		spell_nag.hide()
		add_child(spell_nag)
	if Game.charges >= Game.MAX_CHARGES and not Game.drawing and not Game.tutorial_mode:
		full_time += delta
	else:
		full_time = 0.0
	spell_nag.visible = full_time > FULL_CHARGE_NAG
	if spell_nag.visible:
		spell_nag.modulate.a = 0.6 + 0.4 * sin(full_time * 5.0)


func _process(delta):
	_nag(delta)
	if current_boss and is_instance_valid(current_boss) and current_boss.card >= 0:
		var c = current_boss.cards[current_boss.card]
		var name_part = ("~ " + c.name + " ~   ") if c.name != "" else ""
		var weak = current_boss.weak_spell()
		var weak_part = ("   weak to: " + Boss.SPELL_NAMES.get(weak, "")) if weak != "" else ""
		card_label.text = "%s%ds   card %d/%d%s" % [name_part, int(ceil(max(current_boss.card_time, 0.0))), current_boss.card + 1, current_boss.cards.size(), weak_part]


func _on_armor(pips: float, stunned: bool):
	if stunned:
		armor_label.text = "ARMOUR BROKEN - HIT IT WITH EVERYTHING!"
		armor_label.add_theme_color_override("font_color", Color(0.5, 1, 1))
	else:
		armor_label.text = "ARMOUR %d - only PERFECT shots get through" % int(ceil(pips))
		armor_label.add_theme_color_override("font_color", Color(1, 0.85, 0.3))


func _on_weapon(w: int):
	for i in weapon_icons.size():
		weapon_icons[i].add_theme_color_override("font_color", GOLD if i == w else Color(0.6, 0.6, 0.7))
		weapon_icons[i].add_theme_font_size_override("font_size", 18 if i == w else 15)
	weapon_hint.text = "%s - %s" % [Game.WEAPON_NAMES[w], Game.WEAPON_HINTS[w]]


func _on_dance(active: bool):
	dance_label.visible = active


func _on_fever(active: bool):
	fever_label.visible = active
	if active:
		fever_label.pivot_offset = Vector2(640, 25)
		fever_label.scale = Vector2.ONE * 1.4
		create_tween().tween_property(fever_label, "scale", Vector2.ONE, 0.2)
		Sfx.play("jingle")


# A one-time tip box at the bottom-middle, gone after a few seconds.
func show_tip(text: String):
	var box = PanelContainer.new()
	box.position = Vector2(140, 470)
	box.custom_minimum_size = Vector2(1000, 0)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.05, 0.2, 0.88)
	style.border_color = Color(1, 0.75, 0.95)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)
	box.add_theme_stylebox_override("panel", style)
	var label = _label(text, 18, Color(1, 0.95, 1))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(970, 0)
	box.add_child(label)
	add_child(box)
	var tween = box.create_tween()
	tween.tween_interval(7.0)
	tween.tween_property(box, "modulate:a", 0.0, 0.6)
	tween.tween_callback(box.queue_free)


# First line = big title, the rest = smaller body text (both wrap).
func show_message(text: String):
	var lines = text.split("\n", true, 1)
	message_title.text = lines[0]
	message_body.text = lines[1] if lines.size() > 1 else ""
	message_body.visible = lines.size() > 1
	message.reset_size()
	message.show()


func hide_message():
	message.hide()
