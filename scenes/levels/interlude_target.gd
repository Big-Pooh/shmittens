extends EnemyBase

class_name InterludeTarget

# A harmless, silly target in an INTERLUDE (cheese wheels, conga dancers, flying socks...).
# It never shoots; popping it gives points (and cheese for cheese wheels).

var vel = Vector2.ZERO
var spin = 0.0
var conga = false      # follows a wavy conga path
var base_y = 0.0
var cheese = 0
var quip = ""
var hat: Texture2D


static func make(tex: Texture2D, at: Vector2, velocity: Vector2, k_scale: float = 3.0) -> InterludeTarget:
	var e = InterludeTarget.new()
	var sp = Sprite2D.new()
	sp.name = "Sprite2D"
	sp.texture = tex
	sp.scale = Vector2.ONE * k_scale
	e.add_child(sp)
	var cs = CollisionShape2D.new()
	var sh = CircleShape2D.new()
	sh.radius = max(tex.get_width(), tex.get_height()) * k_scale * 0.45
	cs.shape = sh
	e.add_child(cs)
	e.position = at
	e.vel = velocity
	e.max_health = 1
	e.score_value = 250
	e.drops = false
	return e


func tutorial_exempt() -> bool:
	return true   # no rank / elite scaling: interludes are a breather


func _ready():
	super()
	add_to_group("interlude")
	base_y = position.y
	if hat:
		var h = Sprite2D.new()
		h.texture = hat
		h.position = Vector2(-2, -sprite.texture.get_height() / 2.0 - 2)
		sprite.add_child(h)


func _anim_beat(n: int):
	if spin == 0.0:
		super(n)


func _behave(delta):
	position += vel * delta
	if conga:
		position.y = base_y + sin(position.x * 0.011) * 130.0
	if spin != 0.0:
		sprite.rotation += spin * delta
	if position.y > 800 or position.y < -120:
		queue_free()


func die():
	if is_dead:
		return
	for i in cheese:
		get_tree().current_scene.add_child.call_deferred(Pickup.create(Pickup.Type.CHEESE, global_position + Vector2(i * 16, -i * 12)))
	if quip != "":
		Interlude.pop_text(get_tree().current_scene, quip, global_position)
	super()
