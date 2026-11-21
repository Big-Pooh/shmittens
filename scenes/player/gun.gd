extends Node2D

# Fires toward the mouse.
# - A click fires immediately and is judged against the music beat:
#     PERFECT x2 damage, GOOD x1.5, off-beat x1 and the combo resets.
# - Holding the button auto-fires weaker, unjudged shots.
# Gun level (1-5) = number of streams, fanned out by SPREAD_DEGREES.

const AUTO_FIRE_INTERVAL = 1.0 / 6.0
const SPREAD_DEGREES = 7.0
const CLICK_DAMAGE = 1.0
const AUTO_DAMAGE = 0.6
const JUDGEMENT_DAMAGE = {
	Conductor.Judgement.MISS: 1.0,
	Conductor.Judgement.GOOD: 1.5,
	Conductor.Judgement.PERFECT: 2.0,
}

@onready var player: Shmitten = get_parent()

var cooldown = 0.0


func _unhandled_input(event):
	if event.is_action_pressed("shoot"):
		click()


func _process(delta):
	cooldown -= delta
	if Input.is_action_pressed("shoot") and cooldown <= 0.0:
		fire(AUTO_DAMAGE)


# A deliberate click: judged on the beat.
func click():
	if not player.can_shoot():
		return
	var judgement = Conductor.judge()
	Game.register_judgement(judgement)
	fire(CLICK_DAMAGE * JUDGEMENT_DAMAGE[judgement], judgement)


func fire(damage: float = CLICK_DAMAGE, judgement: int = -1):
	if not player.can_shoot():
		return
	cooldown = AUTO_FIRE_INTERVAL
	var direction = get_global_mouse_position() - global_position
	if direction.length() < 1.0:
		direction = Vector2.RIGHT
	var base_angle = direction.angle()
	var streams = Game.gun_level
	for i in streams:
		var offset = deg_to_rad((i - (streams - 1) / 2.0) * SPREAD_DEGREES)
		var shot = PlayerShot.create(global_position, Vector2.from_angle(base_angle + offset), damage, judgement)
		get_tree().current_scene.add_child(shot)
	Sfx.play("shoot", -4.0 if judgement == Conductor.Judgement.PERFECT else -8.0)
