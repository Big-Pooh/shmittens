extends Node2D

class_name GestureInput

# Hold right-click to draw a skill gesture; release to cast.
# While drawing: the game runs in slow motion (SLOW_MO_SCALE, capped at MAX_DRAW_TIME real
# seconds), the music is muffled, a glowing trail follows the mouse and the gun is disabled.
# On release the stroke is recognised; a known shape spends 1 skill charge and casts.
# Releasing on the beat (Conductor.judge() != MISS) makes the skill EMPOWERED (+50%).

signal cast(skill: String, empowered: bool)
signal bombed
signal fizzled(reason: String)

const SLOW_MO_SCALE = 0.3
# Spell Chain (signature mechanic): casting on consecutive bars links spells. Each link adds
# CHAIN_BONUS power (max CHAIN_MAX links) and plays a rising note in the track's key.
const CHAIN_BONUS = 0.25
const CHAIN_MAX = 3
var chain = 0
var last_cast_bar = -100
const MAX_DRAW_TIME = 2.0
# Snap assist (playtest 3): after SNAP_AFTER unrecognised strokes in a row, a stroke that is
# at least SNAP_MIN_SCORE like a shape is accepted as that shape.
const SNAP_AFTER = 2
const SNAP_MIN_SCORE = 0.6
var fizzles_in_a_row = 0
# Spell impact (playtest 3: spells felt pointless): every cast clears the enemy bullets on
# screen, turning up to CANCEL_TO_CHEESE of them into cheese, and shows the spell's name.
const CANCEL_TO_CHEESE = 6
const SPELL_NAMES = {
	"shockwave": "PURR-CUSSION WAVE", "laser": "CLAW SLASH",
	"lightning": "STATIC FLUFF STORM", "shield": "CUDDLE SHIELD",
}
# Emergency CATNIP BOMB (X): spends ALL charges; clears every bullet, hits every enemy for
# BOMB_DAMAGE per charge (bosses: Boss.take_bomb) and gives BOMB_INVULNERABLE s of safety.
const BOMB_DAMAGE = 5.0
const BOMB_INVULNERABLE = 1.5
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
var guide: GestureGuide   # faded shape outlines while drawing (playtest 2)


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
	var guide_layer = CanvasLayer.new()
	guide_layer.layer = 6
	add_child(guide_layer)
	guide = GestureGuide.new()
	guide_layer.add_child(guide)


func _player() -> Shmitten:
	return get_tree().get_first_node_in_group("player")


func _unhandled_input(event):
	if event.is_action_pressed("draw"):
		begin()
	elif event.is_action_released("draw") and drawing:
		finish()
	elif drawing and event is InputEventMouseMotion:
		add_point(get_global_mouse_position())
	elif event.is_action_pressed("bomb"):
		bomb()


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
	guide.show_panel(true)
	add_point(at if at != null else get_global_mouse_position())


func add_point(p: Vector2):
	if not drawing:
		return
	if points.is_empty() or p.distance_to(points[points.size() - 1]) >= MIN_POINT_SPACING:
		points.append(p)
		trail.add_point(p)
		# live hint: light up the shape the stroke looks like so far
		if points.size() >= 8 and points.size() % 5 == 0:
			guide.set_match(recognizer.recognize(points).name)


func _stop_drawing():
	drawing = false
	Game.drawing = false
	Engine.time_scale = 1.0
	Conductor.set_muffled(false)
	tint.hide()
	guide.show_panel(false)
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
	if result.name == "" and fizzles_in_a_row >= SNAP_AFTER and result.get("best", "") != "" and result.score >= SNAP_MIN_SCORE:
		result.name = result.best   # snap assist: close enough after a couple of misses
		result["snapped"] = true
	if result.name == "":
		fizzles_in_a_row += 1
		_popup("FIZZLE", Color(0.7, 0.7, 0.7))
		fizzled.emit("unrecognised")
		Game.track("fizzles")
		return result
	fizzles_in_a_row = 0
	if not Game.use_charge():
		_popup("NO CHARGE", Color(1, 0.5, 0.5))
		fizzled.emit("no_charge")
		return result
	var skill = SKILL_FOR_SHAPE[result.name]
	var empowered = Conductor.judge() != Conductor.Judgement.MISS
	cast_skill(skill, empowered, result.direction, points)
	return result


# stroke = the drawn points: spells land where they were drawn. Without a stroke (tests,
# old callers) they come from the cat as before.
func cast_skill(skill: String, empowered: bool, direction: Vector2 = Vector2.RIGHT, stroke := PackedVector2Array()):
	var player = _player()
	if player == null:
		return
	var drawn = stroke.size() >= 2
	var bar = int(floor(Conductor.beat_position() / Conductor.BEATS_PER_BAR))
	chain = min(chain + 1, CHAIN_MAX) if bar - last_cast_bar == 1 else 0
	last_cast_bar = bar
	Game.spell_power = 1.0 + CHAIN_BONUS * chain
	var scene = get_tree().current_scene
	match skill:
		"shockwave":
			Game.magnet_until = Game.play_time + 3.0   # the circle also magnets cheese for 3 s
			if drawn:
				var center = Vector2.ZERO
				for p in stroke:
					center += p
				center /= stroke.size()
				var r = 0.0
				for p in stroke:
					r += p.distance_to(center)
				scene.add_child(Shockwave.create(center, empowered, r / stroke.size()))
			else:
				scene.add_child(Shockwave.create(player.global_position, empowered))
		"laser":
			if drawn:
				scene.add_child(LaserBeam.slash(stroke[0], stroke[stroke.size() - 1], empowered))
			else:
				scene.add_child(LaserBeam.create(player, direction, empowered))
		"lightning":
			if drawn:
				scene.add_child(ChainLightning.along(stroke, empowered))
			else:
				scene.add_child(ChainLightning.create(player.global_position, Game.aim_override if Game.aim_override != null else get_global_mouse_position(), empowered))
		"shield":
			player.add_child(Shield.create(empowered))
	Sfx.play(skill)
	Game.shake({"shockwave": 9.0, "laser": 6.0, "lightning": 5.0, "shield": 2.0}[skill] * (1.4 if empowered else 1.0))
	var text = skill.to_upper() + "!"
	if empowered:
		text = "EMPOWERED " + text
	if chain > 0:
		text += "  CHAIN x%d" % (chain + 1)
		Sfx.play("chain_%d" % chain, -4.0)
	_popup(text, SKILL_COLORS[skill])
	_banner(SPELL_NAMES[skill], SKILL_COLORS[skill])
	cancel_bullets(CANCEL_TO_CHEESE)
	Game.track("cast_" + skill)
	Sfx.meow("cast")
	cast.emit(skill, empowered)


# Clears every enemy bullet; the first `to_cheese` of them turn into cheese.
func cancel_bullets(to_cheese: int):
	var scene = get_tree().current_scene
	var n = 0
	for shot in get_tree().get_nodes_in_group("enemy_shots"):
		if n < to_cheese and Game.SCREEN.has_point(shot.global_position):
			scene.add_child.call_deferred(Pickup.create(Pickup.Type.CHEESE, shot.global_position))
			n += 1
		shot.queue_free()


# Emergency bomb: costs every charge you have (at least 1).
func bomb() -> bool:
	var player = _player()
	if player == null or player.is_dead or Game.is_game_over:
		return false
	var spent = 0
	if Game.bomb_stock > 0:
		# TOUHOU: the free bomb of this life (strength of 3 charges), charges are kept
		Game.bomb_stock -= 1
		spent = 3
	elif Game.charges >= Game.BOMB_MIN_CHARGES and not Game.bomb_used_this_level:
		Game.bomb_used_this_level = true
		spent = Game.charges
		Game.charges = 0
		Game.charges_changed.emit(Game.charges, Game.cheese)
	else:
		return false
	if drawing:
		cancel()
	cancel_bullets(0)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.is_dead:
			continue
		if enemy is Boss:
			enemy.take_bomb(spent)
		else:
			enemy.take_skill_damage(BOMB_DAMAGE * spent)
	player.grant_invulnerability(BOMB_INVULNERABLE)
	scene_flash(Color(1, 0.7, 0.95, 0.6))
	Sfx.play("shockwave")
	Game.shake(16.0)
	_banner("CATNIP BOMB x%d" % spent, Color(1, 0.6, 0.9))
	Game.track("bombs")
	bombed.emit()
	return true


func scene_flash(color: Color):
	if Game.reduce_effects:
		color.a *= 0.4
	var layer = CanvasLayer.new()
	layer.layer = 7
	var rect = ColorRect.new()
	rect.color = color
	rect.size = Game.SCREEN.size
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rect)
	add_child(layer)
	var tween = rect.create_tween()
	tween.tween_property(rect, "modulate:a", 0.0, 0.4)
	tween.tween_callback(layer.queue_free)


# Spell-card style name banner across the top of the screen.
func _banner(text: String, color: Color):
	var layer = CanvasLayer.new()
	layer.layer = 8
	var label = Label.new()
	label.text = "~  " + text + "  ~"
	label.position = Vector2(0, 150)
	label.size = Vector2(1280, 50)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 34)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 8)
	layer.add_child(label)
	add_child(layer)
	var tween = label.create_tween()
	tween.tween_property(label, "position:x", 0.0, 0.6).from(-60.0)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.5).set_delay(0.6)
	tween.tween_callback(layer.queue_free)


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
