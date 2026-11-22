extends Boss

class_name RoyalGuard

# Mid-boss of Flexor: Sho's royal guard, a knight mouse with a spear. Two cards:
#   0 "Halt! Who Goes There?" - a 7-shot rose on the downbeat + an aimed pair on beat 3.
#   1 "Spear Pincer"          - NEW PATTERN: rice columns fall from the top AND rise from the
#                               bottom every bar, closing in, with one safe column that moves.

const TEXTURE = preload("res://Art/Generated/boss_royal_guard.png")


func _init():
	build(TEXTURE, 4.0, 60.0, 240.0)
	boss_name = "ROYAL GUARD"
	cards = [
		{"name": "Halt! Who Goes There?", "share": 0.5, "seconds": 24.0, "armored": false, "weak": "laser"},
		{"name": "Spear Pincer", "share": 0.5, "seconds": 26.0, "armored": false, "weak": "lightning"},
	]


func on_beat(n: int):
	var bar = n / 4
	match card:
		0:
			if n % 4 == 0:
				rose(10, 170.0, 3, bar * 0.4)
			if n % 4 == 2:
				aimed(2, 210.0, 10.0)
		_:
			if n % 4 == 0:
				pincer(10, 150.0, 300.0 + 200.0 * sin(bar * 0.9))
	if n % 4 == 3:
		telegraph()


func on_lead_note(pitch: int, _length: int):
	staff_note(pitch, 190.0)
