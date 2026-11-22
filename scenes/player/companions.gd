extends Node2D

class_name Companions

# Shmitten's travelling companions (playtest 4). They join as your combo grows - one every
# JOIN_EVERY on-beat hits in a row (max 3) - and fly in formation around the cat. On every
# beat each one zaps the nearest mouse with a small laser (ZAP_DAMAGE, a "mediocre laser").
# When the combo breaks they wave goodbye and fly off until you build it up again.
#   Pip  - a hamster pilot in a tiny saucer      (joins at 10)
#   Nori - an engineer kitten with a jetpack     (joins at 20)
#   Kiwi - a round little bird                   (joins at 30)

const JOIN_EVERY = 10
const ZAP_DAMAGE = 0.6
const ZAP_RANGE = 900.0
const CREW = [
	{"name": "PIP", "texture": preload("res://Art/Generated/companion_pip.png"), "offset": Vector2(-20, -70), "color": Color(1, 0.85, 0.4)},
	{"name": "NORI", "texture": preload("res://Art/Generated/companion_nori.png"), "offset": Vector2(-20, 70), "color": Color(0.7, 0.8, 1)},
	{"name": "KIWI", "texture": preload("res://Art/Generated/companion_kiwi.png"), "offset": Vector2(-80, 0), "color": Color(0.6, 1, 0.6)},
]

var members: Array = []   # [{sprite, index}]
var zaps: Array = []      # [from, to, time_left, color]
var time = 0.0


func _ready():
	z_index = 15
	Game.combo_changed.connect(_on_combo)
	Conductor.beat.connect(_on_beat)


func count() -> int:
	return members.size()


func _player() -> Node2D:
	return Game.player_ref if Game.player_ref and is_instance_valid(Game.player_ref) else null


func _on_combo(combo: int, _multiplier: int):
	if not is_inside_tree():
		return
	var want = min(combo / JOIN_EVERY, CREW.size())
	while members.size() < want:
		_join(members.size())
	if combo == 0 and not members.is_empty():
		_leave_all()


func _join(index: int):
	var player = _player()
	var sprite = Sprite2D.new()
	sprite.texture = CREW[index].texture
	sprite.scale = Vector2(2.5, 2.5)
	sprite.position = (player.global_position if player else Vector2(200, 360)) + Vector2(-300, CREW[index].offset.y * 2.0)
	add_child(sprite)
	members.append({"sprite": sprite, "index": index})
	Sfx.play("jingle", -8.0)
	Game.track("companions_joined")
	_say(sprite.position + Vector2(0, -30), CREW[index].name + " joins!", CREW[index].color)


func _leave_all():
	for m in members:
		var sprite: Sprite2D = m.sprite
		var tween = sprite.create_tween()
		tween.tween_property(sprite, "position", sprite.position + Vector2(-320, -60), 0.6).set_trans(Tween.TRANS_SINE)
		tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.6)
		tween.tween_callback(sprite.queue_free)
	members.clear()


func _physics_process(delta):
	time += delta
	var player = _player()
	if player == null:
		return
	for m in members:
		var sprite: Sprite2D = m.sprite
		var target = player.global_position + CREW[m.index].offset + Vector2(0, sin(time * 3.0 + m.index) * 6.0)
		sprite.position = sprite.position.lerp(target, min(6.0 * delta, 1.0))
	for z in zaps:
		z[2] -= delta
	zaps = zaps.filter(func(z): return z[2] > 0.0)
	queue_redraw()


func _on_beat(_n: int):
	if not is_inside_tree() or members.is_empty() or Game.is_game_over:
		return
	for m in members:
		var from = m.sprite.position
		var target = _nearest(from)
		if target == null:
			continue
		target.take_hit(ZAP_DAMAGE, (target.global_position - from).normalized(), -1)
		zaps.append([from, target.global_position, 0.12, CREW[m.index].color])
		Game.track("companion_zaps")


func _nearest(from: Vector2):
	var best = null
	var best_d = ZAP_RANGE
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.is_dead or not Game.SCREEN.has_point(e.global_position):
			continue
		var d = e.global_position.distance_to(from)
		if d < best_d:
			best_d = d
			best = e
	return best


func _say(at: Vector2, text: String, color: Color):
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 5)
	label.position = at
	label.z_index = 45
	get_tree().current_scene.add_child(label)
	var tween = label.create_tween()
	tween.tween_property(label, "position:y", at.y - 30, 1.0)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.0)
	tween.tween_callback(label.queue_free)


func _draw():
	for z in zaps:
		var a = clamp(z[2] / 0.12, 0.0, 1.0)
		draw_line(z[0], z[1], Color(z[3], 0.8 * a), 3.0)
		draw_line(z[0], z[1], Color(1, 1, 1, a), 1.0)
