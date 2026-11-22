extends Boss

class_name Mothership

# Level 2 boss, "the Cheese Saucer". Two spell cards:
#   0 "Cheese Rain" - a full-height wall with one gap on every other downbeat (the gap moves
#     along a slow wave), staff notes, a warned beam every 4th bar, 2 helper mice every 4 bars.
#   1 "Holey Lattice" (beat armour) - walls every bar, a 3-arm rice spiral on beat 3, and every
#     4th bar an orb ring that freezes on the beat and then re-aims at you.

const TEXTURE = preload("res://Art/Generated/boss_mothership.png")
const GRUNT = preload("res://scenes/enemies/grunt.tscn")


func _init():
	build(TEXTURE, 5.0, 82.0, 260.0)
	boss_name = "THE CHEESE SAUCER"
	cards = [
		{"name": "Cheese Rain", "share": 0.5, "seconds": 35.0, "armored": false},
		{"name": "Holey Lattice", "share": 0.5, "seconds": 40.0, "armored": true},
	]


func on_lead_note(pitch: int, _length: int):
	# single notes (pairs made level 2 harder than level 3 for beginners)
	staff_note(pitch, 200.0 if card == 0 else 215.0)


# Where the wall's gap is on a given bar: a slow wave over the screen height.
static func gap_for_bar(bar: int) -> float:
	return 360.0 + 190.0 * sin(bar * 0.9)


func on_beat(n: int):
	var beat = n % Conductor.BEATS_PER_BAR
	var bar = n / Conductor.BEATS_PER_BAR
	var wall_bar = card >= 1 or bar % 2 == 0
	if Game.assist >= 1:
		wall_bar = bar % (2 if card >= 1 else 4) == 0   # beginner care: half as many walls
	if beat == 0 and wall_bar:
		wall(gap_for_bar(bar), 200.0, 170.0)
	if beat == 0 and card == 0 and bar % 4 == 2:
		summon(GRUNT, [Vector2(position.x - 170, 180), Vector2(position.x - 170, 540)], 3.0)
	if card >= 1 and beat == 2:
		spiral(3, 150.0, 29.0)
	if card >= 1 and beat == 1 and bar % 4 == 1:
		freeze_ring(10, 160.0, 200.0, EnemyShot.Kind.ORB, bar * 0.3)
	# beam every 4th bar (every 8th when heavily assisted)
	var beam_bar = bar % 8 == 3 if Game.assist >= 2 else bar % 4 == 3
	if beam_bar and beat == 1:
		var y = clamp(player_position().y, 120.0, 600.0)
		telegraph()
		var beam = EnemyBeam.create(global_position.x - 80, y, Conductor.seconds_per_beat * Game.warning_beats(2), Conductor.seconds_per_beat * 0.8)
		get_tree().current_scene.add_child(beam)
	if beat == 2 and bar % 2 == 1:
		drift_to(300.0 if (bar / 2) % 2 == 0 else 420.0, Conductor.seconds_per_beat * 4.0)
