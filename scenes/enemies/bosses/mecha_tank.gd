extends Boss

class_name MechaTank

# Level 1 boss, "Tanky": the gentle introduction to patterns.
#   melody  - every lead note is a staff note (height = pitch), flying straight left.
#   drums   - downbeat: a 5-shot left-pointing arc, nudged half a gap every bar so the safe
#             lanes alternate; drifts slowly between two heights every 2 bars.
#   phase 2 - beat armour (see Boss) + a slow 2-arm spiral on beats 2 and 4.

const TEXTURE = preload("res://Art/Generated/boss_tank.png")


func _init():
	build(TEXTURE, 5.0, 78.0, 190.0)   # playtest 2: x1.6 (laser + beat armour made bosses melt)
	boss_name = "TANKY THE MECHA-MOUSE"


func on_beat(n: int):
	var beat = n % Conductor.BEATS_PER_BAR
	var bar = n / Conductor.BEATS_PER_BAR
	match beat:
		0:
			arc(5, 16.0, 180.0, 180.0 + (8.0 if bar % 2 == 0 else -8.0))
			if bar % 2 == 0:
				drift_to(260.0 if (bar / 2) % 2 == 0 else 460.0, Conductor.seconds_per_beat * 4.0)
		1, 3:
			if phase == 2:
				spiral(2, 150.0, 37.0)
	if beat == 3:
		telegraph()


func on_lead_note(pitch: int, _length: int):
	staff_note(pitch, 190.0 if phase == 1 else 210.0)
