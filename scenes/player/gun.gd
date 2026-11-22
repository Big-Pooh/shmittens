extends Node2D

# Fires toward the mouse.
# - Pressing SPACE (the "shoot" action; the mouse aims) fires immediately and is judged:
#     PERFECT x2 damage, GOOD x1.5, off-beat x1 (and the combo resets).
# - Holding SPACE fires automatically on every 8th note (twice per beat): HELD_DAMAGE, not
#   judged, no combo - an easy fallback that keeps the groove (playtest 2: once per beat felt
#   "chunky").
# Three weapons (Game.Weapon), switched with 1/2/3, Q/E or the mouse wheel. Gun level 1-5
# (yarn) powers the equipped weapon:
#   SPREAD - level = number of streams fanned out by SPREAD_DEGREES. Best against waves.
#   LASER  - one fast piercing bolt, damage x(1 + LASER_PER_LEVEL per level above 1). Bosses.
#   FISH   - FISH_COUNT[level] homing fish at FISH_DAMAGE each. Hits while you dodge.

const SPREAD_DEGREES = 9.0
const CLICK_DAMAGE = 1.0
const HELD_DAMAGE = 0.6
const LASER_PER_LEVEL = 0.45
const FISH_COUNT = [0, 1, 2, 2, 3, 3]
const FISH_DAMAGE = 0.75
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


func _ready():
	Conductor.beat.connect(_on_beat)


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
	elif event is InputEventMouseButton and event.pressed and not Game.drawing:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			Game.cycle_weapon(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			Game.cycle_weapon(1)


# The off-beat 8th notes (the on-beat ones come from the Conductor's beat signal).
func _process(_delta):
	if not Conductor.playing:
		return
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
	match Game.weapon:
		Game.Weapon.LASER:
			var power = 1.0 + LASER_PER_LEVEL * (Game.gun_level - 1)
			scene.add_child(PlayerShot.create(global_position, direction, damage * power, judgement, PlayerShot.Kind.LASER))
		Game.Weapon.FISH:
			var count = FISH_COUNT[clamp(Game.gun_level, 1, 5)]
			for i in count:
				var offset = deg_to_rad((i - (count - 1) / 2.0) * 25.0)
				scene.add_child(PlayerShot.create(global_position, Vector2.from_angle(base_angle + offset), damage * FISH_DAMAGE, judgement, PlayerShot.Kind.FISH))
		_:
			var streams = Game.gun_level
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
	return Game.gun_level
