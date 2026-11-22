extends Control

# The opening story (playtest 4), told in 5 picture-book panels drawn in code:
#   Pisitania -> Sho attacks -> the Princess is taken -> Shmitten and friends -> the journey.
# SPACE / click: next panel. Esc: skip. Then the game starts (tutorial first if not done).
# Shown before the first NEW GAME; the title's STORY button replays it.

const MAIN_SCENE = "res://scenes/main.tscn"
const CAT_SHEET = preload("res://Art/Popo-AnimationSheet.png")
const SHO = preload("res://Art/Generated/boss_sho.png")
const PRINCESS = preload("res://Art/Generated/queen.png")
const GRUNT = preload("res://Art/Generated/grunt.png")
const CREW = [preload("res://Art/Generated/companion_pip.png"), preload("res://Art/Generated/companion_nori.png"), preload("res://Art/Generated/companion_kiwi.png")]
const GOLD = Color(1, 0.82, 0.25)
const PANELS = [
	"Far across the galaxy floats PISITANIA,\na soft, sunny planet where cats nap, purr and play.",
	"Until SHOCIREL - \"Sho\" to his minions - the buff demon lord of the mice,\ncame flexing out of the dark with an army of clockwork mice.",
	"Sho snatched the PRINCESS of Pisitania\nand carried her off to his fortress planet, Flexor.",
	"Only one hero answered the call: SHMITTEN, the superhero cat!\nWith her friends PIP, NORI and KIWI, she leaps into the stars.",
	"Planet by planet, beat by beat, they'll fight their way to Flexor.\nHold on, Princess - we're coming!",
]

var panel = 0
var time = 0.0
var text: Label
var hint: Label
var canvas: Node2D


func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Engine.time_scale = 1.0
	Conductor.play("level1", 2)
	var stars = Node2D.new()
	stars.set_script(preload("res://scenes/levels/starfield.gd"))
	add_child(stars)
	canvas = Node2D.new()
	canvas.draw.connect(_draw_panel)
	add_child(canvas)
	text = Label.new()
	text.position = Vector2(80, 520)
	text.size = Vector2(1120, 120)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_theme_font_size_override("font_size", 26)
	text.add_theme_color_override("font_color", Color(1, 0.95, 1))
	text.add_theme_color_override("font_outline_color", Color.BLACK)
	text.add_theme_constant_override("outline_size", 7)
	add_child(text)
	hint = Label.new()
	hint.text = "SPACE / click - next      Esc - skip"
	hint.position = Vector2(0, 670)
	hint.size = Vector2(1280, 30)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.85))
	add_child(hint)
	_show()


func _show():
	text.text = PANELS[panel]
	text.modulate.a = 0.0
	create_tween().tween_property(text, "modulate:a", 1.0, 0.4)
	time = 0.0


func next():
	panel += 1
	if panel >= PANELS.size():
		finish()
	else:
		_show()


func finish():
	get_tree().change_scene_to_file(MAIN_SCENE)


func _unhandled_input(event):
	if event.is_action_pressed("pause"):
		finish()
	elif event.is_action_pressed("shoot") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		next()


func _process(delta):
	time += delta
	canvas.queue_redraw()


func _tex(texture: Texture2D, at: Vector2, scale: float, frame_rect := Rect2(), flip := false):
	var size = (frame_rect.size if frame_rect.size != Vector2.ZERO else texture.get_size()) * scale
	var rect = Rect2(at - size / 2.0, size)
	if flip:
		rect.size.x = -rect.size.x
		rect.position.x += size.x
	if frame_rect.size != Vector2.ZERO:
		canvas.draw_texture_rect_region(texture, rect, frame_rect)
	else:
		canvas.draw_texture_rect(texture, rect, false)


func _cat(at: Vector2, scale: float):
	var frame = int(time * 12.0) % 10
	_tex(CAT_SHEET, at, scale, Rect2(frame * 64, 0, 64, 48))


func _planet(at: Vector2, radius: float, color: Color):
	canvas.draw_circle(at, radius, color)
	canvas.draw_circle(at + Vector2(-radius * 0.25, -radius * 0.25), radius * 0.7, color.lightened(0.15))
	canvas.draw_arc(at, radius * 1.35, -0.5, PI + 0.5, 48, Color(1, 1, 1, 0.35), 4.0)


func _draw_panel():
	var bob = sin(time * 2.0) * 8.0
	match panel:
		0:
			_planet(Vector2(640, 300), 150, Color(1, 0.7, 0.55))
			for i in 4:
				_cat(Vector2(520 + i * 80, 170 + abs(sin(time * 3 + i)) * -10), 1.0)
		1:
			canvas.draw_rect(Rect2(0, 0, 1280, 520), Color(0.5, 0, 0.15, 0.25))
			_tex(SHO, Vector2(640, 280 + bob), 7.0)
			for i in 6:
				_tex(GRUNT, Vector2(260 + (i % 3) * 90, 180 + (i / 3) * 120 + bob), 2.5)
				_tex(GRUNT, Vector2(1020 - (i % 3) * 90, 180 + (i / 3) * 120 - bob), 2.5, Rect2(), true)
		2:
			_tex(SHO, Vector2(520, 280 + bob), 6.0)
			canvas.draw_rect(Rect2(700, 200, 140, 160), Color(0.75, 0.75, 0.85), false, 4.0)
			for k in 5:
				canvas.draw_line(Vector2(712 + k * 29, 200), Vector2(712 + k * 29, 360), Color(0.75, 0.75, 0.85), 3.0)
			_tex(PRINCESS, Vector2(770, 290 - bob), 5.0, Rect2(), true)
		3:
			_cat(Vector2(560, 280 + bob), 3.0)
			for i in CREW.size():
				_tex(CREW[i], Vector2(760 + i * 70, 220 + i * 60 + sin(time * 3 + i) * 10), 3.0)
		_:
			var pts = [Vector2(170, 380), Vector2(420, 260), Vector2(640, 360), Vector2(860, 240), Vector2(1090, 330)]
			var colors = [Color(1, 0.7, 0.55), Color(0.95, 0.6, 0.35), Color(0.4, 0.8, 0.6), Color(0.65, 0.5, 0.9), Color(0.9, 0.3, 0.45)]
			for i in pts.size() - 1:
				for k in 10:
					if k % 2 == 0:
						canvas.draw_line(pts[i].lerp(pts[i + 1], k / 10.0), pts[i].lerp(pts[i + 1], (k + 1) / 10.0), Color(1, 1, 1, 0.5), 3.0)
			for i in pts.size():
				_planet(pts[i], 44 if i == 4 else 36, colors[i])
			var t = fmod(time * 0.15, 1.0)
			var seg = int(t * 4.0)
			_cat(pts[seg].lerp(pts[seg + 1], t * 4.0 - seg) + Vector2(0, -60), 1.4)
