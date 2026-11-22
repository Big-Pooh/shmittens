extends CharacterBody2D

class_name Shmitten

signal died

# playtest 2: controls felt "chunky" (was accel/friction 2000 -> ~0.3 s to start/stop).
# Now ~0.08 s, plus FOCUS (hold Shift): slower, precise movement with the hitbox shown,
# the standard bullet-hell tool for threading patterns.
@export var max_speed = 580
@export var acceleration = 7500
@export var friction = 9000
const FOCUS_SPEED = 0.45
var focused = false

const INVULNERABLE_TIME = 2.0
const RESPAWN_DELAY = 1.0
const FLY_FRAMES = 10        # row 0 of the sprite sheet
const FLY_FPS = 12.0
const SCREEN_MARGIN = Vector2(40, 36)

@onready var axis = Vector2.ZERO
@onready var sprite: Sprite2D = $Sprite2D
@onready var hitbox: Area2D = $Hitbox
@onready var pickup_area: Area2D = $PickupArea

var spawn_position: Vector2
var is_dead = false
var is_invulnerable = false
var anim_time = 0.0
var blink_tween: Tween
# Guardian (beginner care): a bubble that absorbs one hit, then recharges.
# Active after a game over on this level (recharge GUARDIAN_RECHARGE[assist] s), or - more
# slowly (EARLY_GUARDIAN_RECHARGE) - after EARLY_GUARDIAN_DEATHS deaths in this level attempt.
# Players who aren't dying never get it.
const GUARDIAN_RECHARGE = [0.0, 10.0, 7.0, 5.0]
const EARLY_GUARDIAN_DEATHS = 1   # playtest 2: after the first death (was 2)
const EARLY_GUARDIAN_RECHARGE = 10.0
var guardian_ready = false
var companion_bubble = false   # Nori's one-hit shield (see Companions)
# MECHA-MEOW (rare power-up, see Game.mech_parts): MECH_SECONDS in a mech suit with
# MECH_ARMOR hits of armour, MECH_SPEED x movement, and the heavy mech guns (gun.gd).
const MECH_TEXTURE = preload("res://Art/Generated/mech.png")
const MECH_SECONDS = 12.0
const MECH_ARMOR = 3
const MECH_SPEED = 0.8
var mech_time = 0.0
var mech_armor = 0
var _cat_texture: Texture2D
var _cat_scale: Vector2


func is_mech() -> bool:
	return mech_time > 0.0


func start_mech():
	if is_dead:
		return
	if not is_mech():
		_cat_texture = sprite.texture
		_cat_scale = sprite.scale
		sprite.texture = MECH_TEXTURE
		hat_sprite.visible = false
		sprite.hframes = 1
		sprite.vframes = 1
		sprite.frame = 0
		sprite.scale = Vector2(2.4, 2.4)
	mech_time = MECH_SECONDS
	mech_armor = MECH_ARMOR
	Sfx.play("power_up")
	Sfx.meow("mech")
	Game.shake(10.0)
	Conductor.set_layers(4)
	Game.track("mechs")
	Game.mech_changed.emit(true)


func end_mech():
	if _cat_texture == null:
		return
	mech_time = 0.0
	mech_armor = 0
	sprite.texture = _cat_texture
	hat_sprite.visible = true
	sprite.hframes = 10
	sprite.vframes = 5
	sprite.scale = _cat_scale
	Sfx.play("shield")
	Conductor.set_layers(Game.multiplier() + 1)
	Game.mech_changed.emit(false)
var guardian_timer = 0.0


var sprite_base: Vector2
var focus_marker: Node2D
var hat_sprite: Sprite2D
const HAT_OFFSET = Vector2(14, -17)   # head position in sheet pixels (cat faces right)


func _wear(id: String):
	var path = "res://Art/Generated/%s.png" % id
	hat_sprite.texture = load(path) if id != "none" and ResourceLoader.exists(path) else null
	hat_sprite.position = HAT_OFFSET   # drawn ABOVE the cat sprite (playtest 3: the dot was hidden under it)


func _ready():
	add_to_group("player")
	Game.player_ref = self
	sprite_base = sprite.position
	focus_marker = Node2D.new()
	focus_marker.name = "FocusMarker"
	focus_marker.z_index = 30
	focus_marker.position = hitbox.position
	focus_marker.draw.connect(_draw_focus)
	add_child(focus_marker)
	# sprint 4: the equipped hat sits on Shmitten's head (follows the dance bob)
	hat_sprite = Sprite2D.new()
	hat_sprite.name = "Hat"
	hat_sprite.scale = Vector2(1.6, 1.6)
	sprite.add_child(hat_sprite)
	hat_sprite.scale = Vector2.ONE
	_wear(Game.hat)
	Game.hat_changed.connect(_wear)
	spawn_position = position
	Conductor.beat.connect(_on_beat)
	hitbox.area_entered.connect(_on_hitbox_area_entered)
	pickup_area.area_entered.connect(_on_pickup_area_entered)


func _process(delta):
	anim_time += delta
	var recharge = 0.0
	if Game.challenge != Game.Challenge.NORMAL:
		recharge = 0.0   # HARD / TOUHOU: no guardian
	elif Game.assist > 0:
		recharge = GUARDIAN_RECHARGE[min(Game.assist, 3)]
	elif Game.level_deaths >= EARLY_GUARDIAN_DEATHS:
		recharge = EARLY_GUARDIAN_RECHARGE
	if recharge > 0.0 and not guardian_ready:
		guardian_timer += delta
		if guardian_timer >= recharge:
			guardian_ready = true
			guardian_timer = 0.0
	queue_redraw()
	_pad_aim()
	if is_mech():
		mech_time -= delta
		sprite.rotation = sin(anim_time * 6.0) * 0.04   # stompy idle wobble
		if mech_time <= 0.0:
			end_mech()
	else:
		sprite.frame = int(anim_time * FLY_FPS) % FLY_FRAMES
		_dance()
	var show_focus = focused and not is_dead
	focus_marker.visible = show_focus
	sprite.self_modulate.a = 0.6 if show_focus else 1.0   # see-through cat while focusing
	if show_focus:
		focus_marker.queue_redraw()
		Game.track("focus_seconds", delta)


# Dance break: hop on every beat, sway left/right on alternate beats, spin on the bar.
# GAMEPAD AIM (right stick): when a pad is connected and the stick is pushed, aim that way.
const PAD_AIM_DISTANCE = 450.0
var using_pad = false


func _pad_aim():
	if Input.get_connected_joypads().is_empty():
		return
	var v = Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	if v.length() > 0.3:
		using_pad = true
		if not Game.drawing:
			Game.aim_override = global_position + v.normalized() * PAD_AIM_DISTANCE
	elif using_pad and not Game.drawing and Game.aim_override != null:
		Game.aim_override = global_position + (Game.aim_override - global_position).normalized() * PAD_AIM_DISTANCE


func _input(event):
	if using_pad and event is InputEventMouseMotion:
		using_pad = false
		Game.aim_override = null   # the mouse takes over again


func _dance():
	if not Game.dancing or is_dead:
		if sprite.position != sprite_base or sprite.rotation != 0.0:
			sprite.position = sprite_base
			sprite.rotation = 0.0
		return
	var phase = Conductor.beat_phase()
	var beat = int(floor(Conductor.beat_position()))
	sprite.position = sprite_base + Vector2(0, -18.0 * (1.0 - phase) * (1.0 - phase))
	var sway = 0.22 if beat % 2 == 0 else -0.22
	sprite.rotation = sway * (1.0 - phase)
	if beat % Conductor.BEATS_PER_BAR == 0:
		sprite.rotation = TAU * phase   # a full spin on the downbeat


func _on_beat(_n: int):
	if not is_inside_tree() or not Game.dancing or is_dead:
		return
	# a little music note floats up from the dancing cat
	var note = Label.new()
	note.text = ["♪", "♫"][_n % 2]
	note.add_theme_font_size_override("font_size", 28)
	note.add_theme_color_override("font_color", Color(1, 0.6, 0.85))
	note.add_theme_color_override("font_outline_color", Color.BLACK)
	note.add_theme_constant_override("outline_size", 5)
	note.position = global_position + Vector2(randf_range(-30, 20), -60)
	note.z_index = 40
	get_tree().current_scene.add_child(note)
	var tween = note.create_tween().set_parallel()
	tween.tween_property(note, "position:y", note.position.y - 50, 0.8)
	tween.tween_property(note, "modulate:a", 0.0, 0.8)
	tween.chain().tween_callback(note.queue_free)


func _physics_process(delta):
	Game.player_alive = not is_dead
	Game.player_core = global_position + hitbox.position
	if is_dead:
		return
	move(delta)
	# keep the cat on screen
	position = position.clamp(Game.SCREEN.position + SCREEN_MARGIN, Game.SCREEN.end - SCREEN_MARGIN)


func get_input_axis():
	axis.x = int(Input.is_action_pressed("move_right")) - int(Input.is_action_pressed("move_left"))
	axis.y = int(Input.is_action_pressed("move_down")) - int(Input.is_action_pressed("move_up"))
	return axis.normalized()


func move(delta):
	axis = get_input_axis()
	focused = Input.is_action_pressed("focus") or Game.focus_override

	if axis == Vector2.ZERO:
		apply_friction(friction * delta)
	else:
		# turning around is instant-ish: drop the velocity component against the input
		if velocity.dot(axis) < 0.0:
			velocity = velocity.project(axis.orthogonal())
		apply_movement(axis * acceleration * delta)

	move_and_slide()


func apply_friction(amount):
	if velocity.length() > amount:
		velocity -= velocity.normalized() * amount
	else:
		velocity = Vector2.ZERO


func apply_movement(accel):
	velocity += accel
	velocity = velocity.limit_length(max_speed * (FOCUS_SPEED if focused else 1.0) * (MECH_SPEED if is_mech() else 1.0))


func _draw():
	if companion_bubble:
		draw_arc(Vector2(4, 4), 32.0, 0, TAU, 32, Color(0.7, 0.8, 1, 0.75), 3.0)
	if guardian_ready:
		draw_arc(Vector2(4, 4), 40.0, 0, TAU, 32, Color(1, 0.9, 0.5, 0.55), 2.5)


func grant_invulnerability(seconds: float):
	is_invulnerable = true
	get_tree().create_timer(seconds, false).timeout.connect(func(): if not blink_tween or not blink_tween.is_running(): is_invulnerable = false)


func can_shoot() -> bool:
	return not is_dead and not Game.is_game_over and not Game.drawing


func has_shield() -> bool:
	for child in get_children():
		if child is Shield and child.is_active():
			return true
	return false


func _on_hitbox_area_entered(area):
	if area is EnemyShot:
		if hit("shot"):
			area.queue_free()
	elif area is EnemyBase:
		if hit("ram"):
			area.die()


func _on_pickup_area_entered(area):
	if area is Pickup and not is_dead:
		area.collect()


# Returns true if the hit counted.
func hit(cause: String = "") -> bool:
	if is_dead or is_invulnerable or has_shield():
		return false
	if mech_armor > 0:
		mech_armor -= 1
		Sfx.play("armor_crack")
		Game.shake(6.0)
		is_invulnerable = true
		get_tree().create_timer(0.5, false).timeout.connect(func(): is_invulnerable = false)
		sprite.modulate = Color(3, 1, 1)
		create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.2)
		return false
	if companion_bubble:
		companion_bubble = false
		Sfx.play("shield")
		is_invulnerable = true
		get_tree().create_timer(0.6, false).timeout.connect(func(): is_invulnerable = false)
		Game.track("nori_saves")
		return false
	if guardian_ready:
		guardian_ready = false
		Sfx.play("shield")
		is_invulnerable = true   # brief grace so one burst doesn't pop it and hit at once
		get_tree().create_timer(0.6, false).timeout.connect(func(): is_invulnerable = false)
		return false
	is_dead = true
	velocity = Vector2.ZERO
	sprite.hide()
	Sfx.play("player_hit")
	Sfx.meow("hit")
	Game.player_hit.emit(cause)
	Game.level_hits += 1
	Game.track("deaths_" + (cause if cause != "" else "other"))
	Game.shake(12.0)
	died.emit()
	if Game.lose_life() > 0:
		_respawn_later()
	return true


func _respawn_later():
	await get_tree().create_timer(RESPAWN_DELAY, false).timeout
	respawn()


func respawn():
	position = spawn_position
	velocity = Vector2.ZERO
	is_dead = false
	sprite.show()
	is_invulnerable = true
	if blink_tween:
		blink_tween.kill()
	blink_tween = create_tween().set_loops(int(INVULNERABLE_TIME / 0.2))
	blink_tween.tween_property(sprite, "modulate:a", 0.25, 0.1)
	blink_tween.tween_property(sprite, "modulate:a", 1.0, 0.1)
	blink_tween.finished.connect(_end_invulnerability)


func _end_invulnerability():
	sprite.modulate.a = 1.0
	is_invulnerable = false


# FOCUS: a ring that slowly turns plus the real hitbox, on top of the cat.
func _draw_focus():
	var t = anim_time * 2.0
	focus_marker.draw_arc(Vector2.ZERO, 26.0, t, t + TAU * 0.8, 32, Color(0.6, 0.95, 1.0, 0.8), 2.0)
	focus_marker.draw_circle(Vector2.ZERO, 8.0, Color(1, 1, 1, 1.0))
	focus_marker.draw_circle(Vector2.ZERO, 5.0, Color(1, 0.25, 0.5, 1.0))
