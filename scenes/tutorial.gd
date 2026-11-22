extends Node

class_name Tutorial

# Guided intro before Level 1. Each step shows one instruction and completes when the player
# does it. Practice mice are harmless (they don't march or shoot). Tab skips.
# On finish or skip: remembers it in user://settings.cfg and starts Level 1.

signal step_changed(index: int)
signal finished

const SETTINGS_PATH = "user://settings.cfg"
const MOVE_DISTANCE = 400.0
const BEAT_CLICKS_NEEDED = 3
const HELD_BEATS_NEEDED = 4
const GESTURE_ORDER = ["shockwave", "laser", "lightning", "shield"]
const GESTURE_HINTS = {
	"shockwave": "Draw a CIRCLE around the mice  ->  it bursts right there",
	"laser": "Draw a LINE through the mice  ->  CLAW SLASH along your line",
	"lightning": "Draw a ZIGZAG over the mice  ->  LIGHTNING strikes along it",
	"shield": "Draw a TRIANGLE anywhere  ->  a SHIELD around you",
}
const SHAPE_FOR_SKILL = {"shockwave": "circle", "laser": "line", "lightning": "zigzag", "shield": "triangle"}
const GRUNT = preload("res://scenes/enemies/grunt.tscn")
const GOLD = Color(1, 0.82, 0.25)

var step = 0
var moved = 0.0
var last_cat_position: Vector2
var beat_clicks = 0
var held_beats = 0
var gesture_index = 0
var weapons_tried = {}
var done = false
var guide: GestureGuide
# steps: 0 move, 1 beat clicks, 2 held fire, 3 weapons, 4 practice mice, 5 gestures, 6 ready
const STEP_WEAPONS = 3
const STEP_MICE = 4
const STEP_GESTURES = 5
const STEP_READY = 6

var panel_label: Label
var hint_label: Label


static func is_done() -> bool:
	var config = ConfigFile.new()
	config.load(SETTINGS_PATH)
	return config.get_value("tutorial", "done", false)


static func set_done(value: bool):
	var config = ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("tutorial", "done", value)
	config.save(SETTINGS_PATH)


func _cat() -> Shmitten:
	return get_tree().get_first_node_in_group("player")


func _gestures() -> GestureInput:
	return get_tree().current_scene.get_node("GestureInput")


func _ready():
	_build_ui()
	Conductor.play("level1", 2)
	Conductor.beat.connect(_on_beat)
	Game.judged.connect(_on_judged)
	_gestures().cast.connect(_on_cast)
	Game.weapon_changed.connect(_on_weapon)
	var cat = _cat()
	cat.is_invulnerable = true   # nothing can hurt you in the tutorial
	last_cat_position = cat.global_position
	_show_step()


func _build_ui():
	var layer = CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	panel_label = Label.new()
	panel_label.position = Vector2(0, 100)
	panel_label.size = Vector2(1280, 0)
	panel_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel_label.add_theme_font_size_override("font_size", 30)
	panel_label.add_theme_color_override("font_color", GOLD)
	panel_label.add_theme_color_override("font_outline_color", Color.BLACK)
	panel_label.add_theme_constant_override("outline_size", 8)
	layer.add_child(panel_label)
	hint_label = Label.new()
	hint_label.position = Vector2(0, 620)
	hint_label.size = Vector2(1280, 0)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_font_size_override("font_size", 16)
	hint_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.85))
	hint_label.text = "TUTORIAL  -  press TAB to skip"
	layer.add_child(hint_label)
	guide = GestureGuide.new()
	layer.add_child(guide)


func _show_step():
	step_changed.emit(step)
	guide.show_focus("")
	match step:
		0:
			panel_label.text = "STEP 1/6   Fly around with  W A S D\n(hold SHIFT to FOCUS: slower, and shows your tiny hitbox)"
		1:
			panel_label.text = "STEP 2/6   Watch the beat bar and the sparkles...\nthen press SPACE exactly on the beat (%d/%d)   (the mouse aims)" % [beat_clicks, BEAT_CLICKS_NEEDED]
		2:
			panel_label.text = "STEP 3/6   HOLD SPACE: Shmitten keeps firing to the beat by herself (%d/%d)" % [held_beats, HELD_BEATS_NEEDED]
		STEP_WEAPONS:
			weapons_tried[Game.weapon] = true   # the one you're holding counts
			var names = []
			for w in Game.WEAPON_NAMES.size():
				names.append(("[%s]" if weapons_tried.has(w) else "%s") % Game.WEAPON_NAMES[w])
			panel_label.text = "STEP 4/6   Try all three weapons: press 1, 2, 3 (or Q / E, or the mouse wheel)\nFISH home in by themselves, the LASER hits hardest if you aim, SPREAD is a close-range blast\n%s" % "   ".join(names)
		STEP_MICE:
			panel_label.text = "STEP 5/6   Shoot the practice mice ON THE BEAT.\nOn-beat kills drop cheese; streaks give batteries. Earn a skill charge!"
			_spawn_practice_mice()
		STEP_GESTURES:
			Game.add_charge(Game.MAX_CHARGES)   # free charges for practice
			var skill = GESTURE_ORDER[gesture_index]
			panel_label.text = "STEP 6/6   HOLD RIGHT-CLICK and trace the shape (time slows down), release to cast:\n%s   (%d/%d)" % [GESTURE_HINTS[skill], gesture_index + 1, GESTURE_ORDER.size()]
			guide.show_focus(SHAPE_FOR_SKILL[skill], Vector2(640, 400), 110.0)
			if get_tree().get_nodes_in_group("enemies").size() < 3:
				_spawn_practice_mice()
		STEP_READY:
			panel_label.text = "YOU'RE READY!\nRelease a spell ON THE BEAT to empower it.  X = emergency CATNIP BOMB (uses all charges).\n50 on-beat hits in a row = OVERDRIVE (press F).  Between waves: DANCE on the beat!\nNow go save the Queen!"


func _spawn_practice_mice():
	for i in 6:
		var mouse = GRUNT.instantiate() as Grunt
		mouse.marching = false
		mouse.fire_slots = 1_000_000   # never fires
		mouse.max_health = 1
		mouse.slot_position = Vector2(1000 + (i % 2) * 90, 170 + i * 75)
		mouse.position = Vector2(1380, mouse.slot_position.y)
		get_tree().current_scene.add_child(mouse)


func _process(_delta):
	if done:
		return
	var cat = _cat()
	if step == 0 and cat:
		moved += cat.global_position.distance_to(last_cat_position)
		last_cat_position = cat.global_position
		if moved >= MOVE_DISTANCE:
			advance()
	elif step == STEP_MICE and Game.charges >= 1:
		advance()


func _on_judged(judgement: int):
	if step == 1 and judgement != Conductor.Judgement.MISS:
		beat_clicks += 1
		if beat_clicks >= BEAT_CLICKS_NEEDED:
			advance()
		else:
			_show_step()


func _on_beat(_n: int):
	if not is_inside_tree():
		return
	if step == 2 and Input.is_action_pressed("shoot"):
		held_beats += 1
		if held_beats >= HELD_BEATS_NEEDED:
			advance()
		else:
			_show_step()


func _on_cast(skill: String, _empowered: bool):
	if step != STEP_GESTURES or skill != GESTURE_ORDER[gesture_index]:
		return
	gesture_index += 1
	if gesture_index >= GESTURE_ORDER.size():
		advance()
	else:
		_show_step()


func _on_weapon(w: int):
	if step != STEP_WEAPONS:
		return
	weapons_tried[w] = true
	if weapons_tried.size() >= Game.WEAPON_NAMES.size():
		advance()
	else:
		_show_step()


func advance():
	step += 1
	_show_step()
	if step == STEP_READY:
		_finish_later()


func _finish_later():
	await get_tree().create_timer(4.0, false).timeout
	finish()


func _unhandled_input(event):
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_TAB:
		finish()


# Marks the tutorial as done and starts Level 1.
func finish():
	if done:
		return
	done = true
	set_done(true)
	finished.emit()
	Game.tutorial_mode = false
	Game.start_level = 0
	Game.start_wave = 0
	Game.clear_assist()
	get_tree().reload_current_scene()
