extends Node2D

# Fires toward the mouse.
# - Pressing SPACE (the "shoot" action; the mouse aims) fires immediately and is judged:
#     PERFECT x2 damage, GOOD x1.5, off-beat x1 (and the combo resets).
# - Holding the button fires automatically exactly on each beat: 1.0 damage, not judged, no
#   combo - an easy fallback that also teaches the rhythm.
# Gun level (1-5) = number of streams, fanned out by SPREAD_DEGREES.

const SPREAD_DEGREES = 7.0
const CLICK_DAMAGE = 1.0
const HELD_DAMAGE = 1.0
const JUDGEMENT_DAMAGE = {
	Conductor.Judgement.MISS: 1.0,
	Conductor.Judgement.GOOD: 1.5,
	Conductor.Judgement.PERFECT: 2.0,
}
# a held beat-shot is skipped if the player clicked this close to the beat (no double shots)
const CLICK_SUPPRESS_MSEC = 150

@onready var player: Shmitten = get_parent()

var last_click_msec = -100000


func _ready():
	Conductor.beat.connect(_on_beat)


func _unhandled_input(event):
	if event.is_action_pressed("shoot"):
		click()


func _on_beat(_n: int):
	if not is_inside_tree():
		return
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
	var streams = Game.gun_level
	for i in streams:
		var offset = deg_to_rad((i - (streams - 1) / 2.0) * SPREAD_DEGREES)
		var shot = PlayerShot.create(global_position, Vector2.from_angle(base_angle + offset), damage, judgement)
		get_tree().current_scene.add_child(shot)
	Sfx.play("shoot", -4.0 if judgement == Conductor.Judgement.PERFECT else -8.0)
