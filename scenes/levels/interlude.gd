extends Node2D

class_name Interlude

# INTERLUDES (v0.12 playtest, MANDATORY: "funny interludes like in chicken invaders, still
# playable" + "give the player some chances to rest while travelling between planets").
# Between two planets the cat flies through a short silly scene: nothing can hurt her (safe
# phase), the music is calm, and there are goofy things to pop for bonus points.
# Three scenes rotate: CHEESE METEOR SHOWER, MOUSE CONGA NIGHT, SPACE LAUNDRY DAY.
# Pop EVERYTHING for a big "PERFECT INTERLUDE" bonus. Deterministic (no randomness).

const BARS = 8
const KINDS = ["cheese", "conga", "laundry"]
const TITLES = {
	"cheese": "CHEESE METEOR SHOWER!",
	"conga": "MOUSE CONGA NIGHT!",
	"laundry": "SPACE LAUNDRY DAY!",
}
const SUBTITLES = {
	"cheese": "A cheese wheel storm! Shoot them for cheese. (Nothing can hurt you - take a breather)",
	"conga": "Sho's goons are on their night off. Pop the party animals! (Nothing can hurt you)",
	"laundry": "Someone's laundry escaped their ship. Pop the socks! (Nothing can hurt you)",
}
const ALL_BONUS = 5000
const CHEESE_WHEEL = preload("res://Art/Generated/cheese_wheel.png")
const SOCK = preload("res://Art/Generated/sock.png")
const DUCK = preload("res://Art/Generated/rubber_duck.png")
const GRUNT = preload("res://Art/Generated/grunt.png")
const PARTY_HAT = preload("res://Art/Generated/hat_party.png")

var kind = "cheese"
var beats = 0
var total = 0
var popped = 0
var finished = false


static func create(index: int) -> Interlude:
	var i = Interlude.new()
	i.kind = KINDS[index % KINDS.size()]
	return i


func _ready():
	name = "Interlude"
	Conductor.beat.connect(_on_beat)


func title() -> String:
	return TITLES[kind]


func subtitle() -> String:
	return SUBTITLES[kind]


func _on_beat(_n: int):
	if finished or not is_inside_tree():
		return
	beats += 1
	if beats > BARS * 4 - 8:
		return   # the last bars stay empty so everything leaves the screen
	match kind:
		"cheese":
			# wheels tumble in diagonally; every 6th beat a rubber duck surfs by
			var x = 500.0 + float((beats * 263) % 760)
			var w = _spawn(CHEESE_WHEEL, Vector2(x, -40), Vector2(-90 - (beats % 3) * 30, 210), 3.2)
			w.spin = 3.0 if beats % 2 == 0 else -3.0
			w.cheese = 2
			w.quip = ["CHEESY!", "GOUDA SHOT!", "BRIE-LLIANT!", "NACHO CHEESE!"][beats % 4]
			if beats % 6 == 0:
				var d = _spawn(DUCK, Vector2(1340, 160 + (beats * 97) % 420), Vector2(-260, 0), 3.0)
				d.score_value = 1000
				d.quip = "QUACK?!  +1000"
		"conga":
			# a 14-mouse conga line in party hats, swaying through the screen
			if beats <= 14:
				var m = _spawn(GRUNT, Vector2(1340, 360), Vector2(-170, 0), 2.6)
				m.conga = true
				m.hat = PARTY_HAT
				m.score_value = 300
				m.quip = ["SQUEAK!", "PARTY FOUL!", "MY HAT!", "CONGA NO!", "WHEEE!"][beats % 5]
		"laundry":
			# socks flutter out of a passing laundry ship, one per beat, in a wave
			var y = 120.0 + float((beats * 151) % 480)
			var s = _spawn(SOCK, Vector2(1340, y), Vector2(-230, 40.0 * sin(beats)), 3.0)
			s.spin = 1.5 if beats % 2 == 0 else -1.5
			s.quip = ["SOCK'D!", "STINKY!", "LEFT SOCK!", "LOST ONE!", "PEE-YEW!"][beats % 5]
			if beats % 8 == 4:
				var m = _spawn(GRUNT, Vector2(1340, 620), Vector2(-150, 0), 2.6)
				m.score_value = 800
				m.quip = "MY SOCKS!!  (sorry)"


func _spawn(tex: Texture2D, at: Vector2, vel: Vector2, k: float) -> InterludeTarget:
	var t = InterludeTarget.make(tex, at, vel, k)
	total += 1
	t.died.connect(func(_e): popped += 1)
	get_tree().current_scene.add_child(t)
	return t


# Called when the interlude ends: bonus if everything was popped, then tidy up.
func finish() -> bool:
	finished = true
	var perfect = total > 0 and popped >= total
	if perfect:
		Game.add_score(ALL_BONUS)
		Game.track("perfect_interludes")
	for t in get_tree().get_nodes_in_group("interlude"):
		t.queue_free()
	queue_free()
	return perfect


static func pop_text(parent: Node, text: String, at: Vector2):
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", Color(1, 0.7, 0.88))
	l.add_theme_color_override("font_outline_color", Color(0.25, 0.1, 0.25))
	l.add_theme_constant_override("outline_size", 5)
	l.position = at + Vector2(-40, -40)
	l.z_index = 40
	parent.add_child.call_deferred(l)
	var tw = l.create_tween()
	tw.tween_property(l, "position:y", at.y - 90, 0.8)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.8).set_delay(0.3)
	tw.tween_callback(l.queue_free)
