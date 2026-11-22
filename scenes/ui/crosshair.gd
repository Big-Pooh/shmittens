extends CanvasLayer

# Replaces the mouse cursor with a crosshair sprite that pulses on every beat and shows
# PERFECT / GOOD / MISS for each judged click.

const TEXTURE = preload("res://Art/Generated/crosshair.png")
const BASE_SCALE = 3.0
const JUDGEMENT_TEXT = {
	Conductor.Judgement.PERFECT: ["PERFECT", Color(1, 0.82, 0.25)],
	Conductor.Judgement.GOOD: ["GOOD", Color(0.6, 1, 0.7)],
	Conductor.Judgement.MISS: ["MISS", Color(1, 0.4, 0.4)],
}

var sprite: Sprite2D


func _ready():
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	sprite = Sprite2D.new()
	sprite.texture = TEXTURE
	sprite.scale = Vector2.ONE * BASE_SCALE
	add_child(sprite)
	set_captured(true)
	Conductor.beat.connect(_on_beat)
	Game.judged.connect(_show_judgement)


func _process(_delta):
	sprite.position = get_viewport().get_mouse_position()


func _on_beat(n: int):
	if not is_inside_tree():
		return
	var peak = 4.2 if n % Conductor.BEATS_PER_BAR == 0 else 3.7
	sprite.scale = Vector2.ONE * peak
	create_tween().tween_property(sprite, "scale", Vector2.ONE * BASE_SCALE, 0.15)


const MAX_POPUPS = 2
var popups: Array = []


func _show_judgement(judgement: int):
	var main = get_tree().current_scene
	if main and "transition_card" in main and main.transition_card and is_instance_valid(main.transition_card):
		return   # not on top of the planet map card
	popups = popups.filter(func(p): return is_instance_valid(p))
	while popups.size() >= MAX_POPUPS:
		popups.pop_front().queue_free()
	var label = Label.new()
	label.text = JUDGEMENT_TEXT[judgement][0]
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", JUDGEMENT_TEXT[judgement][1])
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 5)
	# PERFECT / GOOD / MISS appear in one fixed spot just above the beat bar (rhythm-game
	# convention) - never on the score, the boss bar or the speech bubbles. Newest on top.
	label.position = Vector2(640 - 50, 628 - 26 * popups.size())
	popups.append(label)
	add_child(label)
	var tween = create_tween().set_parallel()
	tween.tween_property(label, "position:y", label.position.y - 10, 0.45)
	tween.tween_property(label, "modulate:a", 0.0, 0.45).set_delay(0.15)
	tween.chain().tween_callback(label.queue_free)


# While playing, hide the system cursor and keep it inside the window.
func set_captured(captured: bool):
	sprite.visible = captured
	Input.mouse_mode = Input.MOUSE_MODE_CONFINED_HIDDEN if captured else Input.MOUSE_MODE_VISIBLE


func _exit_tree():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
