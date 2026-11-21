extends Boss

class_name RatKing

# Level 3 (final) boss.
# Phase 1, every bar: 5-shot fan on the downbeat, a tight aimed triple on beat 3,
#   warning flash on beat 4; moves every 2 bars.
# Phase 2 (below half health): summons 2 shield mice immediately and every 2 bars,
#   a 12-shot ring on the downbeat and a 7-shot fan on beat 3.

const TEXTURE = preload("res://Art/Generated/boss_rat_king.png")
const SHIELD_MOUSE = preload("res://scenes/enemies/shield_mouse.tscn")


func _init():
	build(TEXTURE, 6.0, 66.0, 220.0)
	boss_name = "THE RAT KING"


func on_beat(n: int):
	var beat = n % Conductor.BEATS_PER_BAR
	var bar = n / Conductor.BEATS_PER_BAR
	if phase == 1:
		match beat:
			0:
				fan(5, 11.0, 320.0)
			1:
				if bar % 2 == 0:
					move_to_y(200.0 if (bar / 2) % 2 == 0 else 520.0)
			2:
				fan(3, 4.0, 420.0)
			3:
				telegraph()
	else:
		match beat:
			0:
				ring(12, 280.0, bar * 0.26)
			1:
				if bar % 2 == 0:
					_summon_guards()
			2:
				fan(7, 9.0, 360.0)
			3:
				telegraph()
				move_to_y(player_position().y, 0.3)


func on_phase_2():
	_summon_guards()


func _summon_guards():
	summon(SHIELD_MOUSE, [Vector2(position.x - 180, 200), Vector2(position.x - 180, 520)], 5.0)
