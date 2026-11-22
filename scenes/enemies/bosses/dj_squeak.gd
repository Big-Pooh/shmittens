extends Boss

class_name DJSqueak

# World 2, Neon Nibble: DJ SQUEAK, the party mouse. The most music-driven boss. Three cards:
#   0 "Drop the Beat"    - a flower on every downbeat + an aimed pair on every snare.
#   1 "Laser Light Show" - searchlight fans on the hi-hats + butterfly wings every other bar.
#   2 "Bass Boost"       - BEAT ARMOUR: a galaxy on every beat + roses on the bar.

const TEXTURE = preload("res://Art/Generated/boss_dj_squeak.png")


func _init():
	build(TEXTURE, 5.0, 80.0, 1350.0)
	boss_name = "DJ SQUEAK"
	cards = [
		{"name": "Drop the Beat", "share": 0.34, "seconds": 35.0, "armored": false, "weak": "laser"},
		{"name": "Laser Light Show", "share": 0.33, "seconds": 35.0, "armored": false, "weak": "shockwave"},
		{"name": "Bass Boost", "share": 0.33, "seconds": 40.0, "armored": true, "weak": "lightning"},
	]


func on_beat(n: int):
	var beat = n % 4
	var bar = n / 4
	match card:
		0:
			if beat == 0:
				flower(2, 12, 170.0, EnemyShot.Kind.CANDY, bar * 0.2)
			if beat == 1 or beat == 3:
				aimed(2, 220.0, 9.0)
		1:
			if beat == 0 and bar % 2 == 0:
				butterfly(3, 170.0, 0.95)
		_:
			galaxy(2, 250.0, 27.0)
			if beat == 0:
				rose(14, 170.0, 4, bar * 0.3)
	if beat == 3:
		telegraph()


func on_hat(n: int):
	if card == 1 and (Game.assist == 0 or (n / 2) % 2 == 0):
		searchlight(fmod(Conductor.beat_position() / 8.0, 1.0), 3, 210.0)
	elif cards[card].armored and Game.assist < 2:
		spiral(1, 140.0, 13.0 * mirror)


func on_lead_note(pitch: int, length: int):
	staff_note(pitch, 210.0, 2 if length >= 3 else 1)
