extends Boss

class_name RatKing

# Level 3 (final) boss, "King Ratbert". Playtest 2: "too many random bullets and hard to hit"
# -> no shield-mouse guards (they blocked your shots), no jumping to your height, every bullet
# is part of a fixed pattern:
#   melody  - staff notes (height = pitch); long notes are chords of 2.
#   drums   - downbeat: a 14-shot ring that rotates a little every bar; beat 3: a 5-shot arc.
#             Drifts slowly in a figure of eight.
#   phase 2 - beat armour (see Boss) + two counter-rotating spiral arms on every beat; the
#             ring only on every other bar.

const TEXTURE = preload("res://Art/Generated/boss_rat_king.png")


func _init():
	build(TEXTURE, 6.0, 84.0, 220.0)
	boss_name = "KING RATBERT"


var counter_angle = 0.0


func on_beat(n: int):
	var beat = n % Conductor.BEATS_PER_BAR
	var bar = n / Conductor.BEATS_PER_BAR
	if beat == 0 and (phase == 1 or bar % 2 == 0):
		ring(14, 160.0, bar * 0.11)
	if beat == 2 and phase == 1:
		arc(5, 14.0, 190.0)
	if phase == 2:
		spiral(1, 150.0, 31.0)
		_counter_spiral()
	if beat == 0 and bar % 2 == 0:
		drift_to(360.0 + 150.0 * sin(bar * 0.8), Conductor.seconds_per_beat * 8.0)
	if beat == 3:
		telegraph()


# The second arm turns the other way, so the two arms cross in a readable lattice.
func _counter_spiral():
	if Game.assist >= 2:
		return
	fire_shot(Vector2.from_angle(PI + counter_angle), 150.0)
	counter_angle -= deg_to_rad(31.0)


func on_lead_note(pitch: int, length: int):
	staff_note(pitch, 205.0, 2 if length >= 2 else 1)
