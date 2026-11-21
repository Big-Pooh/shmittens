extends Boss

class_name MechaTank

# Level 1 boss. Every bar: warning flash on beat 4, a 5-shot fan at the cat on the downbeat;
# repositions every 2 bars. Phase 2: 7-shot fans on beats 1 and 3, warnings before each.

const TEXTURE = preload("res://Art/Generated/boss_tank.png")


func _init():
	build(TEXTURE, 5.0, 62.0, 120.0)
	boss_name = "MECHA-MOUSE TANK"


func on_beat(n: int):
	var beat = n % Conductor.BEATS_PER_BAR
	var bar = n / Conductor.BEATS_PER_BAR
	if phase == 1:
		if beat == 3:
			telegraph()
		elif beat == 0:
			fan(5, 12.0, 300.0)
		elif beat == 1 and bar % 2 == 0:
			move_to_y(240.0 if (bar / 2) % 2 == 0 else 480.0)
	else:
		if beat == 1 or beat == 3:
			telegraph()
			if beat == 1:
				move_to_y(player_position().y, 0.25)
		else:
			fan(7, 10.0, 340.0)
