extends Boss

class_name RatKing

# Level 3 (final) boss. Plays the music:
#   drums  - phase 1: 5-shot fan on the downbeat; phase 2: 10-shot ring on the downbeat and
#            2 shield-mouse guards every 2 bars; warning flash on beat 4; moves.
#   melody - aimed shot per lead note (a tight triple on long notes); phase 2: pairs.
# Phase 2 starts below half health and summons guards immediately.

const TEXTURE = preload("res://Art/Generated/boss_rat_king.png")
const SHIELD_MOUSE = preload("res://scenes/enemies/shield_mouse.tscn")


func _init():
	build(TEXTURE, 6.0, 66.0, 220.0)
	boss_name = "THE RAT KING"


func on_beat(n: int):
	var beat = n % Conductor.BEATS_PER_BAR
	var bar = n / Conductor.BEATS_PER_BAR
	match beat:
		0:
			if phase == 1:
				fan(5, 11.0, 320.0)
			else:
				ring(10, 250.0, bar * 0.31)
		1:
			if phase == 1 and bar % 2 == 0:
				move_to_y(200.0 if (bar / 2) % 2 == 0 else 520.0)
			elif phase == 2 and bar % 2 == 0:
				_summon_guards()
		3:
			telegraph()
			if phase == 2:
				move_to_y(player_position().y, 0.3)


func on_lead_note(pitch: int, length: int):
	if phase == 1:
		melody_shot(pitch, 270.0, 3 if length >= 2 else 1, 4.0)
	else:
		melody_shot(pitch, 280.0, 2, 6.0)


func on_phase_2():
	_summon_guards()


func _summon_guards():
	summon(SHIELD_MOUSE, [Vector2(position.x - 180, 200), Vector2(position.x - 180, 520)], 5.0)
