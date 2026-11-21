extends Grunt

class_name ShieldMouse

# A grunt carrying a plate in front. Off-beat and held shots travelling rightwards within
# +/-BLOCK_ANGLE of straight on are blocked. Ways through: on-beat clicks (GOOD/PERFECT smash
# through the plate - the key way), shots from a steep angle (cat above/below), and skills.

const BLOCK_ANGLE = deg_to_rad(60.0)

@onready var plate: Sprite2D = $Plate


func take_hit(amount: float, direction: Vector2, judgement: int = -1):
	if is_blocking(direction, judgement):
		Sfx.play("hit", -14.0)
		plate.modulate = Color(2, 2, 3)
		create_tween().tween_property(plate, "modulate", Color.WHITE, 0.1)
		return
	take_damage(amount, judgement)


func is_blocking(direction: Vector2, judgement: int = -1) -> bool:
	if judgement == Conductor.Judgement.GOOD or judgement == Conductor.Judgement.PERFECT:
		return false
	return absf(direction.angle_to(Vector2.RIGHT)) <= BLOCK_ANGLE


func _behave(delta):
	super(delta)
	plate.position.y = sprite.position.y
