extends Boss

class_name TankyJr

# Mid-boss of Drainia: Tanky's little one (with a pacifier). Two cards:
#   0 "Junior Parade" - a small 3-shot arc on the downbeat + staff notes.
#   1 "Baby Snake"    - NEW PATTERN: a wriggling aimed stream on every hi-hat. Keep moving!

const TEXTURE = preload("res://Art/Generated/boss_tanky_jr.png")
var hats = 0


func _init():
	build(TEXTURE, 4.0, 52.0, 150.0)
	boss_name = "TANKY JR."
	cards = [
		{"name": "Junior Parade", "share": 0.5, "seconds": 20.0, "armored": false, "weak": "laser"},
		{"name": "Baby Snake", "share": 0.5, "seconds": 22.0, "armored": false, "weak": "shockwave"},
	]


func on_beat(n: int):
	if card == 0 and n % 4 == 0:
		arc(3, 18.0, 170.0)
	if n % 4 == 3:
		telegraph()


func on_hat(_n: int):
	if card == 1:
		hats += 1
		if Game.assist == 0 or hats % 2 == 0:
			snake(hats, 200.0)


func on_lead_note(pitch: int, _length: int):
	if card == 0:
		staff_note(pitch, 180.0)
