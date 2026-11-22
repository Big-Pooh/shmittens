extends Node2D

# Fires toward the mouse.
# - Pressing SPACE (the "shoot" action; the mouse aims) fires immediately and is judged:
#     PERFECT x2 damage, GOOD x1.5, off-beat x1 (and the combo resets).
# - Holding SPACE fires automatically on every 8th note (twice per beat): HELD_DAMAGE, not
#   judged, no combo - an easy fallback that keeps the groove (playtest 2: once per beat felt
#   "chunky").
# Three weapons (Game.Weapon), switched with 1/2/3, Q/E or the mouse wheel. Gun level 1-5
# (yarn) powers the equipped weapon. Playtest 3: Fish made aiming pointless and Spread was a
# trap, so each weapon now has its own job:
#   FISH   (default) - FISH_COUNT[level] homing fish at FISH_DAMAGE. Effortless; lowest damage.
#   LASER  - one fast piercing bolt, LASER_BASE + LASER_PER_LEVEL per level (~1.2-1.6x Fish).
#            The reward for aiming while you dodge.
#   SPREAD - a close-range shotgun: 2 + level pellets, full damage up close, falling off with
#            distance (see PlayerShot), short range, and pellets ERASE enemy bullets they touch.
# F unleashes a banked CATNIP OVERDRIVE (see OverdriveBeam).

const SPREAD_DEGREES = 11.0
const CLICK_DAMAGE = 1.0
const HELD_DAMAGE = 0.6
const LASER_BASE = 0.8
const LASER_PER_LEVEL = 0.4
# playtest 5: "obliterating playthroughs with fish" -> weaker (0.5 -> 0.35), fewer at Lv2/4,
# and they turn slower (PlayerShot.FISH_TURN_RATE), so aiming the laser clearly pays more.
const FISH_COUNT = [0, 1, 1, 2, 2, 3]
const FISH_DAMAGE = 0.35
const ASSIST_FISH_BONUS = 1.5   # beginner care: fish hit harder after a game over / in Relaxed
const LASER_CRIT = 1.5   # playtest 4: a PERFECT laser shot is a critical hit
const JUDGEMENT_DAMAGE = {
	Conductor.Judgement.MISS: 1.0,
	Conductor.Judgement.GOOD: 1.5,
	Conductor.Judgement.PERFECT: 2.0,
}
# a held shot is skipped if the player clicked this close to it (no double shots)
const CLICK_SUPPRESS_MSEC = 150

@onready var player: Shmitten = get_parent()

var last_click_msec = -100000
var last_half = -1


# PAWFRAME MK-IX (MECHA-MEOW) weapons, real-robot style: every shot is one heavy piercing
# BEAM RIFLE bolt (MECH_RIFLE x damage); on every bar the BEAM SABER slashes a SABER_RADIUS arc in
# front of the mech, hitting each mouse for SABER_DAMAGE and cutting the bullets it touches.
const MECH_RIFLE = 3.0
const SABER_RADIUS = 190.0
const SABER_ARC = 1.4   # radians either side of the aim
const SABER_DAMAGE = 6.0


func _ready():
	Conductor.beat.connect(_on_beat)
	Conductor.bar.connect(_on_bar)


func _on_bar(_n: int):
	if not is_inside_tree() or not player.is_mech() or not player.can_shoot():
		return
	saber_slash()


# Returns how many mice the slash hit.
func saber_slash() -> int:
	var aim = Game.aim_override if Game.aim_override != null else get_global_mouse_position()
	var facing = (aim - global_position).angle()
	var hits = 0
	for e in get_tree().get_nodes_in_group("enemies"):
		var to = e.global_position - global_position
		if not e.is_dead and to.length() <= SABER_RADIUS + 30.0 and absf(angle_difference(facing, to.angle())) <= SABER_ARC:
			e.take_hit(SABER_DAMAGE, to.normalized(), Conductor.Judgement.GOOD)
			hits += 1
	for shot in get_tree().get_nodes_in_group("enemy_shots"):
		var to = shot.global_position - global_position
		if to.length() <= SABER_RADIUS and absf(angle_difference(facing, to.angle())) <= SABER_ARC:
			shot.queue_free()
	saber_fx = {"facing": facing, "time": 0.25}
	queue_redraw()
	Sfx.play("laser", -4.0)
	Game.track("saber_slashes")
	return hits


var saber_fx = {}


func _draw():
	if saber_fx.is_empty():
		return
	var a = saber_fx.time / 0.25
	var f = saber_fx.facing
	draw_arc(Vector2.ZERO, SABER_RADIUS * 0.85, f - SABER_ARC, f + SABER_ARC, 32, Color(1, 0.55, 0.85, a), 14.0)
	draw_arc(Vector2.ZERO, SABER_RADIUS * 0.85, f - SABER_ARC, f + SABER_ARC, 32, Color(1, 1, 1, a), 4.0)


func _unhandled_input(event):
	if event.is_action_pressed("shoot"):
		click()
	elif event.is_action_pressed("weapon_next"):
		Game.cycle_weapon(1)
	elif event.is_action_pressed("weapon_prev"):
		Game.cycle_weapon(-1)
	elif event.is_action_pressed("weapon_1"):
		Game.set_weapon(Game.Weapon.SPREAD)
	elif event.is_action_pressed("weapon_2"):
		Game.set_weapon(Game.Weapon.LASER)
	elif event.is_action_pressed("weapon_3"):
		Game.set_weapon(Game.Weapon.FISH)
	elif event.is_action_pressed("overdrive"):
		unleash_overdrive()
	elif event is InputEventMouseButton and event.pressed and not Game.drawing:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			Game.cycle_weapon(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			Game.cycle_weapon(1)


# The off-beat 8th notes (the on-beat ones come from the Conductor's beat signal).
func _process(delta):
	if not saber_fx.is_empty():
		saber_fx.time -= delta
		queue_redraw()
		if saber_fx.time <= 0.0:
			saber_fx = {}
	if not Conductor.playing:
		return
	if player.can_shoot():
		Game.track("seconds_" + ["spread", "laser", "fish"][Game.weapon], delta)
	var half = int(floor(Conductor.beat_position() * 2.0))
	if half != last_half:
		last_half = half
		if half % 2 == 1:
			pulse()


func _on_beat(_n: int):
	if not is_inside_tree():
		return
	pulse()


# One held-fire tick.
func pulse():
	if Input.is_action_pressed("shoot") and Time.get_ticks_msec() - last_click_msec > CLICK_SUPPRESS_MSEC:
		fire(HELD_DAMAGE)


func unleash_overdrive() -> bool:
	if Game.overdrive != 1 or not player.can_shoot():
		return false
	get_tree().current_scene.add_child(OverdriveBeam.create(player))
	return true


# A deliberate click: judged on the beat.
func click():
	if not player.can_shoot():
		return
	last_click_msec = Time.get_ticks_msec()
	var judgement = Conductor.judge()
	Game.register_judgement(judgement)
	fire(CLICK_DAMAGE * JUDGEMENT_DAMAGE[judgement], judgement)
	if judgement == Conductor.Judgement.PERFECT:
		Sfx.play("perfect", -10.0)


func fire(damage: float = CLICK_DAMAGE, judgement: int = -1):
	if not player.can_shoot():
		return
	var aim = Game.aim_override if Game.aim_override != null else get_global_mouse_position()
	var direction = aim - global_position
	if direction.length() < 1.0:
		direction = Vector2.RIGHT
	var base_angle = direction.angle()
	var scene = get_tree().current_scene
	if player.is_mech():
		var rifle = PlayerShot.create(global_position + direction.normalized() * 40.0, direction, damage * MECH_RIFLE * (1.0 + 0.2 * (Game.gun_level - 1)), judgement, PlayerShot.Kind.LASER)
		rifle.scale = Vector2(1.6, 1.6)
		scene.add_child(rifle)
		Sfx.play("shoot_laser", -3.0)
		return
	match Game.weapon:
		Game.Weapon.LASER:
			var power = LASER_BASE + LASER_PER_LEVEL * (Game.gun_level - 1)
			var crit = judgement == Conductor.Judgement.PERFECT
			var bolt = PlayerShot.create(global_position, direction, damage * power * (LASER_CRIT if crit else 1.0), judgement, PlayerShot.Kind.LASER)
			bolt.crit = crit
			scene.add_child(bolt)
		Game.Weapon.FISH:
			var count = FISH_COUNT[clamp(Game.gun_level, 1, 5)]
			for i in count:
				var offset = deg_to_rad((i - (count - 1) / 2.0) * 25.0)
				var fish_damage = FISH_DAMAGE * (ASSIST_FISH_BONUS if Game.assist > 0 else 1.0)
				scene.add_child(PlayerShot.create(global_position, Vector2.from_angle(base_angle + offset), damage * fish_damage, judgement, PlayerShot.Kind.FISH))
		_:
			var streams = 2 + Game.gun_level
			for i in streams:
				var offset = deg_to_rad((i - (streams - 1) / 2.0) * SPREAD_DEGREES)
				scene.add_child(PlayerShot.create(global_position, Vector2.from_angle(base_angle + offset), damage, judgement))
	Sfx.play(["shoot", "shoot_laser", "shoot_fish"][Game.weapon], -4.0 if judgement == Conductor.Judgement.PERFECT else -8.0)


# How many projectiles one fire() makes with the current weapon (tests, HUD).
static func shots_per_fire() -> int:
	match Game.weapon:
		Game.Weapon.LASER:
			return 1
		Game.Weapon.FISH:
			return FISH_COUNT[clamp(Game.gun_level, 1, 5)]
	return 2 + Game.gun_level
