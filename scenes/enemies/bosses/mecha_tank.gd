extends Boss

class_name MechaTank

# Level 1 boss. Plays the music:
#   drums  - downbeat: 5-shot fan (phase 2: 7-shot); warning flash on beat 4; repositions.
#   melody - one aimed shot per lead note, tilted by pitch (phase 2: pairs, faster).

const TEXTURE = preload("res://Art/Generated/boss_tank.png")


func _init():
	build(TEXTURE, 5.0, 62.0, 120.0)
	boss_name = "MECHA-MOUSE TANK"


func on_beat(n: int):
	var beat = n % Conductor.BEATS_PER_BAR
	var bar = n / Conductor.BEATS_PER_BAR
	match beat:
		0:
			if phase == 1:
				fan(5, 12.0, 300.0)
			else:
				fan(7, 10.0, 340.0)
		1:
			if phase == 2:
				move_to_y(player_position().y, 0.25)
			elif bar % 2 == 0:
				move_to_y(240.0 if (bar / 2) % 2 == 0 else 480.0)
		3:
			telegraph()


func on_lead_note(pitch: int, _length: int):
	if phase == 1:
		melody_shot(pitch, 280.0)
	else:
		melody_shot(pitch, 320.0, 2)
