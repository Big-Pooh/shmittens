extends CanvasLayer

class_name Calibration

# RHYTHM CHECK (onboarding, design review): tap SPACE on the kick TAPS_NEEDED times; the median
# timing error becomes the beat offset (Conductor.offset_ms), so PERFECT matches YOUR speakers or
# headphones. Runs automatically on the first web launch (browser audio latency varies 50-150 ms)
# and from the title screen's RHYTHM CHECK button. Taps more than OUTLIER s off are ignored.

signal done(offset_ms: float)

const TAPS_NEEDED = 12
const OUTLIER = 0.25

var errors: Array = []
var label: Label
var ring: Node2D
var finished = false


func _ready():
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bg = ColorRect.new()
	bg.color = Color(0.04, 0.03, 0.1, 0.94)
	bg.size = Game.SCREEN.size
	add_child(bg)
	ring = Node2D.new()
	ring.position = Vector2(640, 330)
	ring.draw.connect(_draw_ring)
	add_child(ring)
	label = Label.new()
	label.position = Vector2(80, 470)
	label.size = Vector2(1120, 160)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(1, 0.95, 1))
	add_child(label)
	if not Conductor.playing:
		Conductor.play("level1", 1)
	_update_text()


func _update_text():
	label.text = "RHYTHM CHECK\nTap SPACE exactly on every thump of the drum (%d / %d)\nEsc - skip" % [errors.size(), TAPS_NEEDED]


func _process(_delta):
	ring.queue_redraw()


func _draw_ring():
	var p = 1.0 - Conductor.beat_phase()
	ring.draw_circle(Vector2.ZERO, 40.0 + 50.0 * p * p, Color(1, 0.82, 0.25, 0.25 + 0.6 * p * p))
	ring.draw_arc(Vector2.ZERO, 90.0, 0, TAU, 48, Color(1, 1, 1, 0.5), 3.0)


func _unhandled_input(event):
	if finished:
		if event.is_action_pressed("shoot") or event.is_action_pressed("pause"):
			get_viewport().set_input_as_handled()
			queue_free()
		return
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		finished = true
		done.emit(Conductor.offset_ms)
		queue_free()
	elif event.is_action_pressed("shoot"):
		get_viewport().set_input_as_handled()
		tap(Conductor.beat_error())


# One tap with its signed timing error in seconds (+ = late). Returns true when finished.
func tap(error: float) -> bool:
	if finished:
		return true
	if absf(error) <= OUTLIER:
		errors.append(error)
		Sfx.play("perfect", -12.0)
	_update_text()
	if errors.size() >= TAPS_NEEDED:
		finish()
		return true
	return false


func finish():
	finished = true
	var sorted = errors.duplicate()
	sorted.sort()
	var median = sorted[sorted.size() / 2]
	var new_offset = clamp(Conductor.offset_ms + median * 1000.0, -200.0, 200.0)
	Conductor.set_offset_ms(new_offset)
	Game.track("calibrated_offset_ms", new_offset)
	label.text = "Done! Your beat offset is %+d ms.\nPERFECT now matches your speakers. (Change it any time in the pause menu.)\nSPACE - continue" % int(round(new_offset))
	done.emit(new_offset)
