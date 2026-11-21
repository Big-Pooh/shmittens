extends Node2D

class_name GestureInput

# Hold right-click to draw a skill gesture; release to cast.
# While drawing: the game runs in slow motion (SLOW_MO_SCALE, capped at MAX_DRAW_TIME real
# seconds), the music is muffled, a glowing trail follows the mouse and the gun is disabled.
# On release the stroke is recognised; a known shape spends 1 skill charge and casts.
# Releasing on the beat (Conductor.judge() != MISS) makes the skill EMPOWERED (+50%).

signal cast(skill: String, empowered: bool)
signal fizzled(reason: String)

const SLOW_MO_SCALE = 0.3
const MAX_DRAW_TIME = 2.0
const MIN_POINT_SPACING = 4.0
const SKILL_FOR_SHAPE = {
	"circle": "shockwave",
	"line": "laser",
	"zigzag": "lightning",
	"triangle": "shield",
}
const SKILL_COLORS = {
	"shockwave": Color(0.5, 0.9, 1.0),
	"laser": Color(1.0, 0.4, 0.9),
	"lightning": Color(1.0, 0.95, 0.4),
	"shield": Color(0.4, 1.0, 0.6),
}

var recognizer = GestureRecognizer.new()
var drawing = false
var points = PackedVector2Array()
var started_msec = 0
var trail: Line2D
var tint: ColorRect


func _ready():
	z_index = 50
	trail = Line2D.new()
	trail.width = 7.0
	trail.default_color = Color(0.6, 0.95, 1.0, 0.9)
	trail.joint_mode = Line2D.LINE_JOINT_ROUND
	trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	trail.end_cap_mode = Line2D.LINE_CAP_ROUND
	add_child(trail)
	var layer = CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	tint = ColorRect.new()
	tint.color = Color(0.2, 0.3, 0.8, 0.18)
	tint.size = Game.SCREEN.size
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tint.hide()
	layer.add_child(tint)


func _player() -> Shmitten:
	return get_tree().get_first_node_in_group("player")


func _unhandled_input(event):
	if event.is_action_pressed("draw"):
		begin()
	elif event.is_action_released("draw") and drawing:
		finish()
	elif drawing and event is InputEventMouseMotion:
		add_point(get_global_mouse_position())


func _process(_delta):
	if not drawing:
		return
	var player = _player()
	if player == null or player.is_dead or Game.is_game_over:
		cancel()
	elif Time.get_ticks_msec() - started_msec > MAX_DRAW_TIME * 1000.0:
		finish()


# `at` = first point of the stroke (defaults to the mouse position).
func begin(at = null):
	var player = _player()
	if drawing or player == null or player.is_dead or Game.is_game_over:
		return
	drawing = true
	Game.drawing = true
	started_msec = Time.get_ticks_msec()
	points.clear()
	trail.clear_points()
	trail.modulate.a = 1.0
	Engine.time_scale = SLOW_MO_SCALE
	Conductor.set_muffled(true)
	tint.show()
	add_point(at if at != null else get_global_mouse_position())


func add_point(p: Vector2):
	if not drawing:
		return
	if points.is_empty() or p.distance_to(points[points.size() - 1]) >= MIN_POINT_SPACING:
		points.append(p)
		trail.add_point(p)


func _stop_drawing():
	drawing = false
	Game.drawing = false
	Engine.time_scale = 1.0
	Conductor.set_muffled(false)
	tint.hide()
	create_tween().tween_property(trail, "modulate:a", 0.0, 0.25)


func cancel():
	if drawing:
		_stop_drawing()


# Recognises the stroke and casts. Returns the recognizer result (handy for tests).
func finish() -> Dictionary:
	if not drawing:
		return {}
	_stop_drawing()
	var result = recognizer.recognize(points)
	if result.name == "":
		_popup("FIZZLE", Color(0.7, 0.7, 0.7))
		fizzled.emit("unrecognised")
		return result
	if not Game.use_charge():
		_popup("NO CHARGE", Color(1, 0.5, 0.5))
		fizzled.emit("no_charge")
		return result
	var skill = SKILL_FOR_SHAPE[result.name]
	var empowered = Conductor.judge() != Conductor.Judgement.MISS
	cast_skill(skill, empowered, result.direction)
	return result


func cast_skill(skill: String, empowered: bool, direction: Vector2 = Vector2.RIGHT):
	var player = _player()
	if player == null:
		return
	var scene = get_tree().current_scene
	match skill:
		"shockwave":
			scene.add_child(Shockwave.create(player.global_position, empowered))
		"laser":
			scene.add_child(LaserBeam.create(player, direction, empowered))
		"lightning":
			scene.add_child(ChainLightning.create(player.global_position, get_global_mouse_position(), empowered))
		"shield":
			player.add_child(Shield.create(empowered))
	Sfx.play(skill)
	Game.shake({"shockwave": 9.0, "laser": 6.0, "lightning": 5.0, "shield": 2.0}[skill] * (1.4 if empowered else 1.0))
	var text = skill.to_upper() + "!"
	if empowered:
		text = "EMPOWERED " + text
	_popup(text, SKILL_COLORS[skill])
	cast.emit(skill, empowered)


func _popup(text: String, color: Color):
	var player = _player()
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	label.position = (player.global_position if player else get_global_mouse_position()) + Vector2(-60, -80)
	label.z_index = 60
	get_tree().current_scene.add_child(label)
	var tween = label.create_tween().set_parallel()
	tween.tween_property(label, "position:y", label.position.y - 40, 0.8)
	tween.tween_property(label, "modulate:a", 0.0, 0.5).set_delay(0.3)
	tween.chain().tween_callback(label.queue_free)
