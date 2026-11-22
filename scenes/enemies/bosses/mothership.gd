extends Boss

class_name Mothership

# Level 2 boss, "the Cheese Saucer".
#   melody  - staff notes (height = pitch), straight left.
#   walls   - on the downbeat of every other bar (phase 2: every bar) a full-height wall of
#             bullets with one gap. The gap moves along a slow wave, so you can follow it.
#   beam    - every 4th bar: lines up with the cat, shows the warning line for 2 beats, then
#             fires a screen-wide beam.
#   helpers - phase 1 only: 2 mice every 4 bars.
#   phase 2 - beat armour (see Boss) + a 3-arm spiral on beat 3.

const TEXTURE = preload("res://Art/Generated/boss_mothership.png")
const GRUNT = preload("res://scenes/enemies/grunt.tscn")


func _init():
	build(TEXTURE, 5.0, 82.0, 160.0)
	boss_name = "THE CHEESE SAUCER"


func on_lead_note(pitch: int, length: int):
	staff_note(pitch, 200.0 if phase == 1 else 215.0, 2 if length >= 3 else 1)


# Where the wall's gap is on a given bar: a slow wave over the screen height.
static func gap_for_bar(bar: int) -> float:
	return 360.0 + 190.0 * sin(bar * 0.9)


func on_beat(n: int):
	var beat = n % Conductor.BEATS_PER_BAR
	var bar = n / Conductor.BEATS_PER_BAR
	var wall_bar = phase == 2 or bar % 2 == 0
	if beat == 0 and wall_bar:
		wall(gap_for_bar(bar), 170.0, 170.0)
	if beat == 0 and phase == 1 and bar % 4 == 2:
		summon(GRUNT, [Vector2(position.x - 170, 180), Vector2(position.x - 170, 540)], 3.0)
	if phase == 2 and beat == 2:
		spiral(3, 150.0, 29.0)
	# beam every 4th bar (every 8th when heavily assisted)
	var beam_bar = bar % 8 == 3 if Game.assist >= 2 else bar % 4 == 3
	if beam_bar and beat == 1:
		var y = clamp(player_position().y, 120.0, 600.0)
		telegraph()
		var beam = EnemyBeam.create(global_position.x - 80, y, Conductor.seconds_per_beat * Game.warning_beats(2), Conductor.seconds_per_beat * 0.8)
		get_tree().current_scene.add_child(beam)
	if beat == 2 and bar % 2 == 1:
		drift_to(300.0 if (bar / 2) % 2 == 0 else 420.0, Conductor.seconds_per_beat * 4.0)
